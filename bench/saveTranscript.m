function saveTranscript(root, dev, label, deviceId)
%SAVETRANSCRIPT Write a Device transcript to bench/captures/<label>__device_<id>__<time>.txt.
outDir = fullfile(root, 'bench', 'captures');
if ~exist(outDir, 'dir'), mkdir(outDir); end
fname = fullfile(outDir, sprintf('%s__device_%s__%s.txt', label, deviceId, datestr(now, 'yyyy-mm-dd_HHMMSS')));
% read(...,'char') yields one char per byte, so ISO-8859-1 writes the device's bytes back unchanged.
fid = fopen(fname, 'w', 'n', 'ISO-8859-1');
for k = 1:numel(dev.Transcript)
    tr = dev.Transcript(k);
    fprintf(fid, '===== %.3f s  %s\n', tr.t, tr.direction);
    fwrite(fid, char(tr.text));
    fprintf(fid, '\n');
end
fclose(fid);
fprintf('Transcript saved to %s\n', fname);
end
