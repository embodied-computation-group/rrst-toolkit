function makePsiReference()
%MAKEPSIREFERENCE Replay the Psi reference runs through MATLAB Palamedes.
%   makePsiReference()   (needs Palamedes on the path; run on the stim laptop)
%
%   For every tests/fixtures/psi/pypalamedes__<name>.json, sets up PAL_AMPM with the
%   same grids, feeds it the recorded responses trial by trial, and writes
%   tests/fixtures/psi/palamedes_matlab__<name>.json with MATLAB's own stimulus choice
%   and posterior means (PM.threshold, PM.slope = log10 beta, PM.lapse) after every
%   trial. The Python tests (python/tests/test_psi.py) replay every file in that folder
%   and must reproduce it. If MATLAB chooses a different stimulus from pypalamedes at
%   some trial, its file still records what MATLAB did with those responses.
%   NOT YET RUN: written on a machine without Palamedes.

here = fileparts(mfilename('fullpath'));
psiDir = fullfile(here, '..', 'fixtures', 'psi');
files = dir(fullfile(psiDir, 'pypalamedes__*.json'));
if isempty(files)
    error('rrst:noReference', 'No pypalamedes__*.json files in %s.', psiDir);
end
if isempty(which('PAL_AMPM_setupPM'))
    error('rrst:noPalamedes', 'Palamedes is not on the MATLAB path.');
end

for f = files'
    ref = jsondecode(fileread(fullfile(f.folder, f.name)));
    c = ref.config;
    PM = PAL_AMPM_setupPM('priorAlphaRange', c.priorAlphaRange(:)', ...
        'priorBetaRange', c.priorBetaRange(:)', ...
        'priorGammaRange', c.priorGammaRange(:)', ...
        'priorLambdaRange', c.priorLambdaRange(:)', ...
        'numtrials', c.numTrials, ...
        'PF', @PAL_Weibull, ...
        'stimRange', c.stimRange(:)');
    n = numel(ref.response);
    x = zeros(n, 1);
    for k = 1:n
        x(k) = PM.xCurrent;
        PM = PAL_AMPM_updatePM(PM, ref.response(k));
    end

    out = struct();
    out.origin = sprintf('MATLAB %s, Palamedes at %s, tests/reference/makePsiReference.m', ...
        version, fileparts(which('PAL_AMPM_setupPM')));
    out.note = ['Responses replayed from ' f.name '. slope = PM.slope (posterior mean of log10 beta).'];
    out.observer = ref.observer;
    out.pf = 'weibull';
    out.config = c;
    out.x = x;
    out.response = ref.response(:);
    out.threshold = PM.threshold(:);
    out.slope = PM.slope(:);
    out.lapse = PM.lapse(:);
    out.stop = logical(PM.stop);

    name = strrep(f.name, 'pypalamedes__', 'palamedes_matlab__');
    fid = fopen(fullfile(psiDir, name), 'w', 'n', 'UTF-8');
    fprintf(fid, '%s', jsonencode(out, 'PrettyPrint', true));
    fclose(fid);
    firstDiff = find(abs(x - ref.x(:)) > 1e-9, 1);
    if isempty(firstDiff)
        fprintf('%s: same %d stimuli as pypalamedes; final threshold %.4f (pypalamedes %.4f)\n', ...
            name, n, out.threshold(end), ref.threshold(end));
    else
        fprintf('%s: FIRST DIFFERENT STIMULUS at trial %d (MATLAB %g, pypalamedes %g)\n', ...
            name, firstDiff, x(firstDiff), ref.x(firstDiff));
    end
end
end
