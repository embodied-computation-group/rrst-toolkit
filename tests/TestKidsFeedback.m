classdef TestKidsFeedback < matlab.unittest.TestCase
    % RRST-Kids child-facing feedback after an answer (practice, and main trials when
    % cfg.feedback.main): the two answer cards as on the question screen, the correct
    % card in a thick gold frame with a star badge, the chosen card keeping its white
    % frame; right: a gold tick on it and the star sound; wrong: the chosen card fades,
    % the mouse on the correct card squeezes twice or a Z floats up, the soft
    % "tryagain" sound, never a sad face. Second real run (2026-10-30): "the feedback
    % in the training is super weird and only in the text given to the experimenter".
    % The sequence (kidsFeedbackBeat) and the geometry (kidsFeedbackLayout) are pure;
    % the drawing (kidsQuestion's feedback state) runs against the Psychtoolbox
    % stand-ins and, where Psychtoolbox can open a small window, is rendered.

    properties (Constant)
        Windows = {[0 0 1600 900], [0 0 2560 1440], [0 0 2560 1440] / 3, ...
            [0 0 1024 768], [0 0 900 1000]}
        Answers = ["no" "yes"]
        P = 0:0.05:1
    end

    methods (TestClassSetup)
        function addKidsPath(tc)
            root = fileparts(fileparts(mfilename('fullpath')));
            p = fullfile(root, 'task', 'RRST_kids', {'config', 'code'});
            tc.applyFixture(matlab.unittest.fixtures.PathFixture(p));
        end
    end

    methods (Test)
        % --- configuration --------------------------------------------------------
        function defaults(tc)
            cfg = kidsConfig();
            tc.verifyTrue(cfg.feedback.practice);
            tc.verifyFalse(cfg.feedback.main);
            tc.verifyEqual(cfg.feedback.style, "cards");
            tc.verifyEqual(cfg.timing.feedback, 2.5);
            validateKidsConfig(cfg);
            cfg.feedback.style = "reveal";              % the old reveal stays available
            validateKidsConfig(cfg);
            cfg.feedback.main = true;
            validateKidsConfig(cfg);
        end

        function badFeedbackSettingsAreRejected(tc)
            bad = {@(c) setfield(c, 'feedback', rmfield(c.feedback, 'style')), ...
                @(c) setfield(c, 'feedback', setfield(c.feedback, 'style', "stars")), ...
                @(c) setfield(c, 'feedback', setfield(c.feedback, 'practice', 1)), ...
                @(c) setfield(c, 'feedback', setfield(c.feedback, 'main', "no")), ...
                @(c) setfield(c, 'timing', setfield(c.timing, 'feedback', 0)), ...
                @(c) setfield(c, 'timing', rmfield(c.timing, 'feedback')), ...
                @(c) rmfield(c, 'feedback')}; %#ok<SFLD>
            for k = 1:numel(bad)
                cfg = bad{k}(kidsConfig());
                tc.verifyError(@() validateKidsConfig(cfg), 'rrst:badConfig', sprintf('case %d', k));
            end
        end

        % --- sequence (pure) ---------------------------------------------------------
        function soundSaysRightOrTryAgain(tc)
            % right: the star; wrong: the soft "tryagain" (never sad); played once, at
            % the start; the length is cfg.timing.feedback.
            cfg = kidsConfig();
            for a = tc.Answers
                for truth = tc.Answers
                    fb = kidsFeedbackBeat(a, truth, 0, cfg.timing);
                    name = sprintf('answer %s, truth %s', a, truth);
                    tc.verifyEqual(fb.correct, a == truth, name);
                    if a == truth
                        tc.verifyEqual(fb.cue, "star", name);
                    else
                        tc.verifyEqual(fb.cue, "tryagain", name);
                    end
                    tc.verifyTrue(ismember(fb.cue, kidsSound.cueNames));
                    tc.verifyEqual(fb.dur, 2.5, name);
                    tc.verifyEqual(fb.answer, a); tc.verifyEqual(fb.truth, truth);
                    for p = tc.P(2:end)
                        tc.verifyEqual(kidsFeedbackBeat(a, truth, p, cfg.timing).cue, fb.cue, 'the same cue name all along');
                    end
                end
            end
        end

        function rightShowsATickWrongFadesTheChosenCard(tc)
            for a = tc.Answers
                for truth = tc.Answers
                    f = arrayfun(@(p) kidsFeedbackBeat(a, truth, p), tc.P);
                    if a == truth
                        tc.verifyTrue(all([f.tick] > 0 | tc.P == 0), 'a tick when right');
                        tc.verifyEqual([f.fade], zeros(size(tc.P)), 'nothing fades when right');
                        tc.verifyEqual(f(end).tick, 1);
                    else
                        tc.verifyEqual([f.tick], zeros(size(tc.P)), 'no tick when wrong');
                        tc.verifyTrue(all(diff([f.fade]) >= 0), 'the chosen card fades in');
                        tc.verifyGreaterThan(f(end).fade, 0.3);
                        tc.verifyLessThan(f(end).fade, 0.8, 'faded, still visible');
                    end
                end
            end
        end

        function theMouseOnTheCorrectCardShowsTheTruth(tc)
            % pinching (truth yes): squeezes twice; asleep (truth no): a Z floats up
            p = 0:0.01:1;
            for a = tc.Answers
                f = arrayfun(@(q) kidsFeedbackBeat(a, "yes", q), p);
                sq = [f.squeeze];
                tc.verifyEqual(nnz(diff(sign(diff(sq))) < 0), 2, 'two squeezes');
                tc.verifyGreaterThan(max(sq), 0.9); tc.verifyEqual(sq(1), 0, 'AbsTol', 1e-12);
                tc.verifyEqual(sq(end), 0, 'AbsTol', 1e-9, 'ends at rest');
                tc.verifyTrue(all(isnan([f.zRise])));
                f = arrayfun(@(q) kidsFeedbackBeat(a, "no", q), p);
                z = [f.zRise];
                tc.verifyTrue(all(diff(z) > 0), 'the Z floats up');
                tc.verifyEqual(z([1 end]), [0 1], 'AbsTol', 1e-12);
                tc.verifyEqual([f.squeeze], zeros(size(p)));
            end
        end

        function feedbackNamesAreChecked(tc)
            tc.verifyError(@() kidsFeedbackBeat("maybe", "yes", 0), 'rrst:badFeedback');
            tc.verifyError(@() kidsFeedbackBeat("yes", "none", 0), 'rrst:badFeedback');
            tc.verifyError(@() kidsFeedbackBeat("yes", "no", 1.5), 'rrst:badFeedback');
        end

        % --- geometry (pure) ---------------------------------------------------------
        function badgeAndGoldFrameAreOnTheCorrectCard(tc)
            for k = 1:numel(tc.Windows)
                r = tc.Windows{k};
                q = kidsQuestionLayout(r);
                for a = tc.Answers
                    for truth = tc.Answers
                        g = kidsFeedbackLayout(r, kidsFeedbackBeat(a, truth, 0.5));
                        name = sprintf('window %d, answer %s, truth %s', k, a, truth);
                        card = g.card.(truth);
                        b = g.badge;                                  % [x y r]
                        tc.verifyTrue(inside([b(1) - b(3), b(2) - b(3), b(1) + b(3), b(2) + b(3)], card), ...
                            [name ': the star badge in the correct card']);
                        tc.verifyGreaterThan(b(1), mean(card([1 3])), [name ': top right corner']);
                        tc.verifyLessThan(b(2), mean(card([2 4])), [name ': top right corner']);
                        tc.verifyTrue(inside(g.frame.(truth), g.gold), [name ': gold round the correct card']);
                        tc.verifyTrue(inside(g.gold, r), [name ': gold frame on screen']);
                        tc.verifyGreaterThan(g.goldWidth, q.chosenWidth, [name ': thick']);
                        tc.verifyEqual(g.chosenFrame, q.frame.(a), [name ': the white frame on the chosen card']);
                        tc.verifyEqual(g.chosenWidth, q.chosenWidth);
                        % the cards are the question screen's: same size, same place
                        tc.verifyEqual(g.card, q.card);
                        tc.verifyEqual(width(g.card.no), width(g.card.yes), 'AbsTol', 1e-9);
                    end
                end
            end
        end

        function tickOnTheChosenCardFadeOnTheWrongOne(tc)
            for k = 1:numel(tc.Windows)
                r = tc.Windows{k};
                q = kidsQuestionLayout(r);
                for a = tc.Answers
                    g = kidsFeedbackLayout(r, kidsFeedbackBeat(a, a, 1));
                    tc.verifyTrue(g.tick.active);
                    tc.verifyTrue(inside(bbox(g.tick.points), g.card.(a)), 'the tick over the chosen card');
                    tc.verifyFalse(g.fadeChosen.active);
                    other = setdiff(tc.Answers, a);
                    g = kidsFeedbackLayout(r, kidsFeedbackBeat(a, other, 1));
                    tc.verifyFalse(g.tick.active);
                    tc.verifyTrue(g.fadeChosen.active);
                    tc.verifyTrue(inside(q.card.(a), g.fadeChosen.rect), 'the chosen (wrong) card fades...');
                    tc.verifyTrue(inside(g.fadeChosen.rect, q.frame.(a) + [1 1 -1 -1] * q.chosenWidth), ...
                        '...inside its white frame, which stays');
                    tc.verifyGreaterThan(g.fadeChosen.alpha, 0.3);
                end
            end
        end

        % --- drawing -----------------------------------------------------------------
        function drawsAllFourCombinationsWithTheStandIns(tc)
            here = fileparts(mfilename('fullpath'));
            tc.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(here, 'ptbstubs')));
            txt = kidsText("en");
            for k = [1 4]
                scr = struct('win', 1, 'winRect', tc.Windows{k}, 'colours', colours());
                for a = tc.Answers
                    for truth = tc.Answers
                        for p = [0 0.2 0.5 0.8 1]
                            kidsQuestion(scr, txt, a, true, truth, p);
                        end
                    end
                end
                kidsQuestion(scr, txt);                     % the question screen still works
                kidsQuestion(scr, txt, "yes");
                kidsQuestion(scr, txt, "no", true);
            end
            tc.verifyTrue(true);
        end

        function rendersTheCorrectCardInGold(tc)
            % Real Psychtoolbox, small window: only where it can open one in this session.
            tc.assumeTrue(endsWith(which('Screen'), mexext), 'Psychtoolbox is not on the path.');
            oldSync = Screen('Preference', 'SkipSyncTests', 1);
            oldDebug = Screen('Preference', 'VisualDebugLevel', 0);
            oldVerb = Screen('Preference', 'Verbosity', 0);
            tc.addTeardown(@() Screen('Preference', 'SkipSyncTests', oldSync));
            tc.addTeardown(@() Screen('Preference', 'VisualDebugLevel', oldDebug));
            tc.addTeardown(@() Screen('Preference', 'Verbosity', oldVerb));
            c = colours();
            try
                [w, r] = Screen('OpenWindow', max(Screen('Screens')), c.background * 255, [0 0 640 360]);
            catch err
                tc.assumeFail(['Psychtoolbox cannot open a window here: ' err.message]);
            end
            tc.addTeardown(@() Screen('Close', w));
            Screen('ColorRange', w, 1);
            Screen('BlendFunction', w, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');
            Screen('TextFont', w, 'Arial');
            Screen('TextSize', w, round(48 * r(4) / 1440));
            scr = struct('win', w, 'winRect', r, 'colours', c);
            txt = kidsText("en");
            gold = kidsFeedbackLayout(r, kidsFeedbackBeat("yes", "yes", 1)).goldColour;
            for a = tc.Answers
                for truth = tc.Answers
                    g = kidsFeedbackLayout(r, kidsFeedbackBeat(a, truth, 1));
                    img = grab(scr, txt, a, true, truth, 1);
                    other = setdiff(tc.Answers, truth);
                    tc.verifyTrue(hasColour(band(img, g.gold, g.goldWidth), gold), 'gold round the correct card');
                    tc.verifyFalse(hasColour(band(img, g.gold + [1 0 -1 0] * (g.card.(other)(1) - g.card.(truth)(1)), ...
                        g.goldWidth), gold), 'no gold round the other card');
                end
            end
            % wrong: the chosen card is faded compared with the question screen
            plain = grab(scr, txt, "no", true);
            g = kidsFeedbackLayout(r, kidsFeedbackBeat("no", "yes", 1));
            wrong = grab(scr, txt, "no", true, "yes", 1);
            inset = [1 1 -1 -1] * 2 * g.radius;
            a1 = region(plain, g.card.no + inset); a2 = region(wrong, g.card.no + inset);
            tc.verifyGreaterThan(mean(abs(a1(:) - a2(:))), 0.05, 'chosen wrong card faded');
        end
    end
end

function c = colours()
c = struct('background', [0.55 0.82 0.95], 'monster', [150 80 200] / 255, ...
    'monsterDark', [110 55 160] / 255, 'belly', [200 160 235] / 255, 'mouth', [0.25 0.05 0.2], ...
    'shake', [1 0.6 0.75], 'straw', [1 0.95 0.5], 'bubble', [1 1 1], 'mouse', [0.6 0.6 0.62], ...
    'mouseEar', [1 0.7 0.75], 'star', [1 0.82 0.1], 'slot', [1 1 1], 'text', [0.1 0.1 0.25], ...
    'cardEasy', [1 0.96 0.88], 'cardSquishy', [0.94 0.88 1]);
end

function w = width(r), w = r(3) - r(1); end

function r = bbox(p), r = [min(p(:, 1)), min(p(:, 2)), max(p(:, 1)), max(p(:, 2))]; end

function tf = inside(a, b)
% Rect a lies within rect b (1 px tolerance).
tf = a(1) >= b(1) - 1 && a(2) >= b(2) - 1 && a(3) <= b(3) + 1 && a(4) <= b(4) + 1;
end

function img = grab(scr, txt, varargin)
kidsQuestion(scr, txt, varargin{:});
Screen('DrawingFinished', scr.win);
img = double(Screen('GetImage', scr.win, [], 'backBuffer')) / 255;
Screen('Flip', scr.win);
end

function px = region(img, r)
r = round(r);
r = [max(r(1), 0), max(r(2), 0), min(r(3), size(img, 2)), min(r(4), size(img, 1))];
px = img(r(2) + 1:r(4), r(1) + 1:r(3), :);
end

function px = band(img, r, lw)
% The pixels of a frame's left and right bands (outer edge r, line width lw).
r = round(r); lw = max(1, round(lw));
a = region(img, [r(1), r(2) + lw, r(1) + lw, r(4) - lw]);
b = region(img, [r(3) - lw, r(2) + lw, r(3), r(4) - lw]);
px = [reshape(a, [], 3); reshape(b, [], 3)];
end

function tf = hasColour(px, rgb)
px = reshape(px, [], 3);
tf = any(all(abs(px - rgb) < 4 / 255, 2));
end
