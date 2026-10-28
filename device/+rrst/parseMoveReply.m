function mv = parseMoveReply(lines)
%PARSEMOVEREPLY Interpret the firmware's reply to 'a' + target.
%   mv = rrst.parseMoveReply(lines)   (lines from rrst.splitReply)
%
%   mv.ok is true only when "Move complete." is present and no line starts with
%   "Error"/"ERROR". Fields: ok, target (from "Moving to absolute position"),
%   warnings (string array of WARNING lines, kept even on success), errorText.

lines = string(lines(:));
mv = struct('ok', false, 'target', NaN, 'warnings', strings(0, 1), 'errorText', "");

mv.warnings = lines(startsWith(lines, "WARNING", 'IgnoreCase', true));
errs = lines(startsWith(lines, "ERROR", 'IgnoreCase', true));

tok = regexp(cellstr(lines), '^Moving to absolute position: (-?\d+)', 'tokens', 'once');
hit = find(~cellfun(@isempty, tok), 1);
if ~isempty(hit)
    mv.target = str2double(tok{hit}{1});
end

if ~isempty(errs)
    mv.errorText = errs(end);
elseif ~any(lines == "Move complete.")
    mv.errorText = "No 'Move complete.' line in the reply.";
else
    mv.ok = true;
end
end
