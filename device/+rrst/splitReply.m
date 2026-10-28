function [lines, complete] = splitReply(text)
%SPLITREPLY Split raw firmware output into lines and detect the command prompt.
%   [lines, complete] = rrst.splitReply(text)
%
%   The firmware ends every command reply with giveCmdPrompt(), i.e. CRLF and then
%   "Valve>" with no line terminator. complete is true when the text ends with that
%   prompt. lines is a column string array with carriage returns, blank lines and
%   the prompt removed.

PROMPT = "Valve>";

text = string(text);
if strlength(text) == 0
    lines = strings(0, 1);
    complete = false;
    return
end

trimmed = strip(text, 'right');
complete = endsWith(trimmed, PROMPT);
if complete
    trimmed = extractBefore(trimmed, strlength(trimmed) - strlength(PROMPT) + 1);
end

lines = split(erase(trimmed, sprintf('\r')), newline);
lines = strip(lines, 'right');
lines = lines(strlength(lines) > 0);
lines = lines(:);
end
