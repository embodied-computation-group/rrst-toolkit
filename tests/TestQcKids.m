classdef TestQcKids < matlab.unittest.TestCase
    % qcKids on a saved session that never reached the main trials (the first child,
    % 2026-10-30, stopped in the practice): a clear error, no figure, instead of a
    % crash on an empty phase list.

    methods (TestClassSetup)
        function addKidsPath(tc)
            root = fileparts(fileparts(mfilename('fullpath')));
            p = [fullfile(root, 'task', 'RRST_kids', {'', 'config', 'code'}), ...
                {fullfile(root, 'task', 'RRST_2-0', 'code')}];
            addpath(p{:});
            tc.addTeardown(@() rmpath(p{:}));
        end
    end

    methods (Test)
        function noMainTrialsIsAClearError(tc)
            f = tc.saveSession([]);                         % trials = [] (aborted in the tutorial)
            tc.verifyError(@() qcKids(f), 'rrst:qcNoMainTrials');
            tc.verifyFalse(isfile(strrep(f, '.mat', '_qc.png')), 'no figure for an empty run');
        end

        function practiceOnlyIsAClearError(tc)
            tr = repmat(struct('phase', "practice", 'level', 90, 'isCatch', false, ...
                'response', 0, 'rt', 1, 'answer', "no"), 0, 1);   % empty struct array
            f = tc.saveSession(tr);
            tc.verifyError(@() qcKids(f), 'rrst:qcNoMainTrials');
        end
    end

    methods
        function f = saveSession(tc, trials)
            cfg = kidsConfig(); %#ok<NASGU>
            result = struct('outcome', "aborted", 'trials', trials, 'practice', [], ...
                'flags', [], 'kp', struct('PM', [])); %#ok<NASGU>
            d = tempname; mkdir(d);
            tc.addTeardown(@() rmdir(d, 's'));
            f = fullfile(d, 'Aborted_RRSTkids_9002_test.mat');
            save(f, 'cfg', 'result');
        end
    end
end
