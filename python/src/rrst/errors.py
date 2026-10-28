"""Errors raised by the RRST layer. Each carries the identifier the MATLAB layer uses
(e.g. "rrst:moveFailed"), so logs from both implementations read the same."""


class RrstError(Exception):
    identifier = "rrst:error"


def _error(name, identifier, doc):
    return type(name, (RrstError,), {"identifier": identifier, "__doc__": doc})


NotCalibrated = _error("NotCalibrated", "rrst:notCalibrated", "Move requested before a successful calibration.")
OutOfRange = _error("OutOfRange", "rrst:outOfRange", "Target or obstruction value outside its valid range.")
CalibrationFailed = _error("CalibrationFailed", "rrst:calibrationFailed", "'c' reply did not confirm both endstops.")
EnableFailed = _error("EnableFailed", "rrst:enableFailed", "'e' reply did not confirm.")
MoveFailed = _error("MoveFailed", "rrst:moveFailed", "Firmware refused or aborted the move.")
DeviceFault = _error("DeviceFault", "rrst:deviceFault", "An unsolicited ERROR arrived before a command.")
Timeout = _error("Timeout", "rrst:timeout", "No complete reply within the timeout.")
BadStatus = _error("BadStatus", "rrst:badStatus", "Reply has no status block.")
BadMap = _error("BadMap", "rrst:badMap", "Invalid level-to-step map.")
BadAnchors = _error("BadAnchors", "rrst:badAnchors", "Invalid anchor offsets.")
LevelOutOfRange = _error("LevelOutOfRange", "rrst:levelOutOfRange", "Configured levels outside the device's scale.")
CalibrationMismatch = _error("CalibrationMismatch", "rrst:calibrationMismatch", "MaxPosition far from the device record.")
WrongDevice = _error("WrongDevice", "rrst:wrongDevice", "The record belongs to another device.")
NoDeviceRecord = _error("NoDeviceRecord", "rrst:noDeviceRecord", "No complete bench record for this device.")
NoPort = _error("NoPort", "rrst:noPort", "The requested serial port is not available.")
AmbiguousPort = _error("AmbiguousPort", "rrst:ambiguousPort", "Several ports are available; name one.")
BadNoise = _error("BadNoise", "rrst:badNoise", "Unknown masking-noise colour.")
BadConfig = _error("BadConfig", "rrst:badConfig", "The task configuration cannot run as intended.")
BadSetting = _error("BadSetting", "rrst:badSetting", "apply_motion given an invalid speed, acceleration or mode.")
SettingFailed = _error("SettingFailed", "rrst:settingFailed", "Firmware did not confirm a setting, or 's' disagrees.")
BadGrid = _error("BadGrid", "rrst:badGrid", "A Psi grid the psychometric function cannot evaluate.")
