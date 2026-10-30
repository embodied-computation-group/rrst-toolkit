classdef TestKidsPrompt < matlab.unittest.TestCase
    % RRST-Kids experimenter prompts (kidsPrompt): the one line the experimenter reads
    % at each moment of the session, on screen (bottom left) and on the console.
    % Pure: no screen. After the first real run (2026-10-30) the experimenter did not
    % know they were in practice, nor when Space was needed.

    properties (Constant)
        MaxLen = 90
        MaxLenCounts = 116       % the main trial line with its counts (2026-10-30)
    end

    methods (TestClassSetup)
        function addKidsPath(tc)
            root = fileparts(fileparts(mfilename('fullpath')));
            p = fullfile(root, 'task', 'RRST_kids', {'config', 'code'});
            tc.applyFixture(matlab.unittest.fixtures.PathFixture(p));
        end
    end

    methods (Static)
        function c = cases()
            % {moment, info} for every moment, including the largest numbers a
            % session can reach (so the length check covers them).
            c = {
                "calibrating", struct()
                "story",       struct('beat', 1, 'nBeats', 3)
                "story",       struct('beat', 3, 'nBeats', 3)
                "freeplay",    struct()
                "demo",        struct('demo', "pinch")
                "demo",        struct('demo', "sleep")
                "bridge",      struct()
                "mainStart",   struct()
                "move",        struct()
                "ready",       struct('phase', "practice", 'k', 3, 'n', 6)
                "ready",       struct('phase', "practice", 'k', 12, 'n', 12)
                "ready",       struct('phase', "main", 'n', 5, 'level', 65)
                "ready",       struct('phase', "main", 'n', 120, 'level', 85)
                "ready",       struct('phase', "free", 'k', 1, 'n', 2)
                "slurps",      struct('phase', "practice", 'k', 3, 'n', 6, 'slurps', 3)
                "slurps",      struct('phase', "main", 'n', 120, 'slurps', 3, 'level', 85)
                "slurps",      struct('phase', "demo", 'demo', "pinch", 'slurps', 3)
                "slurps",      struct('phase', "free", 'k', 2, 'n', 2, 'slurps', 3)
                "question",    struct()
                "reveal",      struct('phase', "practice")
                "reveal",      struct('phase', "demo")
                "reveal",      struct('phase', "main")
                "feedback",    struct('phase', "practice", 'correct', true)
                "feedback",    struct('phase', "practice", 'correct', false)
                "feedback",    struct('phase', "main", 'correct', false)
                "reward",      struct()
                "cup",         struct()
                "rest",        struct('restS', 30)
                "rest",        struct('restS', 45)
                "pause",       struct()
                "thanks",      struct()
                "done",        struct()
                };
        end
    end

    methods (Test)
        function everyMomentIsAShortNonEmptyLine(tc)
            c = tc.cases();
            for k = 1:size(c, 1)
                line = kidsPrompt(c{k, 1}, c{k, 2});
                name = sprintf('%s (case %d)', c{k, 1}, k);
                tc.verifyClass(line, 'char', name);
                tc.verifyNotEmpty(strtrim(line), name);
                tc.verifyLessThan(numel(line), tc.MaxLen, name);
                tc.verifyEmpty(strfind(line, '\n'), [name ': one line']);
                tc.verifyFalse(any(line == newline), [name ': one line']);
            end
        end

        function everyMomentIsCovered(tc)
            % kidsPrompt() lists its moments; each one is in the cases above.
            names = kidsPrompt();
            tc.verifyClass(names, 'string');
            c = tc.cases();
            tc.verifyEqual(sort(unique([c{:, 1}])), sort(names));
        end

        function wordingOfTheKeyMoments(tc)
            tc.verifyEqual(kidsPrompt("story", struct('beat', 1, 'nBeats', 3)), ...
                'Story 1 of 3. Tell it, then Space.');
            tc.verifyEqual(kidsPrompt("freeplay", struct()), ...
                'Free slurps: let them breathe. Space when done.');
            tc.verifyEqual(kidsPrompt("demo", struct('demo', "pinch")), ...
                'Demo: the mouse is pinching. Let them slurp and feel it. Space starts.');
            tc.verifyEqual(kidsPrompt("question", struct()), ...
                'Click the card the child chose (Left/Right arrow). x = bad breath.');
            tc.verifyEqual(kidsPrompt("reveal", struct('phase', "practice")), ...
                'Practice: this is the truth.');
            tc.verifyEqual(kidsPrompt("reward", struct()), ...
                'Star: one per answer, right or wrong.');
            tc.verifyEqual(kidsPrompt("rest", struct('restS', 30)), 'Rest 30 s. Then Space.');
            tc.verifyEqual(kidsPrompt("cup", struct()), 'Sticker time! Space.');
            tc.verifyEqual(kidsPrompt("done", struct()), 'All done. Esc or wait.');
        end

        function practiceLineCarriesTheNumbers(tc)
            tc.verifyEqual(kidsPrompt("ready", struct('phase', "practice", 'k', 3, 'n', 6)), ...
                'PRACTICE 3 of 6. Space starts the slurps. The truth is shown after the answer.');
            line = kidsPrompt("ready", struct('phase', "practice", 'k', 5, 'n', 8));
            tc.verifyTrue(startsWith(line, 'PRACTICE 5 of 8.'), line);
            line = kidsPrompt("slurps", struct('phase', "practice", 'k', 4, 'n', 6, 'slurps', 3));
            tc.verifyTrue(contains(line, 'PRACTICE 4 of 6'), line);
        end

        function mainLineNeverMentionsTheLevel(tc)
            tc.verifyEqual(kidsPrompt("ready", struct('phase', "main", 'n', 5, 'level', 65)), ...
                'Trial 5. Space starts the slurps. No feedback; one star per answer.');
            for level = [0 35 65 85]
                for m = ["ready" "slurps"]
                    line = kidsPrompt(m, struct('phase', "main", 'n', 7, 'level', level, 'slurps', 3));
                    tc.verifyFalse(contains(lower(line), 'level'), line);
                    tc.verifyFalse(contains(line, '%'), line);
                    if level > 0
                        tc.verifyFalse(contains(line, sprintf('%g', level)), line);
                    end
                    tc.verifyFalse(contains(lower(line), 'catch'), line);
                end
            end
        end

        function feedbackLineSaysRightOrNot(tc)
            % The cards feedback (2026-10-30): the child sees the gold card; the
            % experimenter's line says whether the answer was right.
            tc.verifyEqual(kidsPrompt("feedback", struct('phase', "practice", 'correct', true)), ...
                'Practice: right. The gold card shows the truth.');
            tc.verifyEqual(kidsPrompt("feedback", struct('phase', "practice", 'correct', false)), ...
                'Practice: not right. The gold card shows the truth.');
            tc.verifyEqual(kidsPrompt("feedback", struct('phase', "main", 'correct', true)), ...
                'Feedback: right. The gold card shows the truth.');
            tc.verifyError(@() kidsPrompt("feedback", struct('phase', "practice")), 'rrst:badPrompt');
        end

        function mainLineCountsTheTrials(tc)
            % Second real run (2026-10-30): "trial 21" and a third break although 20
            % trials were planned; 20 Psi + 8 catch = up to 28 and the early stop
            % needs 20 Psi trials, but the experimenter could not see that.
            info = struct('phase', "main", 'n', 21, 'nMax', 28, 'psiDone', 15, 'psiN', 20, ...
                'catchDone', 6, 'catchN', 8, 'feedback', false);
            tc.verifyEqual(kidsPrompt("ready", info), ['Trial 21 of up to 28 (Psi 15/20, catch 6/8). ' ...
                'Space starts the slurps. No feedback; one star per answer.']);
            info.feedback = true;
            tc.verifyEqual(kidsPrompt("ready", info), ['Trial 21 of up to 28 (Psi 15/20, catch 6/8). ' ...
                'Space starts the slurps. Feedback on; one star per answer.']);
            % the counts are of trials done: the line does not depend on this trial
            for level = [0 35 85]
                info.level = level; info.isCatch = level == 0;
                line = kidsPrompt("ready", info);
                tc.verifyFalse(contains(lower(line), 'level'), line);
                tc.verifyFalse(contains(line, '%'), line);
                tc.verifyEqual(line, kidsPrompt("ready", rmfield(info, {'level', 'isCatch'})));
            end
            % the largest numbers a session can reach still fit on the line
            big = struct('phase', "main", 'n', 120, 'nMax', 140, 'psiDone', 100, 'psiN', 100, ...
                'catchDone', 40, 'catchN', 40, 'feedback', true);
            tc.verifyLessThan(numel(kidsPrompt("ready", big)), tc.MaxLenCounts);
        end

        function mainStartSaysWhetherThereIsFeedback(tc)
            tc.verifyEqual(kidsPrompt("mainStart", struct()), ...
                'Practice passed. Main trials: no feedback, one star per answer. Space.');
            tc.verifyEqual(kidsPrompt("mainStart", struct('feedback', true)), ...
                'Practice passed. Main trials: feedback on, one star per answer. Space.');
        end

        function consoleShowsThePlanTheEstimateAndWhyItStopped(tc)
            cfg = kidsConfig();
            cfg.child.numPsiTrials = 20; cfg.child.numCatchTrials = 8;
            cfg.child.stopSE = 8; cfg.child.stopMinTrials = 20;
            kp = fakeKp(15, 6, 72.34, 7.12, 28);
            tc.verifyEqual(kidsRunReport(kp, cfg, "plan"), ['Main trials: up to 28 (20 Psi + 8 catch). ' ...
                'Early stop: SE < 8 after 20 Psi trials.']);
            tc.verifyEqual(kidsRunReport(kp, cfg, "progress"), ['Threshold 72.3 %, SE 7.1. ' ...
                'Early stop: SE < 8 after 20 Psi trials; now SE 7.1 after 15 (5 more Psi trials needed).']);
            kp = fakeKp(20, 7, 86.9, 7.1, 28);
            tc.verifyEqual(kidsRunReport(kp, cfg, "progress"), ['Threshold 86.9 %, SE 7.1. ' ...
                'Early stop: SE < 8 after 20 Psi trials; now SE 7.1 after 20: stops now.']);
            kp = fakeKp(21, 7, 60, 9.26, 28);
            tc.verifyEqual(kidsRunReport(kp, cfg, "progress"), ['Threshold 60.0 %, SE 9.3. ' ...
                'Early stop: SE < 8 after 20 Psi trials; now SE 9.3 after 21: goes on (0 trials left).']);
            kp = fakeKp(20, 7, 86.9, 7.1, 28);
            tc.verifyEqual(kidsRunReport(kp, cfg, "end", "precise"), ['Stopped early: SE 7.1 < 8 after ' ...
                '20 Psi trials (27 of up to 28 trials run). Threshold 86.9 %.']);
            kp = fakeKp(20, 8, 70, 9, 28);
            tc.verifyEqual(kidsRunReport(kp, cfg, "end", "complete"), ['Stopped: all 28 planned trials ' ...
                'run (20 Psi, 8 catch); SE 9.0 (the early stop needs SE < 8 after 20 Psi trials). Threshold 70.0 %.']);
            tc.verifyEqual(kidsRunReport(kp, cfg, "end", "repeats"), ['Stopped: more than 10 repeated ' ...
                'trials (no answer, bad breath or pause). Threshold 70.0 %, SE 9.0.']);
            kp = fakeKp(0, 0, NaN, NaN, 28);
            tc.verifyTrue(startsWith(kidsRunReport(kp, cfg, "progress"), 'No estimate yet.'));
            tc.verifyError(@() kidsRunReport(kp, cfg, "end", "bored"), 'rrst:badPrompt');
            tc.verifyError(@() kidsRunReport(kp, cfg, "summary"), 'rrst:badPrompt');
        end

        function unknownMomentIsAnError(tc)
            tc.verifyError(@() kidsPrompt("dance", struct()), 'rrst:badPrompt');
            tc.verifyError(@() kidsPrompt("ready", struct('phase', "warmup")), 'rrst:badPrompt');
        end
    end
end

function kp = fakeKp(nPsi, nCatch, threshold, se, nSchedule)
% A kidsProcedure state after nPsi Psi and nCatch catch trials were answered, with
% the posterior's threshold and SE (no Palamedes; NaN: no estimate yet).
kp.schedule = false(1, nSchedule);
kp.schedule(1 + 2 * (1:nCatch)) = true;
kp.k = nPsi + nCatch + 1;
kp.nPsiDone = nPsi;
kp.nRepeats = 0;
isCatch = num2cell([true(1, nCatch), false(1, nPsi)]);
kp.history = struct('level', 50, 'response', 1, 'isCatch', isCatch);
if isnan(threshold)
    kp.PM = struct('threshold', [], 'seThreshold', []);
else
    kp.PM = struct('threshold', [80 threshold], 'seThreshold', [12 se]);
end
end
