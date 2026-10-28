function endSession(vars, scr, keys, Results, stair, status)
%endSession(vars, scr, keys, Results, stair, status)
%
% Save the session and close the screen. RRST 2.0 version of helpers/experimentEnd.m:
% status is "complete", "aborted" or "error"; the caller rethrows errors itself
% (experimentEnd rethrew psychlasterror, which could be a stale error).
% Files: <DataFileName>.mat (stair, Results, vars incl. vars.device and vars.cfg,
% scr, keys) and <DataFileName>.csv (one row per trial, trialTable.m); aborted and error runs get an
% Aborted_ / Error_ prefix.

switch status
    case "complete"
        message = vars.InstructionEnd;
        prefix = '';
    case "aborted"
        message = 'Experiment was aborted!';
        prefix = 'Aborted_';
    otherwise
        message = '';
        prefix = 'Error_';
end

if isfield(scr, 'win') && ~isempty(message)
    try
        Screen('FillRect', scr.win, scr.BackgroundGray, scr.winRect);
        DrawFormattedText(scr.win, message, 'center', 'center', scr.TextColour);
        Screen('Flip', scr.win);
        WaitSecs(2);
    catch
        % window already gone; saving matters more
    end
end

vars.DataFileName = [prefix, vars.DataFileName];
matName = fullfile(vars.OutputFolder, [vars.DataFileName, '.mat']);
save(matName, 'stair', 'Results', 'vars', 'scr', 'keys');
fprintf('Run %s. Results saved as %s\n', status, matName);
try
    % per-trial columns only; the rest is in the .mat (struct2csv failed silently)
    writetable(trialTable(Results), fullfile(vars.OutputFolder, [vars.DataFileName, '.csv']));
catch csvErr
    warning('rrst:csvNotWritten', 'CSV not written (%s). The .mat file is complete.', csvErr.message);
end

% Masking noise is closed by stopMaskingNoise. Without noise the audio driver was
% never loaded, and any PsychPortAudio call errors.
if vars.playNoiseSound
    try
        PsychPortAudio('Close');
    catch
    end
end
sca;
ShowCursor;
fclose('all');
Priority(0);
end
