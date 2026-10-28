function checkSessionIsNew(folder, stem)
%CHECKSESSIONISNEW Error if this session of this participant was already completed.
%   checkSessionIsNew(folder, stem)    stem from sessionFileStem, e.g. 'RRST_0001_s2'
%   Only a completed file (no Aborted_ / Error_ prefix) blocks: an aborted or failed
%   session can be run again, and its files are kept.
if ~isempty(dir(fullfile(folder, [stem, '_*.mat'])))
    error('rrst:dataExists', ['%s was already completed (a file %s_*.mat is in %s). ' ...
        'Check the subject ID and session number.'], stem, stem, folder);
end
end
