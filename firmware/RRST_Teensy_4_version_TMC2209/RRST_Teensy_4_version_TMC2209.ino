


#include "LocalMenuCmd.h" // Local fixed version wrapper
#include <teensystep4.h>
#include <TMCStepper.h>
#include <EEPROM.h>
#include <string.h>
#include <OneWire.h>
#include <DallasTemperature.h>


#define LedOnBoard 13

#define EndstopMaxPin 6
#define EndstopMinPin 7
#define EnablePin 8
#define DirPin 9
#define StepPin 10
#define STARTPOS 20000
#define ACCELERATION 10000
#define SPEED 16000

// TMC2209 UART configuration (current + microstepping only; STEP/DIR/EN
// wiring and homing are unaffected by any of this)
#define R_SENSE 0.11f       // BigTreeTech TMC2209 V1.2 sense resistor
#define DRIVER_ADDRESS 0b00 // MS1=MS2=GND -> UART slave address 0
#define DefaultRunCurrent 800  // mA
#define DefaultMicrosteps 16
#define DefaultHoldPercent 50  // % of run current; matches TMCStepper's own default ratio
#define DefaultRetractDistanceMm 15.0f  // = 24000 steps at 16 microsteps; see the retract-distance design spec for the geometry this comes from

// Endstop auto-correction safeguard (cmd6_AbsoluteMove only; homing and
// calibration are unaffected)
#define EndstopDebounceMs 5
#define MaxConsecutiveUnexpectedHits 3
#define EndstopResumeGraceMs 300  // suppress the just-hit endstop this long on retry, so genuine continued contact right after a correction isn't mistaken for a fresh hit

// How long a two-step command (e.g. 'f' then a number) waits for its second
// input before giving up - see WaitForCommandInput(). Long enough for a
// human typing into a terminal, short enough that background safety
// monitoring isn't blocked for an unreasonable time if the second input
// never arrives at all.
#define CommandInputTimeoutMs 15000

// Precise endstop homing (cmd3_Calibrate): fast approach, back off, then a
// slow re-approach whose trigger point is trusted as the true reference -
// far more repeatable than a single fast trigger.
#define HomingBackoffMinDistanceMm 3.0f  // unconditional back-off before phase 3 - see monitored-endstop-backoff design spec
#define HomingBackoffMaxDistanceMm 10.0f // safety cap: abort if the switch hasn't released by this total back-off distance
#define HomingSpeed 8000          // fixed fast-approach/back-off speed for calibration and homing - deliberately decoupled from the general Speed/Acceleration - see fixed-homing-speed design spec
#define HomingAcceleration 5000
#define HomingSlowSpeed    1000 // steps/s for the slow re-approach; ~6% of default cruise speed (16000)
#define HomingOvertravelMargin 200 // extra distance on the slow re-approach beyond the backoff, to guarantee reaching the switch even with some backlash/variance

// Temperature-controlled driver cooling fan (low-side MOSFET switch on the
// FAN connector's GND return - see the fan-thermal-control design spec for
// the hardware side).
#define FanControlPin 2
#define FanT120PollIntervalMs 2000  // how often to poll DRV_STATUS for t120 in Auto mode
#define FanCooldownMs 60000         // keep the fan on this long after t120 clears, to avoid chatter at the threshold

// Optional DS18B20 1-Wire heat-sink temperature sensor - detected once
// at boot (see setup()). Devices without one wired pay no added cost:
// cmd7_Status() skips the whole read path when none was found.
#define HeatSinkTempPin 4

OneWire heatSinkOneWire(HeatSinkTempPin);
DallasTemperature heatSinkTempSensor(&heatSinkOneWire);
bool HeatSinkSensorPresent = false;  // set once in setup(), after the bus scan

// Automatic driver fault monitoring: independent of the fan's own poll,
// so fault detection doesn't stop just because FanMode is Forced.
#define FaultMonitorPollIntervalMs 2000  // how often to poll DRV_STATUS for real faults

// Settings persistence (EEPROM emulation via Teensyduino's EEPROM
// library; no new hardware). Two independent concerns share one struct
// via independent validity flags: tuning settings (tuningValid, written
// only by the explicit 'v' command, to avoid wearing the emulated
// EEPROM's flash during rapid bench-tuning) and the last successfully
// calibrated MaxPosition (calibrationValid, written automatically right
// after a successful 'c', for comparison/diagnostic display only).
#define PersistedSettingsMagic 0x52525354  // sentinel: this EEPROM region has been written by compatible firmware at all
#define PersistedSettingsVersion 2  // was 1 - retractDistanceMm field added
#define PersistedSettingsEepromAddress 0


using namespace TS4;

SerialMenuCmd myMmuCmd;
Stepper motor(StepPin, DirPin);  
TMC2209Stepper driver(&Serial1, R_SENSE, DRIVER_ADDRESS);

struct PersistedSettings {
  uint32_t magic;
  uint16_t version;
  bool     tuningValid;
  int32_t  runCurrentMa;
  uint8_t  holdPercent;
  uint32_t speed;
  uint32_t acceleration;
  int32_t  microsteps;
  bool     spreadCycleEnabled;
  float    retractDistanceMm;
  bool     calibrationValid;
  int32_t  lastCalibratedMaxPosition;
};

// Independent of PersistedSettings on purpose - a distinct magic value and
// its own EEPROM address, so a future change to PersistedSettings's
// version (which wipes that whole struct on mismatch - see its own
// version-bump history above) can never erase this device's lifetime
// usage history, and vice versa. Losing a tuning setting is a quick
// re-save; losing lifetime run-hours/distance is permanent and
// unrecoverable.
#define UsageStatsMagic 0x52525355   // distinct from PersistedSettingsMagic (...54)
#define UsageStatsVersion 3  // was 2 - peakHeatSinkTempC added
#define UsageStatsEepromAddress 160  // clear of PersistedSettings's ~40 bytes at address 0

struct UsageStats {
  uint32_t magic;
  uint16_t version;
  uint32_t totalEnabledSeconds;   // lifetime motor-enabled time
  float    totalDistanceMeters;   // lifetime lead-screw travel
  uint32_t totalMinHits;          // lifetime min-endstop physical actuations
  uint32_t totalMaxHits;          // lifetime max-endstop physical actuations
  float    peakHeatSinkTempC;     // lifetime peak DS18B20 reading, or
                                   // DEVICE_DISCONNECTED_C if never recorded
};

uint8_t StepperStatus;
int32_t MaxPosition = 45000;       
uint8_t CalibrationStatus = 0;
int32_t CurrentPosition = 0;       
uint32_t Acceleration = ACCELERATION; 
uint32_t Speed = SPEED;               
uint16_t LedOnTime;
uint16_t LedOffTime;
uint32_t tEvent;
String Software;

// No TMCStepper getter reflects the hold-current ratio as a percentage
// (IHOLD_IRUN is write-only, and hold_multiplier() has no matching
// getter), so this is tracked locally, same reasoning as Speed/Acceleration.
uint8_t HoldPercent = DefaultHoldPercent;

// The literal last-requested run current in mA, NOT driver.rms_current()'s
// reconstructed value. driver.rms_current() truncates a different float
// formula than the setter does, so feeding the getter's output back into
// the setter is not a fixed point - it silently decrements the actual
// current by roughly one CS step on every call. Always re-apply this
// exact integer instead, which is idempotent by construction.
int32_t RunCurrentMa = DefaultRunCurrent;

// SpreadCycle (true) trades quiet running for full torque/speed headroom;
// StealthChop (false) is near-silent but loses torque well before the
// motor's real limits - confirmed on the bench: 30000 steps/s unloaded
// struggled under StealthChop, ran clean at 70000 steps/s under SpreadCycle.
// Defaults to SpreadCycle so out-of-the-box behavior is the proven-reliable
// one; toggle to StealthChop for moves where quiet matters more than speed.
bool SpreadCycleEnabled = true;

// Distance (mm) to retract from the calibrated MaxPosition to reach the
// point where the wedge first touches the tube (zero compression) - see
// the retract-distance-setting design spec for the geometry this default
// comes from. Stored as mm, not a raw step count, so it stays correct if
// microstepping ('u') changes later; RetractSteps() converts using
// whatever microstepping is currently active. Adjustable ('r') because
// small mechanical differences (endstop switch trip-point variance,
// coupler play) aren't identical unit to unit. Report-only for now -
// nothing clamps or gates moves against the resulting first-contact
// position yet.
float RetractDistanceMm = DefaultRetractDistanceMm;

// 0 = Auto (temperature-based), 1 = Forced ON, 2 = Forced OFF
uint8_t FanMode = 0;
bool FanOn = false;
uint32_t FanCooldownUntil = 0;
// Initialized so the very first loop() iteration polls immediately,
// rather than waiting out the first full interval before the fan can
// react to anything.
uint32_t LastFanPollTime = 0 - FanT120PollIntervalMs;

// Same "poll immediately on first loop()" initialization as LastFanPollTime.
uint32_t LastFaultPollTime = 0 - FaultMonitorPollIntervalMs;

int32_t SavedMaxPosition = -1;  // -1 = no valid saved calibration this session

uint8_t  ConsecutiveUnexpectedHits = 0;
uint32_t UnexpectedMinHits = 0;
uint32_t UnexpectedMaxHits = 0;
int32_t  LastMinHitPosition = 0;
int32_t  LastMaxHitPosition = 0;
uint32_t LastMinHitTime = 0;
uint32_t LastMaxHitTime = 0;

// Highest graduated thermal pre-warning threshold (120/143/150/157C) the
// driver has been observed at since the last enable - background-tracked
// in CheckDriverFaults on its regular poll, not just read-when-asked like
// cmd15_DriverDiagnostics's live report, so a brief spike during a long
// unattended run (e.g. the sweep test) doesn't go unnoticed just because
// nobody happened to check 'x' at that exact moment. Doesn't track ot
// (shutdown) - that already disables the stepper and prints its own
// impossible-to-miss ERROR via CheckDriverFaults, so it doesn't need a
// second, easy-to-miss mechanism to be noticed. 0 = never exceeded 120C.
uint16_t HighestTempThresholdC = 0;
uint32_t HighestTempThresholdTime = 0;

long initial_homing = -300;


void LedInfoUserPanic(void);
bool DebounceEndstop(bool rawTriggered, bool &candidateActive, uint32_t &candidateStart);
void MoveAbsWithEndstopGuard(int32_t target);
int32_t SeekEndstopPrecise(int8_t direction, uint8_t endstopPin, bool &triggered);
uint32_t HashBuildTimestamp(void);
String BuildCodename(void);
void UpdateFanControl(void);
void CheckDriverFaults(void);
bool CheckSerialConnection(void);
bool WaitForCommandInput(void);
PersistedSettings LoadPersistedSettings(void);
void SavePersistedSettings(const PersistedSettings &s);
UsageStats LoadUsageStats(void);
void SaveUsageStats(const UsageStats &u);
void UpdateUsageStats(void);
int32_t StepsPerMm(void);
int32_t RetractSteps(void);

// Auto-generated per-build "codename" (adjective-noun pair) plus the exact
// build timestamp, replacing a manually-bumped version string like "2026r5" -
// nobody has to remember to update a version number by hand. The codename is
// deterministic from __DATE__/__TIME__ (same build, same codename every
// time), memorable enough to reference in conversation ("are you on
// Quiet-Valve?"), and the appended timestamp still gives exact precision for
// correlating a running build against `git log` after the fact. Needs no
// build tooling - __DATE__/__TIME__ are standard preprocessor macros, so
// this works identically whether compiled via arduino-cli or the Arduino
// IDE's own Upload button.
const char* const BuildCodenameAdjectives[] = {
  "Steadfast", "Quiet", "Brisk", "Calm", "Vigilant", "Nimble", "Sturdy", "Patient",
  "Silent", "Precise", "Steady", "Gentle", "Resolute", "Swift", "Faithful", "Keen"
};
const char* const BuildCodenameNouns[] = {
  "Bellows", "Valve", "Piston", "Diaphragm", "Manometer", "Airway", "Throttle", "Sentinel",
  "Turbine", "Cylinder", "Spirometer", "Conduit", "Damper", "Regulator", "Chamber", "Current"
};

/* CLI( Command Line Interface)================================================ */

tMenuCmdTxt txt1_EnableStepper[] = "e - enable stepper (normal mode)";
tMenuCmdTxt txt2_DisableStepper[] = "d - disable stepper";
tMenuCmdTxt txt3_Calibrate[] = "c - calibrate min & max";
tMenuCmdTxt txt4_Home[] = "h - home stepper";
tMenuCmdTxt txt5_SafeOperation[] = "o - Operate with in safemode";
tMenuCmdTxt txt6_AbsoluteMove[] = "a - move to absolute position";
tMenuCmdTxt txt7_Status[] = "s - status";
tMenuCmdTxt txt8_Menu[] = "m - menu";
tMenuCmdTxt txt9_Speed[] = "f - speed";
tMenuCmdTxt txt10_Acceleration[] = "g - acceleration";
tMenuCmdTxt txt11_RunCurrent[] = "i - run current (mA)";
tMenuCmdTxt txt12_Microsteps[] = "u - microsteps";
tMenuCmdTxt txt13_EndstopLog[] = "l - endstop event log";
tMenuCmdTxt txt14_HoldPercent[] = "p - hold current (%)";
tMenuCmdTxt txt15_DriverDiagnostics[] = "x - driver fault diagnostics";
tMenuCmdTxt txt16_ToggleChopperMode[] = "t - toggle chopper mode (SpreadCycle/StealthChop)";
tMenuCmdTxt txt17_ToggleFanMode[] = "w - toggle fan mode (Auto/Forced ON/Forced OFF)";
tMenuCmdTxt txt18_SaveSettings[] = "v - save settings (current/speed/accel/microsteps/chopper)";
tMenuCmdTxt txt19_RetractDistance[] = "r - retract distance (first-contact offset)";
tMenuCmdTxt txt20_ResetToDefaults[] = "z - reset to defaults (endstop log + tuning)";
tMenuCmdTxt txt21_VerifyPosition[] = "k - verify position against max endstop (no re-zero)";
tMenuCmdTxt txt22_Retract[] = "y - retract to first-contact position";
tMenuCmdTxt txt_Prompt[] = "Valve";

void cmd1_EnableStepper(void);
void cmd2_DisableStepper(void);
void cmd3_Calibrate(void);
void cmd4_Home(void);
void cmd5_SafeOperation(void);
void cmd6_AbsoluteMove(void);
void cmd7_Status(void);
void cmd8_Menu(void);
void cmd9_Speed(void);
void cmd10_Acceleration(void);
void cmd11_RunCurrent(void);
void cmd12_Microsteps(void);
void cmd13_EndstopLog(void);
void cmd14_HoldPercent(void);
void cmd15_DriverDiagnostics(void);
void cmd16_ToggleChopperMode(void);
void cmd17_ToggleFanMode(void);
void cmd18_SaveSettings(void);
void cmd19_RetractDistance(void);
void cmd20_ResetToDefaults(void);
void cmd21_VerifyPosition(void);
void cmd22_Retract(void);

stMenuCmd list[] = {
    {txt1_EnableStepper, 'e', cmd1_EnableStepper},
    {txt2_DisableStepper, 'd', cmd2_DisableStepper},
    {txt3_Calibrate, 'c', cmd3_Calibrate},
    {txt4_Home, 'h', cmd4_Home},
    {txt5_SafeOperation, 'o', cmd5_SafeOperation},
    {txt6_AbsoluteMove, 'a', cmd6_AbsoluteMove},  
    {txt7_Status, 's', cmd7_Status},  
    {txt8_Menu, 'm', cmd8_Menu},
    {txt9_Speed, 'f', cmd9_Speed},
    {txt10_Acceleration, 'g', cmd10_Acceleration},
    {txt11_RunCurrent, 'i', cmd11_RunCurrent},
    {txt12_Microsteps, 'u', cmd12_Microsteps},
    {txt13_EndstopLog, 'l', cmd13_EndstopLog},
    {txt14_HoldPercent, 'p', cmd14_HoldPercent},
    {txt15_DriverDiagnostics, 'x', cmd15_DriverDiagnostics},
    {txt16_ToggleChopperMode, 't', cmd16_ToggleChopperMode},
    {txt17_ToggleFanMode, 'w', cmd17_ToggleFanMode},
    {txt18_SaveSettings, 'v', cmd18_SaveSettings},
    {txt19_RetractDistance, 'r', cmd19_RetractDistance},
    {txt20_ResetToDefaults, 'z', cmd20_ResetToDefaults},
    {txt21_VerifyPosition, 'k', cmd21_VerifyPosition},
    {txt22_Retract, 'y', cmd22_Retract}
};

#define NbCmds sizeof(list) / sizeof(stMenuCmd)

/* Functions Implementation =================================================== */

void setup()
{
  Serial.begin(115200);

  // Initialize TeensyStep4 backend
  TS4::begin(); 

  motor.setAcceleration(Acceleration)
       .setMaxSpeed(Speed);

  // TMC2209 UART: current + microstepping configuration.
  // STEP/DIR/EN keep working even if this link is absent (see below).
  Serial1.begin(115200);
  driver.begin();
  driver.pdn_disable(true);       // use UART, not PDN_UART as a dedicated pulldown
  driver.mstep_reg_select(true);  // microsteps come from UART register, not MS1/MS2 pins
  driver.I_scale_analog(false);   // use internal voltage reference, not the VREF pin
  if (driver.test_connection() != 0) {
    Serial.println(F("WARNING: TMC2209 UART not detected - check wiring"));
  }
  driver.hold_multiplier(DefaultHoldPercent / 100.0f);
  driver.rms_current(DefaultRunCurrent);
  driver.microsteps(DefaultMicrosteps);
  driver.en_spreadCycle(SpreadCycleEnabled);

  pinMode(EndstopMinPin, INPUT_PULLUP);
  pinMode(EndstopMaxPin, INPUT_PULLUP);
  pinMode(EnablePin, OUTPUT);
  // pinMode() alone does not guarantee an output level - the pin retains
  // whatever it was last driven to before this boot/reset. If the driver
  // was actively enabled (EnablePin LOW) right before a reset, it can
  // still be physically enabled here even though StepperStatus/the LED
  // both say "disabled" below, since those are only software state.
  // Force the real hardware line to the disabled state explicitly so the
  // two can never disagree.
  digitalWrite(EnablePin, HIGH);
  pinMode(LedOnBoard, OUTPUT);
  digitalWrite(LedOnBoard, LOW);
  pinMode(FanControlPin, OUTPUT);
  digitalWrite(FanControlPin, LOW);
  heatSinkTempSensor.begin();
  HeatSinkSensorPresent = heatSinkTempSensor.getDS18Count() > 0;

  PersistedSettings saved = LoadPersistedSettings();
  if (saved.tuningValid) {
    RunCurrentMa = saved.runCurrentMa;
    HoldPercent = saved.holdPercent;
    Speed = saved.speed;
    Acceleration = saved.acceleration;
    driver.hold_multiplier(HoldPercent / 100.0f);
    driver.rms_current(RunCurrentMa);
    driver.microsteps(saved.microsteps);
    SpreadCycleEnabled = saved.spreadCycleEnabled;
    driver.en_spreadCycle(SpreadCycleEnabled);
    RetractDistanceMm = saved.retractDistanceMm;
    motor.setMaxSpeed(Speed);
    motor.setAcceleration(Acceleration);
    Serial.println(F("Loaded saved tuning settings from EEPROM."));
  }
  if (saved.calibrationValid) {
    SavedMaxPosition = saved.lastCalibratedMaxPosition;
  }

  StepperStatus = 0;
  LedOnTime = 1000;
  LedOffTime = 1000;
  tEvent = 0;
  Software = BuildCodename();

  if (myMmuCmd.begin(list, NbCmds, txt_Prompt) == false)
  {
    while (true) { LedInfoUserPanic(); }
  }

  myMmuCmd.ShowMenu();
  myMmuCmd.giveCmdPrompt();
}

void loop()
{
  uint8_t CmdCode = myMmuCmd.UserRequest();

  if (CmdCode != 0)
  {
    myMmuCmd.ExeCommand(CmdCode);
  }

  UpdateFanControl();
  CheckDriverFaults();
  CheckSerialConnection();
  UpdateUsageStats();

  switch(StepperStatus)
  {
    case 0: 
      if(digitalRead(LedOnBoard) == true) digitalWrite(LedOnBoard, false);
      break;
    case 1: 
      if(digitalRead(LedOnBoard) == false) digitalWrite(LedOnBoard, true);
      break;
    case 2:
      if(millis() >= tEvent)
      {
        tEvent = millis() + (digitalRead(LedOnBoard) ? LedOffTime : LedOnTime);
        digitalWrite(LedOnBoard, !digitalRead(LedOnBoard));
      }
      break;
  }
}

void LedInfoUserPanic(void)
{
  digitalWrite(LedOnBoard, HIGH); delay(100);
  digitalWrite(LedOnBoard, LOW);  delay(100);
}

// djb2 string hash - not security-sensitive, just needs to spread build
// timestamps across the codename word lists reasonably evenly.
uint32_t HashBuildTimestamp(void)
{
  const char* ts = __DATE__ " " __TIME__;
  uint32_t hash = 5381;
  for (const char* p = ts; *p; p++) {
    hash = ((hash << 5) + hash) + (uint8_t)*p;
  }
  return hash;
}

String BuildCodename(void)
{
  uint32_t hash = HashBuildTimestamp();
  uint8_t adjCount = sizeof(BuildCodenameAdjectives) / sizeof(BuildCodenameAdjectives[0]);
  uint8_t nounCount = sizeof(BuildCodenameNouns) / sizeof(BuildCodenameNouns[0]);
  const char* adj = BuildCodenameAdjectives[hash % adjCount];
  const char* noun = BuildCodenameNouns[(hash / adjCount) % nounCount];
  return String(adj) + "-" + String(noun) + " (" + __DATE__ " " __TIME__ ")";
}

bool DebounceEndstop(bool rawTriggered, bool &candidateActive, uint32_t &candidateStart)
{
  if (rawTriggered) {
    if (!candidateActive) {
      candidateActive = true;
      candidateStart = millis();
      return false;
    }
    return (millis() - candidateStart >= EndstopDebounceMs);
  } else {
    candidateActive = false;
    return false;
  }
}

// Drives the cooling fan. In Auto mode, polls DRV_STATUS's live t120
// (120C) comparator on a timer - never called from inside
// MoveAbsWithEndstopGuard's or SeekEndstopPrecise's tight motion-polling
// loops, so this never adds UART latency to endstop-detection
// responsiveness during a move. Fails safe: if the UART link is down
// (temperature can't be confirmed), treats it as hot rather than cool.
void UpdateFanControl(void)
{
  if (FanMode == 1) {
    FanOn = true;
  } else if (FanMode == 2) {
    FanOn = false;
  } else {
    uint32_t now = millis();
    if (now - LastFanPollTime >= FanT120PollIntervalMs) {
      LastFanPollTime = now;
      bool hot;
      if (driver.test_connection() != 0) {
        hot = true;  // fail-safe: can't confirm temperature, assume hot
      } else {
        TMC2208_n::DRV_STATUS_t status;
        status.sr = driver.DRV_STATUS();
        hot = status.t120;
      }
      if (hot) {
        FanOn = true;
        FanCooldownUntil = now + FanCooldownMs;
      } else if ((int32_t)(now - FanCooldownUntil) >= 0) {
        FanOn = false;
      }
      // else: t120 has cleared but we're still within the cool-down
      // window - leave FanOn as it is (true) until the delay expires.
    }
  }
  digitalWrite(FanControlPin, FanOn ? HIGH : LOW);
}

// Independently polls DRV_STATUS for genuine faults (thermal shutdown,
// short-to-ground, short-to-supply) and, on the same read, background-
// updates HighestTempThresholdC (see its declaration) - the graduated
// thermal pre-warnings (t120/t143/t150/t157) stay informational-only here,
// same as UpdateFanControl's own t120 response, but are now also recorded
// for later reporting rather than only ever read live. Runs on its own
// timer, regardless of FanMode, so fault detection doesn't stop just
// because the fan is in Forced mode. Only acts while the stepper is
// currently enabled, so it can't re-trigger every poll once already
// disabled.
void CheckDriverFaults(void)
{
  uint32_t now = millis();
  if (now - LastFaultPollTime < FaultMonitorPollIntervalMs) {
    return;
  }
  LastFaultPollTime = now;

  if (StepperStatus != 1) {
    return;
  }
  if (driver.test_connection() != 0) {
    return;  // can't confirm fault state over a dead link - nothing to act on
  }

  TMC2208_n::DRV_STATUS_t status;
  status.sr = driver.DRV_STATUS();

  uint16_t observedThresholdC = status.t157 ? 157 : status.t150 ? 150 : status.t143 ? 143 : status.t120 ? 120 : 0;
  if (observedThresholdC > HighestTempThresholdC) {
    HighestTempThresholdC = observedThresholdC;
    HighestTempThresholdTime = now;
  }

  if (!(status.ot || status.s2ga || status.s2gb || status.s2vsa || status.s2vsb)) {
    return;
  }

  StepperStatus = 0;
  digitalWrite(EnablePin, HIGH);
  // Disabling removes holding torque - the mechanism can be moved by hand
  // while disabled, so previously tracked position/calibration is no
  // longer trustworthy. Same reasoning as cmd2_DisableStepper.
  CalibrationStatus = 0;
  Serial.print(F("\nERROR: Driver fault detected - stepper disabled. ("));
  if (status.ot) Serial.print(F("overtemperature shutdown "));
  if (status.s2ga) Serial.print(F("short-to-GND phase A "));
  if (status.s2gb) Serial.print(F("short-to-GND phase B "));
  if (status.s2vsa) Serial.print(F("short-to-supply phase A "));
  if (status.s2vsb) Serial.print(F("short-to-supply phase B "));
  Serial.println(F(") Investigate before re-enabling (e)."));
}

// Whenever the driver is currently energized (EnablePin LOW) and no host
// has the serial port open, disables it the same way cmd2_DisableStepper
// does. Gates on the actual hardware pin state rather than StepperStatus
// because cmd3_Calibrate drives EnablePin LOW directly without
// necessarily going through StepperStatus - this way the check is
// correct for every path that can energize the driver, not just normal
// moves. Self-latching: once it disables, EnablePin reads HIGH, so this
// is a no-op on every subsequent call until something re-enables the
// driver. Returns true when it just performed a disable, so a caller
// inside a motion-polling loop knows to abort immediately.
bool CheckSerialConnection(void)
{
  if (Serial || digitalRead(EnablePin) == HIGH) return false;
  if (motor.isMoving) motor.emergencyStop();
  StepperStatus = 0;
  CalibrationStatus = 0;
  digitalWrite(EnablePin, HIGH);
  Serial.println(F("\nSerial connection lost - stepper disabled. Reconnect and use 'e' to re-enable (recalibrate 'c' before moving)."));
  return true;
}

uint32_t SessionEnabledMs = 0;          // RAM-only, raw ms; resets every boot -
                                         // "Session Run Time". Deliberately never
                                         // divided per-iteration (unlike a seconds
                                         // counter would be) - loop() iterates many
                                         // times a second while idle, so a per-call
                                         // elapsedMs/1000 would truncate to 0 almost
                                         // every time and the remainder would never
                                         // be recovered. Converted to hours only when
                                         // read/displayed.
uint32_t PendingEnabledMs = 0;          // accumulated since last EEPROM flush
float    PendingDistanceMeters = 0.0f;  // accumulated since last EEPROM flush
uint32_t PendingMinHits = 0;           // accumulated since last EEPROM flush
uint32_t PendingMaxHits = 0;           // accumulated since last EEPROM flush
float    PendingPeakHeatSinkTempC = DEVICE_DISCONNECTED_C;  // highest reading seen since last EEPROM flush
bool     WasEnabledLastUsageCheck = false;
uint32_t LastUsageCheckMillis = 0;
int32_t  LastPolledPosition = 0;
uint32_t LastUsageFlushMillis = 0;

#define UsageFlushIntervalMs (10UL * 60UL * 1000UL)  // 10 minutes

// Polls EnablePin and the motor's position once per loop() iteration,
// rather than hooking every individual enable/disable/move call site
// (cmd1/cmd2/cmd3, disconnect auto-disable, fault auto-disable, homing,
// sweep moves, ...) - this way nothing can be missed as new call sites
// get added later. Flushes accumulated time/distance to EEPROM on every
// enable->disable transition (the common case) plus a periodic backstop
// during any single long continuous enabled stretch, bounding worst-case
// data loss from a hard power cut without meaningfully adding EEPROM wear.
//
// Known accepted gap: a disconnect that lands mid-move (CheckSerialConnection
// disabling EnablePin from inside SeekEndstopPrecise/MoveAbsWithEndstopGuard/
// cmd4_Home's polling loops, none of which call this function) drops that
// move's enabled-time credit entirely, since by the time loop() polls again
// EnablePin already reads HIGH. Distance is unaffected (position is read
// unconditionally). Narrow edge case, under-counts only by at most one
// move's duration - accepted rather than instrumenting those loops
// individually, which is exactly the per-call-site coupling this polling
// design avoids.
void UpdateUsageStats(void)
{
  uint32_t now = millis();
  bool enabled = (digitalRead(EnablePin) == LOW);

  if (enabled) {
    uint32_t elapsedMs = now - LastUsageCheckMillis;
    PendingEnabledMs += elapsedMs;
    SessionEnabledMs += elapsedMs;
  }
  LastUsageCheckMillis = now;

  int32_t pos = motor.getPosition();
  if (pos != LastPolledPosition) {
    int32_t deltaSteps = abs(pos - LastPolledPosition);
    // Convert at accumulation time using the *current* StepsPerMm(), so a
    // later microstepping change never retroactively distorts previously
    // accumulated history.
    PendingDistanceMeters += deltaSteps / (StepsPerMm() * 1000.0f);
    LastPolledPosition = pos;
  }

  bool justDisabled = (WasEnabledLastUsageCheck && !enabled);
  bool periodicFlushDue = (now - LastUsageFlushMillis >= UsageFlushIntervalMs);
  if (justDisabled || periodicFlushDue) {
    UsageStats u = LoadUsageStats();
    u.totalEnabledSeconds += PendingEnabledMs / 1000;
    u.totalDistanceMeters += PendingDistanceMeters;
    u.totalMinHits += PendingMinHits;
    u.totalMaxHits += PendingMaxHits;
    if (PendingPeakHeatSinkTempC != DEVICE_DISCONNECTED_C && PendingPeakHeatSinkTempC > u.peakHeatSinkTempC) {
      u.peakHeatSinkTempC = PendingPeakHeatSinkTempC;
    }
    SaveUsageStats(u);
    PendingEnabledMs %= 1000;  // carry the sub-second remainder forward, don't discard it
    PendingDistanceMeters = 0.0f;
    PendingMinHits = 0;
    PendingMaxHits = 0;
    PendingPeakHeatSinkTempC = DEVICE_DISCONNECTED_C;
    LastUsageFlushMillis = now;
  }
  WasEnabledLastUsageCheck = enabled;
}

// Waits for the second half of a two-step command's input (e.g. 'f' then
// the actual speed number) without blocking the background safety checks
// a bare `while(!Serial.available()) yield();` loop would - the very gap
// this closes: if a client sends the command character but then never
// sends the value (a crash, a bug, a connection dropped at exactly the
// wrong moment), that bare loop would hang forever, and disconnect
// detection, driver fault monitoring, and fan control would all silently
// stop running until something eventually arrives. Returns true once
// input has arrived; false means the caller should abandon the command
// and return to the prompt without reading anything further - either the
// link just died (CheckSerialConnection already printed its own message)
// or the wait timed out (this prints its own message for that case).
bool WaitForCommandInput(void)
{
  uint32_t deadline = millis() + CommandInputTimeoutMs;
  while (!Serial.available()) {
    if (CheckSerialConnection()) return false;
    CheckDriverFaults();
    UpdateFanControl();
    if ((int32_t)(millis() - deadline) >= 0) {
      Serial.println(F("\nERROR: timed out waiting for input - command cancelled."));
      return false;
    }
    yield();
  }
  return true;
}

// Reads the persisted struct if the EEPROM region is valid (magic +
// version match this firmware), or returns a zeroed struct - both
// tuningValid and calibrationValid explicitly false - if nothing's ever
// been saved (fresh Teensy) or the stored data doesn't match this
// firmware's schema. Callers must check the relevant *Valid flag before
// trusting the fields it guards.
PersistedSettings LoadPersistedSettings(void)
{
  PersistedSettings s;
  EEPROM.get(PersistedSettingsEepromAddress, s);
  if (s.magic != PersistedSettingsMagic || s.version != PersistedSettingsVersion) {
    memset(&s, 0, sizeof(s));
  }
  return s;
}

void SavePersistedSettings(const PersistedSettings &s)
{
  EEPROM.put(PersistedSettingsEepromAddress, s);
}

// Same validity pattern as LoadPersistedSettings(): a magic/version
// mismatch (including a totally fresh, never-written Teensy) returns a
// zeroed-and-reinitialized struct rather than garbage. Unlike
// LoadPersistedSettings(), there's no "valid" flag for callers to check
// first - a fresh UsageStats is simply "zero history", which is exactly
// the right starting value, not a state callers need to guard against
// trusting.
UsageStats LoadUsageStats(void)
{
  UsageStats u;
  EEPROM.get(UsageStatsEepromAddress, u);
  if (u.magic != UsageStatsMagic || u.version != UsageStatsVersion) {
    memset(&u, 0, sizeof(u));
    u.magic = UsageStatsMagic;
    u.version = UsageStatsVersion;
    u.peakHeatSinkTempC = DEVICE_DISCONNECTED_C;  // 0.0 from memset would misread as a real recorded peak
  }
  return u;
}

void SaveUsageStats(const UsageStats &u)
{
  EEPROM.put(UsageStatsEepromAddress, u);
}

// Steps per mm of wedge travel: 1.8-degree stepper (200 full steps/rev)
// through a TR8x2 leadscrew (2mm lead), at the driver's *current*
// microstepping setting. driver.microsteps() can read back as 0, which
// in this firmware's convention (see cmd12_Microsteps) means full-step
// mode (1x), not literally zero microsteps - treated as 1 here so this
// never scales out to zero.
int32_t StepsPerMm(void)
{
  int32_t microsteps = driver.microsteps();
  if (microsteps == 0) microsteps = 1;
  return 100 * microsteps;  // (200 full steps/rev * microsteps) / 2mm lead
}

// RetractDistanceMm converted to steps at the CURRENT microstepping
// setting - recomputed on every call rather than cached, so the result
// always reflects the same physical distance even if microsteps ('u')
// was changed since RetractDistanceMm was last set.
int32_t RetractSteps(void)
{
  return (int32_t)(RetractDistanceMm * StepsPerMm() + 0.5f);
}

void cmd1_EnableStepper(void)
{
  StepperStatus = 1;  
  ConsecutiveUnexpectedHits = 0;
  Serial.println(F("\nStepper enabled in normal mode\n"));
  digitalWrite(EnablePin, LOW);
  myMmuCmd.giveCmdPrompt();
}

void cmd2_DisableStepper(void)
{
  StepperStatus = 0;
  // Disabling removes holding torque - the mechanism can be moved by hand
  // while disabled, so any previously tracked position/calibration is no
  // longer trustworthy. Force a fresh 'c' before cmd6_AbsoluteMove's
  // calibration gate will allow a move again.
  CalibrationStatus = 0;
  Serial.println(F("\nStepper disabled. Position tracking is no longer trustworthy - recalibrate ('c') before moving.\n"));
  digitalWrite(EnablePin, HIGH);
  myMmuCmd.giveCmdPrompt();
}

// Seeks the given endstop precisely: fast approach until the first
// trigger, back off away from the switch, then a slow re-approach until
// it triggers again. The slow second trigger is far more repeatable than
// the fast first one - momentum and switch bounce at full speed vary
// run to run, but a slow, controlled final approach doesn't have that
// problem. direction is +1 or -1 (steps move toward the target endstop).
// Sets triggered to true only if a real trigger occurred (either phase);
// false means a move ran out of travel without hitting the switch. The
// caller must not trust the returned position when triggered is false -
// it reflects wherever the untriggered move happened to stop, not a real
// endstop position.
int32_t SeekEndstopPrecise(int8_t direction, uint8_t endstopPin, bool &triggered)
{
  triggered = false;

  // Phase 1: fast approach - always at the fixed HomingSpeed/
  // HomingAcceleration, not whatever the general Speed/Acceleration
  // happen to be configured to (see fixed-homing-speed design spec).
  // The general values are restored by cmd3_Calibrate once both seeks
  // are done, not here - SeekEndstopPrecise has too many early-return
  // paths (disconnects, the Stage B stuck-switch abort) to restore
  // cleanly at each one.
  motor.setMaxSpeed(HomingSpeed);
  motor.setAcceleration(HomingAcceleration);
  motor.moveRelAsync(direction * 100000);
  while (motor.isMoving) {
    if (CheckSerialConnection()) return motor.getPosition();
    if (digitalRead(endstopPin) == HIGH) {
      motor.emergencyStop();
      triggered = true;
      if (endstopPin == EndstopMinPin) PendingMinHits++; else PendingMaxHits++;
      break;
    }
    yield();
  }
  if (!triggered) {
    // No stray restore here - cmd3_Calibrate unconditionally restores
    // Speed/Acceleration on every exit path, including this one.
    return motor.getPosition();
  }

  // Phase 2, Stage A: unconditional minimum back-off away from the switch.
  // triggered is still true here (left over from phase 1's success) -
  // every early return below must explicitly clear it, or the caller
  // would wrongly read an aborted seek as having succeeded.
  int32_t positionBeforeBackoff = motor.getPosition();
  int32_t backoffMinSteps = (int32_t)(HomingBackoffMinDistanceMm * StepsPerMm() + 0.5f);
  int32_t backoffMaxSteps = (int32_t)(HomingBackoffMaxDistanceMm * StepsPerMm() + 0.5f);
  motor.moveRelAsync(-direction * backoffMinSteps);
  while (motor.isMoving) {
    if (CheckSerialConnection()) { triggered = false; return motor.getPosition(); }
    yield();
  }

  // Phase 2, Stage B: the 3mm minimum doesn't always clear every switch -
  // if it's still triggered, keep backing off while monitoring for
  // release, up to the safety cap. Only runs when Stage A wasn't enough.
  if (digitalRead(endstopPin) == HIGH) {
    bool released = false;
    motor.moveRelAsync(-direction * (backoffMaxSteps - backoffMinSteps));
    while (motor.isMoving) {
      if (CheckSerialConnection()) { triggered = false; return motor.getPosition(); }
      if (digitalRead(endstopPin) == LOW) {
        motor.emergencyStop();
        released = true;
        break;
      }
      yield();
    }
    if (!released) {
      Serial.printf("ERROR: %s endstop did not release after backing off %.1fmm - switch may be stuck or miswired.\n",
                    endstopPin == EndstopMinPin ? "Min" : "Max", HomingBackoffMaxDistanceMm);
      triggered = false;
      return motor.getPosition();
    }
  }

  // Phase 2 is done - figure out how far it actually backed off (Stage B's
  // emergencyStop() on release can land anywhere along its path, not just
  // at the 3mm or 10mm marks, so this can't be assumed - it's read back
  // from the real position change). Multiplying by -direction turns the
  // signed delta into a plain positive distance, since back-off always
  // moves in the -direction sense.
  int32_t actualBackoffSteps = (motor.getPosition() - positionBeforeBackoff) * -direction;

  // Phase 3: slow re-approach - trust this trigger point. Travels back
  // however far phase 2 actually moved (not a fixed guess), plus the
  // existing overtravel margin, so it always reaches the switch again
  // even if Stage B had to extend the back-off.
  triggered = false;
  motor.setMaxSpeed(HomingSlowSpeed);
  motor.moveRelAsync(direction * (actualBackoffSteps + HomingOvertravelMargin));
  while (motor.isMoving) {
    if (CheckSerialConnection()) return motor.getPosition();
    if (digitalRead(endstopPin) == HIGH) {
      motor.emergencyStop();
      triggered = true;
      if (endstopPin == EndstopMinPin) PendingMinHits++; else PendingMaxHits++;
      break;
    }
    yield();
  }

  // No stray restore here either - cmd3_Calibrate unconditionally
  // restores Speed/Acceleration on every exit path, including this one.
  return motor.getPosition();
}

void cmd3_Calibrate(void)
{
  Serial.println(F("\nStarting calibration..."));
  ConsecutiveUnexpectedHits = 0;
  digitalWrite(EnablePin, LOW);

  // Invalidate any prior calibration up front, not just on success below -
  // otherwise a re-calibration that fails partway through (e.g. min seek
  // re-zeros the coordinate frame, then max seek fails to trigger) would
  // leave CalibrationStatus/MaxPosition at their old values, computed
  // against a zero point that no longer matches the physical setup -
  // stale state cmd6_AbsoluteMove's calibration gate has no way to detect.
  CalibrationStatus = 0;

  bool minTriggered;
  SeekEndstopPrecise(-1, EndstopMinPin, minTriggered);
  if (!minTriggered) {
    motor.setMaxSpeed(Speed);
    motor.setAcceleration(Acceleration);
    Serial.println(F("ERROR: Min endstop not found - calibration aborted."));
    myMmuCmd.giveCmdPrompt();
    return;
  }
  // Capture this seek's distance against the OLD coordinate frame before
  // setPosition(0) below redefines "0" to be wherever the carriage physically
  // is right now. Without this, UpdateUsageStats()'s next poll (after this
  // whole blocking function returns) would compute abs(new-frame-position -
  // old-frame-LastPolledPosition) - two positions expressed in different
  // frames - silently dropping this entire seek's distance (worst case: on
  // the very first calibration after a fresh flash, when the pre-calibration
  // position is the compiled-in default, not the true physical min endstop).
  UpdateUsageStats();
  motor.setPosition(0);
  LastPolledPosition = 0;  // resync the tracker to the frame that was just redefined - the carriage didn't move, only its coordinate label did
  Serial.println(F("Min Endstop found. Position set to 0."));
  delay(500);

  bool maxTriggered;
  int32_t maxPos = SeekEndstopPrecise(1, EndstopMaxPin, maxTriggered);
  if (!maxTriggered) {
    motor.setMaxSpeed(Speed);
    motor.setAcceleration(Acceleration);
    Serial.println(F("ERROR: Max endstop not found - calibration aborted."));
    myMmuCmd.giveCmdPrompt();
    return;
  }
  motor.setMaxSpeed(Speed);
  motor.setAcceleration(Acceleration);
  MaxPosition = maxPos;
  CalibrationStatus = 1;

  PersistedSettings s = LoadPersistedSettings();  // preserve tuningValid/tuning fields untouched
  int32_t previousSaved = s.calibrationValid ? s.lastCalibratedMaxPosition : -1;
  // Only actually write when something's changing - a sweep test's recovery
  // path alone can call 'c' dozens of times in a session, and the emulated
  // EEPROM's flash has finite write endurance. Re-saving the exact same
  // value every time wears it for no benefit.
  if (!s.calibrationValid || previousSaved != MaxPosition) {
    s.magic = PersistedSettingsMagic;
    s.version = PersistedSettingsVersion;
    s.calibrationValid = true;
    s.lastCalibratedMaxPosition = MaxPosition;
    SavePersistedSettings(s);
  }
  SavedMaxPosition = MaxPosition;

  Serial.printf("Max Endstop found. Max Position: %d", MaxPosition);
  if (previousSaved >= 0) {
    Serial.printf(" (previous saved: %d, diff: %+d)", previousSaved, MaxPosition - previousSaved);
  } else {
    Serial.print(F(" (no previous saved value to compare)"));
  }
  Serial.println();
  Serial.printf("First-contact position (retract %.3f mm): %d\n", RetractDistanceMm, MaxPosition - RetractSteps());
  Serial.println();
  myMmuCmd.giveCmdPrompt();
}

void cmd4_Home(void)
{
  if (CalibrationStatus != 1) {
    Serial.println(F("\nError: Must calibrate ('c') before homing."));
  } else {
    Serial.println(F("\nHoming to position 0..."));
    motor.setMaxSpeed(HomingSpeed);
    motor.setAcceleration(HomingAcceleration);
    motor.moveAbsAsync(0);
    bool aborted = false;
    while (motor.isMoving) {
      if (CheckSerialConnection()) { aborted = true; break; }
      yield();
    }
    motor.setMaxSpeed(Speed);
    motor.setAcceleration(Acceleration);
    if (!aborted) {
      Serial.println(F("Homing completed.\n"));
    }
  }
  myMmuCmd.giveCmdPrompt();
}

// Unlike cmd3_Calibrate, this does NOT re-zero at the min endstop first -
// it seeks the max endstop from wherever the carriage currently is. That's
// the point: motor.getPosition() is an open-loop commanded-pulse count, so
// if steps were lost by an intervening move (a stepper stall/skip that
// doesn't itself trip a switch), the tracked position silently drifts from
// physical reality - but a full 'c' would never reveal that, since it
// always re-anchors to a known-good zero at the min switch before counting
// anything, erasing whatever drift happened before it ran. This seek is
// physically grounded (it stops on the real switch) with nothing reset
// beforehand, so the resulting position carries that drift forward:
// comparing it against a previously trusted position (e.g. a sweep test's
// baseline) exposes missed steps a full recalibration would mask. Reports
// but does not persist anything - MaxPosition/EEPROM/CalibrationStatus are
// untouched, since a mismatch here means the tracked position is suspect,
// not that a new value should be trusted.
void cmd21_VerifyPosition(void)
{
  if (CalibrationStatus != 1) {
    Serial.println(F("\nError: Must calibrate ('c') before verifying position."));
    myMmuCmd.giveCmdPrompt();
    return;
  }
  // Leading newline breaks this cleanly onto its own line after the
  // command-character echo, matching cmd3_Calibrate/cmd4_Home - without
  // it, the result below would run together with the echoed 'k' on one
  // line, which sweep.py's line-anchored regex wouldn't match.
  Serial.println(F("\nVerifying position..."));
  digitalWrite(EnablePin, LOW);
  bool maxTriggered;
  int32_t verifiedPosition = SeekEndstopPrecise(1, EndstopMaxPin, maxTriggered);
  motor.setMaxSpeed(Speed);
  motor.setAcceleration(Acceleration);
  if (!maxTriggered) {
    Serial.println(F("ERROR: Max endstop not found - position verify aborted."));
    myMmuCmd.giveCmdPrompt();
    return;
  }
  Serial.printf("Position verified against Max endstop: %d\n", verifiedPosition);
  myMmuCmd.giveCmdPrompt();
}

void cmd22_Retract(void)
{
  int32_t target = MaxPosition - RetractSteps();
  if (CalibrationStatus != 1) {
    Serial.println(F("Error: Must calibrate ('c') before retracting."));
  } else if (target < 0 || target > MaxPosition) {
    Serial.println(F("Error: Target out of calibrated bounds!"));
  } else {
    Serial.printf("Retracting to First-Contact position: %d\n", target);
    MoveAbsWithEndstopGuard(target);
  }
  myMmuCmd.giveCmdPrompt();
}

void cmd5_SafeOperation(void)
{
  Serial.println(F("\nSafe mode verified. Soft limits active."));
  myMmuCmd.giveCmdPrompt();
}

// Drives an absolute move while guarding against an unexpected endstop hit.
// On a debounce-confirmed hit: stop, correct the tracked position to the known
// calibrated endstop value, log it, and retry the same move from the corrected
// position - up to MaxConsecutiveUnexpectedHits attempts before disabling the
// stepper and requiring manual re-enable (see cmd1_EnableStepper).
void MoveAbsWithEndstopGuard(int32_t target)
{
  uint8_t suppressedEndstopPin = 0;  // 0 = none suppressed
  uint32_t suppressUntil = 0;

  // The carriage may already be resting on an endstop when this move starts -
  // calibration and homing both always finish with a switch triggered, and
  // every move issued right after one of them (e.g. the sweep test's move-
  // then-verify cycle, or a user 'a' right after 'c'/'h') would otherwise
  // have its very first poll below read that pre-existing contact as a brand
  // new hit, before the carriage has had any chance to physically move off
  // the switch. Arm the same grace-window suppression the retry path below
  // uses after an in-call correction, but proactively here at entry.
  if (digitalRead(EndstopMinPin) == HIGH) {
    suppressedEndstopPin = EndstopMinPin;
    suppressUntil = millis() + EndstopResumeGraceMs;
  } else if (digitalRead(EndstopMaxPin) == HIGH) {
    suppressedEndstopPin = EndstopMaxPin;
    suppressUntil = millis() + EndstopResumeGraceMs;
  }

  while (true) {
    motor.moveAbsAsync(target);

    bool minCandidateActive = false, maxCandidateActive = false;
    uint32_t minCandidateStart = 0, maxCandidateStart = 0;
    bool hitDetected = false, hitWasMin = false;

    while (motor.isMoving) {
      if (CheckSerialConnection()) return;

      bool minRaw = digitalRead(EndstopMinPin) == HIGH;
      bool maxRaw = digitalRead(EndstopMaxPin) == HIGH;

      // Right after a correction, the carriage is still physically resting
      // against the switch it just hit - the very next poll would otherwise
      // read that same genuine contact as a brand new hit. Suppress only
      // that specific pin, only briefly, so real clearance has time to
      // happen before this guard trusts it again.
      //
      // Tradeoff: a genuine re-hit on this same pin within the grace window
      // is also masked, not just lingering contact - acceptable because the
      // retry always moves toward target (already validated against
      // calibrated bounds), i.e. away from the endstop it just corrected
      // against.
      if (suppressedEndstopPin == EndstopMinPin && millis() < suppressUntil) minRaw = false;
      if (suppressedEndstopPin == EndstopMaxPin && millis() < suppressUntil) maxRaw = false;

      bool minHit = DebounceEndstop(minRaw, minCandidateActive, minCandidateStart);
      // min/max are physically mutually exclusive (opposite ends of travel), so
      // prioritizing a min hit over a max hit within one poll iteration is safe.
      bool maxHit = !minHit && DebounceEndstop(maxRaw, maxCandidateActive, maxCandidateStart);

      if (minHit || maxHit) {
        hitDetected = true;
        hitWasMin = minHit;
        // Counts every real physical contact here, including ones later
        // found to be an intentional arrival at a calibrated endstop -
        // the switch was still physically triggered either way.
        if (hitWasMin) PendingMinHits++; else PendingMaxHits++;
        // emergencyStop() (not stop()) is required here: stop() only begins a
        // gradual deceleration that plays out over many further ISR ticks with
        // isMoving still true, which would let the motor keep traveling toward
        // the endstop and would race the retry's next moveAbsAsync() call
        // (its new-timer attach is gated on isMoving being false already).
        // emergencyStop() halts synchronously and clears isMoving immediately.
        motor.emergencyStop();
        break;
      }
      yield();
    }

    if (!hitDetected) {
      Serial.println(F("Move complete."));
      ConsecutiveUnexpectedHits = 0;
      return;
    }

    // Same coordinate-frame class of gap as cmd3_Calibrate's setPosition(0)
    // (see its comment) applies to the two motor.setPosition(correctedPosition)
    // calls below: UpdateUsageStats() doesn't run between the stale distance
    // poll and this correction, so a small slice of the retry's distance can
    // go uncounted. Left unfixed here (unlike calibration) because this is a
    // fault/drift-correction path, not the common-case flow, and the
    // magnitude is bounded by whatever drift triggered the unexpected hit in
    // the first place - typically a few steps, not a full-travel seek.
    int32_t correctedPosition = hitWasMin ? 0 : MaxPosition;

    // A hit exactly at the position this move was already headed to isn't a
    // fault - it's the move successfully reaching a target that happens to
    // sit right at a calibrated endstop (e.g. a caller intentionally
    // driving to 0 or MaxPosition). Treating it as "unexpected" would
    // misclassify a normal, successful arrival as a fault, and enough of
    // these in a row would disable the stepper for no reason.
    if (target == correctedPosition) {
      motor.setPosition(correctedPosition);
      Serial.println(F("Move complete."));
      ConsecutiveUnexpectedHits = 0;
      return;
    }

    motor.setPosition(correctedPosition);

    if (hitWasMin) {
      UnexpectedMinHits++;
      LastMinHitPosition = correctedPosition;
      LastMinHitTime = millis();
    } else {
      UnexpectedMaxHits++;
      LastMaxHitPosition = correctedPosition;
      LastMaxHitTime = millis();
    }

    ConsecutiveUnexpectedHits++;
    Serial.printf("WARNING: Unexpected %s endstop hit! Position auto-corrected to %d.\n",
                  hitWasMin ? "MIN" : "MAX", correctedPosition);

    if (ConsecutiveUnexpectedHits >= MaxConsecutiveUnexpectedHits) {
      Serial.println(F("ERROR: Repeated unexpected endstop hits - stepper disabled. Investigate before re-enabling (e)."));
      StepperStatus = 0;
      digitalWrite(EnablePin, HIGH);
      // Disabling removes holding torque - the mechanism can be moved by hand
      // while disabled, so previously tracked position/calibration is no
      // longer trustworthy. Same reasoning as cmd2_DisableStepper and
      // CheckDriverFaults.
      CalibrationStatus = 0;
      return;
    }

    suppressedEndstopPin = hitWasMin ? EndstopMinPin : EndstopMaxPin;
    suppressUntil = millis() + EndstopResumeGraceMs;

    Serial.println(F("Resuming toward original target..."));
    // loop retries the move toward the same target from the corrected position
  }
}

void cmd6_AbsoluteMove(void)
{
  Serial.println(F("\nEnter absolute target position (steps):"));
  if (!WaitForCommandInput()) {
    myMmuCmd.giveCmdPrompt();
    return;
  }

  int32_t target = Serial.parseInt();

  if (CalibrationStatus != 1) {
    Serial.println(F("Error: Must calibrate ('c') before moving."));
  } else if (target < 0 || target > MaxPosition) {
    Serial.println(F("Error: Target out of calibrated bounds!"));
  } else {
    Serial.printf("Moving to absolute position: %d\n", target);
    MoveAbsWithEndstopGuard(target);
  }
  myMmuCmd.giveCmdPrompt();
}

void cmd7_Status(void)
{
  CurrentPosition = motor.getPosition();
  Serial.println(F("\n--- SYSTEM STATUS ---"));
  Serial.printf("Software Version: %s\n", Software.c_str());
  Serial.printf("Device ID:        %08lX%08lX\n", (unsigned long)HW_OCOTP_CFG1, (unsigned long)HW_OCOTP_CFG0);
  Serial.printf("Stepper Enabled:  %s\n", StepperStatus == 1 ? "YES" : "NO");
  Serial.printf("Current Position: %d steps\n", CurrentPosition);
  if (CalibrationStatus) {
    Serial.printf("Max Range Limit:  %d steps\n", MaxPosition);
  } else {
    // Same "don't trust this until calibrated" reasoning as First-Contact
    // below - MaxPosition still holds whatever it was last set to (the
    // compiled-in default, or a stale value from before a disable/fault/
    // disconnect/microstep-change invalidated it), not a real measurement.
    Serial.printf("Max Range Limit:  %d steps (stale - not calibrated)\n", MaxPosition);
  }
  Serial.printf("Calibrated:       %s\n", CalibrationStatus ? "YES" : "NO");
  if (SavedMaxPosition >= 0) {
    Serial.printf("Saved Max Pos:    %d steps\n", SavedMaxPosition);
  } else {
    Serial.println(F("Saved Max Pos:    none"));
  }
  Serial.printf("Retract Distance: %d steps (%.3f mm)\n", RetractSteps(), RetractDistanceMm);
  if (CalibrationStatus) {
    Serial.printf("First-Contact:    %d steps\n", MaxPosition - RetractSteps());
  } else {
    Serial.println(F("First-Contact:    unavailable (not calibrated)"));
  }
  Serial.printf("Current Speed:    %d steps/s\n", Speed);
  Serial.printf("Acceleration:     %d steps/s²\n", Acceleration);
  Serial.printf("Run Current:      %d mA\n", driver.rms_current());
  Serial.printf("Hold Current:     %d%%\n", HoldPercent);
  Serial.printf("Microsteps:       %d\n", driver.microsteps());
  Serial.printf("Chopper Mode:     %s\n", SpreadCycleEnabled ? "SpreadCycle" : "StealthChop");
  const char* fanModeNames[] = {"Auto", "Forced ON", "Forced OFF"};
  Serial.printf("Fan Mode:         %s\n", fanModeNames[FanMode]);
  Serial.printf("Fan State:        %s\n", FanOn ? "ON" : "OFF");
  float heatSinkTempC = DEVICE_DISCONNECTED_C;
  if (HeatSinkSensorPresent) {
    heatSinkTempSensor.requestTemperatures();
    heatSinkTempC = heatSinkTempSensor.getTempCByIndex(0);
    if (heatSinkTempC == DEVICE_DISCONNECTED_C) {
      Serial.println(F("Heat Sink Temp:   DISCONNECTED"));
    } else {
      Serial.printf("Heat Sink Temp:   %.1f C\n", heatSinkTempC);
    }
  }
  Serial.printf("Min Endstop:      %s\n", digitalRead(EndstopMinPin) == HIGH ? "TRIGGERED" : "ok");
  Serial.printf("Max Endstop:      %s\n", digitalRead(EndstopMaxPin) == HIGH ? "TRIGGERED" : "ok");
  // The hard limits above are the physical switches; this is the separate
  // software layer cmd6_AbsoluteMove enforces before ever issuing a move -
  // refusing any target outside [0, MaxPosition]. Only meaningful once
  // calibrated, since MaxPosition isn't trustworthy before that (same
  // "stale" reasoning as Max Range Limit above).
  if (CalibrationStatus) {
    Serial.printf("Soft Limit Guard: active (0 to %d steps)\n", MaxPosition);
  } else {
    Serial.println(F("Soft Limit Guard: inactive - not calibrated, moves refused"));
  }
  UsageStats usage = LoadUsageStats();
  // Only update the in-RAM running peak here, not EEPROM directly - an
  // active thermal ramp (e.g. a stress test) can set a new high on
  // nearly every 's' poll, and writing that straight to EEPROM each
  // time would defeat the same wear-avoidance batching every other
  // UsageStats field already gets from UpdateUsageStats(). The actual
  // EEPROM write happens there, on its existing flush schedule;
  // PendingPeakHeatSinkTempC covers the gap for display purposes in
  // the meantime.
  if (heatSinkTempC != DEVICE_DISCONNECTED_C && heatSinkTempC > PendingPeakHeatSinkTempC) {
    PendingPeakHeatSinkTempC = heatSinkTempC;
  }
  float displayPeakHeatSinkTempC = usage.peakHeatSinkTempC;
  if (PendingPeakHeatSinkTempC != DEVICE_DISCONNECTED_C && PendingPeakHeatSinkTempC > displayPeakHeatSinkTempC) {
    displayPeakHeatSinkTempC = PendingPeakHeatSinkTempC;
  }
  Serial.printf("Total Run Time:   %.1f hours\n", usage.totalEnabledSeconds / 3600.0f);
  Serial.printf("Session Run Time: %.1f hours\n", SessionEnabledMs / 3600000.0f);
  Serial.printf("Total Distance:   %.1f m\n", usage.totalDistanceMeters);
  Serial.printf("Total Min Hits:   %lu\n", (unsigned long)usage.totalMinHits);
  Serial.printf("Total Max Hits:   %lu\n", (unsigned long)usage.totalMaxHits);
  if (displayPeakHeatSinkTempC == DEVICE_DISCONNECTED_C) {
    Serial.println(F("Peak Heat Sink Temp: never recorded"));
  } else {
    Serial.printf("Peak Heat Sink Temp: %.1f C\n", displayPeakHeatSinkTempC);
  }
  Serial.println(F("---"));
  myMmuCmd.giveCmdPrompt();
}

void cmd8_Menu(void)
{
  Serial.println("");
  myMmuCmd.ShowMenu();
  myMmuCmd.giveCmdPrompt();
}

void cmd9_Speed(void)
{
  Serial.printf("\nCurrent speed is %d. Enter new max speed: \n", Speed);
  if (!WaitForCommandInput()) {
    myMmuCmd.giveCmdPrompt();
    return;
  }
  uint32_t newSpeed = Serial.parseInt();
  if(newSpeed > 0) {
    Speed = newSpeed;
    motor.setMaxSpeed(Speed);
    Serial.printf("Speed set to %d\n\n", Speed);
  }
  myMmuCmd.giveCmdPrompt();
}

void cmd10_Acceleration(void)
{
  Serial.printf("\nCurrent acceleration is %d. Enter new acceleration: \n", Acceleration);
  if (!WaitForCommandInput()) {
    myMmuCmd.giveCmdPrompt();
    return;
  }
  uint32_t newAccel = Serial.parseInt();
  if(newAccel > 0) {
    Acceleration = newAccel;
    motor.setAcceleration(Acceleration);
    Serial.printf("Acceleration set to %d\n\n", Acceleration);
  }
  myMmuCmd.giveCmdPrompt();
}

void cmd11_RunCurrent(void)
{
  Serial.printf("\nCurrent run current is %d mA. Enter new run current (1-2000 mA): \n", driver.rms_current());
  if (!WaitForCommandInput()) {
    myMmuCmd.giveCmdPrompt();
    return;
  }
  int32_t newCurrent = Serial.parseInt();
  if(newCurrent > 0 && newCurrent <= 2000) {
    RunCurrentMa = newCurrent;
    driver.rms_current(newCurrent);
    Serial.printf("Run current set to %d mA\n\n", driver.rms_current());
  } else {
    Serial.println(F("Error: run current must be between 1 and 2000 mA\n"));
  }
  myMmuCmd.giveCmdPrompt();
}

void cmd12_Microsteps(void)
{
  int32_t oldMicrosteps = driver.microsteps();
  Serial.printf("\nCurrent microsteps is %d. Enter new microsteps (0,2,4,8,16,32,64,128,256; 0 = full step): \n", oldMicrosteps);
  if (!WaitForCommandInput()) {
    myMmuCmd.giveCmdPrompt();
    return;
  }
  int32_t newMicrosteps = Serial.parseInt();
  switch(newMicrosteps) {
    case 0: case 2: case 4: case 8: case 16: case 32: case 64: case 128: case 256:
      driver.microsteps(newMicrosteps);
      Serial.printf("Microsteps set to %d\n\n", driver.microsteps());
      // MaxPosition (and everything derived from it - First-Contact,
      // cmd6_AbsoluteMove's bounds check, homing's target of 0) is a raw
      // step count at whatever microstepping was active when calibration
      // last ran. Unlike RetractDistanceMm (stored in mm, rescaled live by
      // RetractSteps()/StepsPerMm() on every call), it does NOT track a
      // microstepping change automatically - the same step count now
      // means a different physical position, silently, unless this
      // invalidates the stale calibration.
      if (driver.microsteps() != oldMicrosteps && CalibrationStatus == 1) {
        CalibrationStatus = 0;
        Serial.printf("WARNING: Microstepping changed (%d -> %d) - the calibrated range no longer matches this scale. Recalibrate ('c') before homing or moving.\n\n",
                      oldMicrosteps, driver.microsteps());
      }
      break;
    default:
      Serial.println(F("Error: microsteps must be one of 0,2,4,8,16,32,64,128,256\n"));
      break;
  }
  myMmuCmd.giveCmdPrompt();
}

void cmd13_EndstopLog(void)
{
  Serial.println(F("\n--- ENDSTOP EVENT LOG ---"));
  Serial.printf("Unexpected MIN hits: %d", UnexpectedMinHits);
  if (UnexpectedMinHits > 0) {
    Serial.printf(" (last at position %d, %dms after boot)", LastMinHitPosition, LastMinHitTime);
  }
  Serial.println();
  Serial.printf("Unexpected MAX hits: %d", UnexpectedMaxHits);
  if (UnexpectedMaxHits > 0) {
    Serial.printf(" (last at position %d, %dms after boot)", LastMaxHitPosition, LastMaxHitTime);
  }
  Serial.println();
  Serial.println(F("---"));
  myMmuCmd.giveCmdPrompt();
}

void cmd14_HoldPercent(void)
{
  Serial.printf("\nCurrent hold percent is %d%%. Enter new hold percent (0-100): \n", HoldPercent);
  if (!WaitForCommandInput()) {
    myMmuCmd.giveCmdPrompt();
    return;
  }
  bool looksLikeZero = (Serial.peek() == '0');
  int32_t newPercent = Serial.parseInt();
  if((newPercent > 0 && newPercent <= 100) || (newPercent == 0 && looksLikeZero)) {
    HoldPercent = newPercent;
    if (driver.test_connection() != 0) {
      Serial.println(F("WARNING: TMC2209 UART link is down - this setting may not have reached the driver"));
    }
    driver.hold_multiplier(HoldPercent / 100.0f);
    driver.rms_current(RunCurrentMa);  // re-apply the literal last-requested run current (not the getter's
                                        // reconstructed value - see the RunCurrentMa comment) so the new
                                        // ratio takes effect immediately, without drifting run current.
    Serial.printf("Hold percent set to %d%% (run current re-applied at %d mA)\n\n", HoldPercent, driver.rms_current());
  } else {
    Serial.println(F("Error: hold percent must be between 0 and 100\n"));
  }
  myMmuCmd.giveCmdPrompt();
}

void cmd15_DriverDiagnostics(void)
{
  Serial.println(F("\n--- DRIVER FAULT DIAGNOSTICS ---"));
  Serial.println(F("(short-to-GND/supply flags latch until disable+re-enable; see each temperature line below for its own latching behavior)"));

  if (driver.test_connection() != 0) {
    Serial.println(F("WARNING: TMC2209 UART link is down - readings below are not trustworthy"));
  }

  // Single atomic read, decoded locally, instead of 12 separate UART round-trips
  // (one per flag) that could each independently fail or be inconsistent with
  // each other if the link glitches mid-report.
  TMC2208_n::DRV_STATUS_t status;
  status.sr = driver.DRV_STATUS();

  // Live state: t120/t143/t150/t157/ot are real-time comparators - true
  // only while the die is actually at or above that threshold right now.
  if (status.ot) {
    Serial.println(F("Temperature:      SHUTDOWN (ot) - driver disabled by chip"));
  } else if (status.t157) {
    Serial.println(F("Temperature:      WARNING - currently >= 157C"));
  } else if (status.t150) {
    Serial.println(F("Temperature:      WARNING - currently >= 150C"));
  } else if (status.t143) {
    Serial.println(F("Temperature:      WARNING - currently >= 143C"));
  } else if (status.t120) {
    Serial.println(F("Temperature:      PRE-WARNING - currently >= 120C"));
  } else {
    Serial.println(F("Temperature:      OK - currently < 120C"));
  }

  // otpw, unlike the live comparators above, is latched by the driver
  // itself - it stays set once tripped even after cooling back down,
  // until the driver is disabled and re-enabled. Answers "has it been hot
  // at any point since last enable", which the live read above can't if a
  // spike already cleared before this was checked.
  Serial.printf("Overtemp latch:   %s\n",
                status.otpw ? "TRIPPED - has exceeded ~120C since last enable" : "clear");

  // Background-tracked across this whole session (since the last 'z'), not
  // just since the last enable - see HighestTempThresholdC's declaration.
  // Catches a spike during a long unattended run (e.g. the sweep test)
  // that both readings above would miss if nobody checked at the right
  // moment and the driver has since been re-enabled.
  if (HighestTempThresholdC > 0) {
    Serial.printf("Session high:     reached %dC, first seen %dms after boot\n",
                  HighestTempThresholdC, HighestTempThresholdTime);
  } else {
    Serial.println(F("Session high:     never exceeded 120C"));
  }

  Serial.printf("Short to GND:     phase A %s, phase B %s\n",
                status.s2ga ? "FAULT" : "ok", status.s2gb ? "FAULT" : "ok");
  Serial.printf("Short to supply:  phase A %s, phase B %s\n",
                status.s2vsa ? "FAULT" : "ok", status.s2vsb ? "FAULT" : "ok");
  Serial.printf("Open load:        phase A %s, phase B %s (informative only)\n",
                status.ola ? "flagged" : "ok", status.olb ? "flagged" : "ok");
  Serial.println(F("---"));
  myMmuCmd.giveCmdPrompt();
}

void cmd16_ToggleChopperMode(void)
{
  SpreadCycleEnabled = !SpreadCycleEnabled;
  driver.en_spreadCycle(SpreadCycleEnabled);
  if (driver.test_connection() != 0) {
    Serial.println(F("WARNING: TMC2209 UART link is down - this setting may not have reached the driver"));
  }
  if (SpreadCycleEnabled) {
    Serial.println(F("\nChopper mode set to SpreadCycle (louder, full torque/speed headroom)\n"));
  } else {
    Serial.println(F("\nChopper mode set to StealthChop (near-silent, reduced high-speed torque)\n"));
  }
  myMmuCmd.giveCmdPrompt();
}

void cmd17_ToggleFanMode(void)
{
  FanMode = (FanMode + 1) % 3;
  const char* modeNames[] = {"Auto (temperature-based)", "Forced ON", "Forced OFF"};
  Serial.printf("\nFan mode set to %s\n\n", modeNames[FanMode]);
  myMmuCmd.giveCmdPrompt();
}

void cmd18_SaveSettings(void)
{
  PersistedSettings s = LoadPersistedSettings();  // preserve calibrationValid/lastCalibratedMaxPosition untouched
  s.magic = PersistedSettingsMagic;
  s.version = PersistedSettingsVersion;
  s.tuningValid = true;
  s.runCurrentMa = RunCurrentMa;
  s.holdPercent = HoldPercent;
  s.speed = Speed;
  s.acceleration = Acceleration;
  s.microsteps = driver.microsteps();
  s.spreadCycleEnabled = SpreadCycleEnabled;
  s.retractDistanceMm = RetractDistanceMm;
  SavePersistedSettings(s);
  Serial.println(F("\nSettings saved (run current, hold %, speed, acceleration, microsteps, chopper mode, retract distance).\n"));
  myMmuCmd.giveCmdPrompt();
}

void cmd19_RetractDistance(void)
{
  Serial.printf("\nCurrent retract distance is %d steps (%.3f mm). Enter new retract distance (steps, must be > 0): \n",
                RetractSteps(), RetractDistanceMm);
  if (!WaitForCommandInput()) {
    myMmuCmd.giveCmdPrompt();
    return;
  }
  int32_t newSteps = Serial.parseInt();
  if (newSteps > 0) {
    RetractDistanceMm = (float)newSteps / StepsPerMm();
    Serial.printf("Retract distance set to %d steps (%.3f mm)\n\n", RetractSteps(), RetractDistanceMm);
  } else {
    Serial.println(F("Error: retract distance must be greater than 0\n"));
  }
  myMmuCmd.giveCmdPrompt();
}

void cmd20_ResetToDefaults(void)
{
  UnexpectedMinHits = 0;
  UnexpectedMaxHits = 0;
  LastMinHitPosition = 0;
  LastMaxHitPosition = 0;
  LastMinHitTime = 0;
  LastMaxHitTime = 0;
  ConsecutiveUnexpectedHits = 0;
  HighestTempThresholdC = 0;
  HighestTempThresholdTime = 0;

  // The one deliberate exception to "cmd20_ResetToDefaults never touches
  // lifetime UsageStats" (see LoadUsageStats/UpdateUsageStats) - a peak
  // temperature has a real fresh-start use case (swapping a heat sink or
  // fan) the other lifetime fields don't, so only this one field resets.
  UsageStats usage = LoadUsageStats();
  usage.peakHeatSinkTempC = DEVICE_DISCONNECTED_C;
  SaveUsageStats(usage);
  PendingPeakHeatSinkTempC = DEVICE_DISCONNECTED_C;

  RunCurrentMa = DefaultRunCurrent;
  HoldPercent = DefaultHoldPercent;
  Speed = SPEED;
  Acceleration = ACCELERATION;
  SpreadCycleEnabled = true;
  RetractDistanceMm = DefaultRetractDistanceMm;

  driver.hold_multiplier(HoldPercent / 100.0f);
  driver.rms_current(RunCurrentMa);
  driver.microsteps(DefaultMicrosteps);
  driver.en_spreadCycle(SpreadCycleEnabled);
  motor.setMaxSpeed(Speed);
  motor.setAcceleration(Acceleration);

  PersistedSettings s = LoadPersistedSettings();  // preserve calibrationValid/lastCalibratedMaxPosition untouched
  s.magic = PersistedSettingsMagic;
  s.version = PersistedSettingsVersion;
  s.tuningValid = true;
  s.runCurrentMa = RunCurrentMa;
  s.holdPercent = HoldPercent;
  s.speed = Speed;
  s.acceleration = Acceleration;
  s.microsteps = DefaultMicrosteps;
  s.spreadCycleEnabled = SpreadCycleEnabled;
  s.retractDistanceMm = RetractDistanceMm;
  SavePersistedSettings(s);

  Serial.println(F("\nReset to defaults: endstop log cleared, tuning settings (current/speed/accel/microsteps/chopper/retract distance) restored to compiled-in defaults and saved to EEPROM.\n"));
  myMmuCmd.giveCmdPrompt();
}
