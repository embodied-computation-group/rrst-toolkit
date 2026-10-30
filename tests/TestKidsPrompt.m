classdef TestKidsPrompt < matlab.unittest.TestCase
    % RRST-Kids experimenter prompts (kidsPrompt): the one line the experimenter reads
    % at each moment of the session, on screen (bottom left) and on the console.
    % Pure: no screen. After the first real run (2026-10-30) the experimenter did not
    % know they were in practice, nor when Space was needed.

    properties (Constant)
        MaxLen = 90
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

        function unknownMomentIsAnError(tc)
            tc.verifyError(@() kidsPrompt("dance", struct()), 'rrst:badPrompt');
            tc.verifyError(@() kidsPrompt("ready", struct('phase', "warmup")), 'rrst:badPrompt');
        end
    end
end
