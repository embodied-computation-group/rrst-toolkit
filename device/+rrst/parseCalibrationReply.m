function cal = parseCalibrationReply(lines)
%PARSECALIBRATIONREPLY Interpret the firmware's reply to 'c'.
%   cal = rrst.parseCalibrationReply(lines)   (lines from rrst.splitReply)
%
%   cal.ok is true only when the max endstop and first-contact lines are present
%   and no line starts with "ERROR". Fields: ok, maxPosition, firstContact,
%   retractMm, previousSaved (NaN when none), errorText ("" when ok).

lines = string(lines(:));
cal = struct('ok', false, 'maxPosition', NaN, 'firstContact', NaN, ...
    'retractMm', NaN, 'previousSaved', NaN, 'errorText', "");

errs = lines(startsWith(lines, "ERROR", 'IgnoreCase', true));

tok = regexp(cellstr(lines), '^Max Endstop found\. Max Position: (-?\d+)', 'tokens', 'once');
hit = find(~cellfun(@isempty, tok), 1);
if ~isempty(hit)
    cal.maxPosition = str2double(tok{hit}{1});
    prev = regexp(lines(hit), 'previous saved: (-?\d+)', 'tokens', 'once');
    if ~isempty(prev)
        cal.previousSaved = str2double(prev{1});
    end
end

tok = regexp(cellstr(lines), '^First-contact position \(retract ([\d.]+) mm\): (-?\d+)', 'tokens', 'once');
hit = find(~cellfun(@isempty, tok), 1);
if ~isempty(hit)
    cal.retractMm = str2double(tok{hit}{1});
    cal.firstContact = str2double(tok{hit}{2});
end

if ~isempty(errs)
    cal.errorText = errs(1);
elseif isnan(cal.maxPosition) || isnan(cal.firstContact)
    cal.errorText = "No 'Max Endstop found' / 'First-contact position' line in the reply.";
else
    cal.ok = true;
end

if ~cal.ok
    cal.maxPosition = NaN;
    cal.firstContact = NaN;
end
end
