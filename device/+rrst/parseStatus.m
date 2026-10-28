function st = parseStatus(lines)
%PARSESTATUS Interpret the firmware's 's' status block.
%   st = rrst.parseStatus(lines)   (lines from rrst.splitReply)
%
%   Returns typed fields for the values the task relies on, plus st.fields, a struct
%   of every "Key: value" line as raw strings, for logging. maxPosition and
%   firstContact are NaN unless the device reports itself calibrated: an
%   uncalibrated device still prints a stale MaxPosition, which must not be used.

lines = string(lines(:));
if ~any(lines == "--- SYSTEM STATUS ---")
    error('rrst:badStatus', 'Reply does not contain a "--- SYSTEM STATUS ---" block.');
end

raw = struct();
for k = 1:numel(lines)
    parts = regexp(lines(k), '^([^:]+):\s*(.*)$', 'tokens', 'once');
    if isempty(parts)
        continue
    end
    raw.(matlab.lang.makeValidName(strtrim(parts{1}))) = string(strtrim(parts{2}));
end

st = struct();
st.fields = raw;
st.softwareVersion = getText(raw, 'SoftwareVersion');
st.gitCommit = getText(raw, 'GitCommit');      % "" before Precise-Piston; "-dirty"/"unknown" possible
st.deviceId = getText(raw, 'DeviceID');
st.stepperEnabled = getText(raw, 'StepperEnabled') == "YES";
st.calibrated = getText(raw, 'Calibrated') == "YES";
st.currentPosition = leadingNumber(getText(raw, 'CurrentPosition'));
st.maxPosition = NaN;
st.firstContact = NaN;
if st.calibrated
    st.maxPosition = leadingNumber(getText(raw, 'MaxRangeLimit'));
    st.firstContact = leadingNumber(getText(raw, 'First_Contact'));
end
retract = regexp(getText(raw, 'RetractDistance'), '^(\d+) steps \(([\d.]+) mm\)', 'tokens', 'once');
if isempty(retract)
    st.retractSteps = NaN;
    st.retractMm = NaN;
else
    st.retractSteps = str2double(retract{1});
    st.retractMm = str2double(retract{2});
end
st.speed = leadingNumber(getText(raw, 'CurrentSpeed'));
st.acceleration = leadingNumber(getText(raw, 'Acceleration'));
st.runCurrent = leadingNumber(getText(raw, 'RunCurrent'));
st.holdPercent = leadingNumber(getText(raw, 'HoldCurrent'));
st.microsteps = leadingNumber(getText(raw, 'Microsteps'));
st.chopperMode = getText(raw, 'ChopperMode');
end

function s = getText(raw, name)
if isfield(raw, name)
    s = raw.(name);
else
    s = "";
end
end

function x = leadingNumber(s)
tok = regexp(s, '^(-?\d+(\.\d+)?)', 'tokens', 'once');
if isempty(tok)
    x = NaN;
else
    x = str2double(tok{1});
end
end
