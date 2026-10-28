function rec = loadDeviceRecord(deviceId, devicesDir)
%LOADDEVICERECORD Read the bench-measured record for one device.
%   rec = rrst.loadDeviceRecord("2E4441D76D5F2996", devicesDir)
%
%   Records live in devices/<deviceId>.json. A device without a record has no
%   measured anchors, so this is an error (rrst:noDeviceRecord), never a default.

deviceId = string(deviceId);
f = fullfile(devicesDir, deviceId + ".json");
if ~isfile(f)
    error('rrst:noDeviceRecord', ...
        ['No record for device %s (looked for %s). Measure its anchors at the bench ' ...
         '(bench/anchorSession.m) and save them in devices/ before running the task.'], ...
        deviceId, f);
end
rec = jsondecode(fileread(f));
rec.deviceId = string(rec.deviceId);
need = ["maxPositionAtMeasurement" "zeroOffset" "fullOffset"];
if ~isfield(rec, 'anchors') || ~all(isfield(rec.anchors, need))
    error('rrst:noDeviceRecord', 'Record %s has no complete anchors (%s).', f, strjoin(need, ', '));
end
end
