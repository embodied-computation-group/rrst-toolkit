classdef TestKidsQuestion < matlab.unittest.TestCase
    % RRST-Kids answer screen: two equally nice scene cards, "easy" (no) on the left and
    % "squishy" (yes) on the right. The geometry (kidsQuestionLayout) is pure and tested
    % for any window; the drawing (kidsQuestion) runs against the Psychtoolbox stand-ins
    % and, when Psychtoolbox can open a small window here, is rendered and checked.

    properties (Constant)
        % Window rects: full HD, the stim laptop's external screen, the 1/3-size test
        % window (cfg.smallWindow), a 4:3 projector and a tall window.
        Windows = {[0 0 1600 900], [0 0 2560 1440], [0 0 2560 1440] / 3, ...
            [0 0 1024 768], [0 0 900 1000]}
    end

    methods (TestClassSetup)
        function addKidsPath(tc)
            root = fileparts(fileparts(mfilename('fullpath')));
            p = fullfile(root, 'task', 'RRST_kids', 'code');
            addpath(p);
            tc.addTeardown(@() rmpath(p));
        end
    end

    methods (Test)
        % --- geometry -----------------------------------------------------------
        function cardsHaveIdenticalSize(tc)
            for k = 1:numel(tc.Windows)
                g = kidsQuestionLayout(tc.Windows{k});
                tc.verifyEqual(width(g.card.no), width(g.card.yes), 'AbsTol', 1e-9);
                tc.verifyEqual(height(g.card.no), height(g.card.yes), 'AbsTol', 1e-9);
                tc.verifyGreaterThan(width(g.card.no), 0);
                tc.verifyGreaterThan(height(g.card.no), 0);
                tc.verifyEqual(width(g.frame.no), width(g.frame.yes), 'AbsTol', 1e-9);
                tc.verifyEqual(height(g.frame.no), height(g.frame.yes), 'AbsTol', 1e-9);
            end
        end

        function cardsAreSymmetricAboutTheScreenCentre(tc)
            for k = 1:numel(tc.Windows)
                r = tc.Windows{k}; g = kidsQuestionLayout(r); W = r(3);
                tc.verifyEqual(g.card.no([2 4]), g.card.yes([2 4]), 'AbsTol', 1e-9);
                tc.verifyEqual(g.card.no(1) + g.card.yes(3), W, 'AbsTol', 1e-9);
                tc.verifyEqual(g.card.no(3) + g.card.yes(1), W, 'AbsTol', 1e-9);
                tc.verifyEqual(g.frame.no(1) + g.frame.yes(3), W, 'AbsTol', 1e-9);
                tc.verifyEqual(g.label.no(1) + g.label.yes(1), W, 'AbsTol', 1e-9);
                tc.verifyEqual(g.label.no(2), g.label.yes(2), 'AbsTol', 1e-9);
            end
        end

        function cardsClearTheQuestionBand(tc)
            for k = 1:numel(tc.Windows)
                r = tc.Windows{k}; g = kidsQuestionLayout(r);
                tc.verifyEqual(g.questionBand([1 2 3]), [0 0 r(3)], 'AbsTol', 1e-9);
                tc.verifyGreaterThan(g.questionBand(4), g.questionY);
                for side = ["no" "yes"]
                    tc.verifyGreaterThan(g.card.(side)(2), g.questionBand(4));
                    tc.verifyGreaterThan(g.frame.(side)(2), g.questionBand(4));
                end
            end
        end

        function clicksAgreeWithKidsClickAnswer(tc)
            rs = RandStream('mt19937ar', 'Seed', 4);
            for k = 1:numel(tc.Windows)
                r = tc.Windows{k}; W = r(3); g = kidsQuestionLayout(r);
                x = W * rand(rs, 50, 1);
                x = [x; mean(g.hit.no); mean(g.hit.yes); W / 2];   %#ok<AGROW> one of each for sure
                for i = 1:numel(x)
                    a = kidsClickAnswer(x(i), W);
                    inNo = x(i) >= g.hit.no(1) && x(i) < g.hit.no(2);
                    inYes = x(i) > g.hit.yes(1) && x(i) <= g.hit.yes(2);
                    tc.verifyEqual(a == "no", inNo, sprintf('W = %g, x = %g', W, x(i)));
                    tc.verifyEqual(a == "yes", inYes, sprintf('W = %g, x = %g', W, x(i)));
                    tc.verifyEqual(a == "none", ~inNo && ~inYes, sprintf('W = %g, x = %g', W, x(i)));
                end
            end
        end

        function wholeCardsAndFramesAreClickable(tc)
            % A click anywhere on a card (or its hover frame) gives that card's answer.
            for k = 1:numel(tc.Windows)
                r = tc.Windows{k}; W = r(3); g = kidsQuestionLayout(r);
                tc.verifyGreaterThanOrEqual(g.frame.no(1), g.hit.no(1));
                tc.verifyLessThan(g.frame.no(3), g.hit.no(2));
                tc.verifyGreaterThan(g.frame.yes(1), g.hit.yes(1));
                tc.verifyLessThanOrEqual(g.frame.yes(3), g.hit.yes(2));
                for side = ["no" "yes"]
                    c = g.card.(side);
                    for x = linspace(c(1), c(3), 9)
                        tc.verifyEqual(kidsClickAnswer(x, W), side);
                    end
                end
            end
        end

        function framesHoldTheCardAndItsLabel(tc)
            for k = 1:numel(tc.Windows)
                r = tc.Windows{k}; g = kidsQuestionLayout(r);
                for side = ["no" "yes"]
                    c = g.card.(side); f = g.frame.(side); L = g.labelRect.(side);
                    tc.verifyTrue(inside(c, f), sprintf('card in frame, %s', side));
                    tc.verifyTrue(inside(L, f), sprintf('label in frame, %s', side));
                    tc.verifyGreaterThanOrEqual(L(2), c(4), 'label under the card');
                    tc.verifyEqual(g.label.(side)(1), (c(1) + c(3)) / 2, 'AbsTol', 1e-9);
                    tc.verifyTrue(inside(f, r), sprintf('frame on screen, %s', side));
                    tc.verifyTrue(inside(g.fade.(side), r), sprintf('fade on screen, %s', side));
                    tc.verifyTrue(inside(f, g.fade.(side)), 'fade covers the frame');
                end
                tc.verifyLessThan(g.fade.no(3), g.fade.yes(1), 'fades do not overlap');
            end
        end

        function layoutScalesWithTheWindowHeight(tc)
            big = kidsQuestionLayout([0 0 2560 1440]);
            small = kidsQuestionLayout([0 0 2560 1440] / 3);
            for side = ["no" "yes"]
                tc.verifyEqual(small.card.(side), big.card.(side) / 3, 'RelTol', 1e-9);
                tc.verifyEqual(small.frame.(side), big.frame.(side) / 3, 'RelTol', 1e-9);
            end
            tc.verifyEqual(small.lineWidth, big.lineWidth / 3, 'RelTol', 1e-9);
            tc.verifyGreaterThan(big.chosenWidth, big.lineWidth);
        end

        % --- drawing --------------------------------------------------------------
        function drawsEveryStateWithTheStandIns(tc)
            % Runs the drawing code against the Psychtoolbox stand-ins: every state, any
            % window, no errors (the stand-ins return nothing for queries like TextSize).
            here = fileparts(mfilename('fullpath'));
            stubs = fullfile(here, 'ptbstubs');
            addpath(stubs);
            tc.addTeardown(@() rmpath(stubs));
            txt = struct('question', 'Did the mouse pinch the straw?', 'easy', 'Easy', 'squishy', 'Squishy!');
            for k = 1:numel(tc.Windows)
                scr = struct('win', 1, 'winRect', tc.Windows{k}, 'colours', colours());
                kidsQuestion(scr, txt);
                kidsQuestion(scr, txt, "");
                kidsQuestion(scr, txt, "none");
                for side = ["no" "yes"]
                    kidsQuestion(scr, txt, side);
                    kidsQuestion(scr, txt, side, true);
                end
            end
        end

        function rendersTwoEquallyNiceCards(tc)
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
            txt = struct('question', 'Did the mouse pinch the straw?', 'easy', 'Easy', 'squishy', 'Squishy!');
            g = kidsQuestionLayout(r);

            plain = grab(scr, txt);
            no = region(plain, g.card.no); yes = region(plain, g.card.yes);
            % Equally bright cards, and no red/green "good versus bad" anywhere on them
            tc.verifyLessThan(abs(mean(no(:)) - mean(yes(:))), 0.04, 'card brightness differs');
            tc.verifyFalse(hasColour(no, [0.3 0.75 0.4]) || hasColour(yes, [0.3 0.75 0.4]), 'green on a card');
            tc.verifyFalse(hasColour(no, [0.9 0.35 0.35]) || hasColour(yes, [0.9 0.35 0.35]), 'red on a card');
            % The monster is on both cards
            tc.verifyTrue(hasColour(no, c.monster) && hasColour(yes, c.monster), 'monster missing');

            hover = grab(scr, txt, "yes");
            tc.verifyTrue(hasColour(ring(hover, g.frame.yes), [1 1 1]), 'no hover frame on "yes"');
            tc.verifyFalse(hasColour(ring(hover, g.frame.no), [1 1 1]), 'hover frame on "no"');

            chosen = grab(scr, txt, "yes", true);
            tc.verifyEqual(region(chosen, g.card.yes), yes, 'AbsTol', 1 / 255, 'chosen card changed');
            faded = region(chosen, g.card.no);
            tc.verifyGreaterThan(mean(abs(faded(:) - no(:))), 0.05, 'other card not faded');
        end
    end
end

function c = colours()
% The colours openScreen in kidsMain sets (the card colours are kidsQuestion's own).
c = struct('background', [0.55 0.82 0.95], 'monster', [150 80 200] / 255, ...
    'monsterDark', [110 55 160] / 255, 'belly', [200 160 235] / 255, 'mouth', [0.25 0.05 0.2], ...
    'shake', [1 0.6 0.75], 'straw', [1 0.95 0.5], 'bubble', [1 1 1], 'mouse', [0.6 0.6 0.62], ...
    'mouseEar', [1 0.7 0.75], 'star', [1 0.82 0.1], 'slot', [1 1 1], 'text', [0.1 0.1 0.25], ...
    'easy', [0.3 0.75 0.4], 'squishy', [0.9 0.35 0.35]);
end

function w = width(r), w = r(3) - r(1); end
function h = height(r), h = r(4) - r(2); end

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
px = img(r(2) + 1:r(4), r(1) + 1:r(3), :);
end

function px = ring(img, r)
% Pixels within the hover frame's outer band.
outer = region(img, r);
b = max(2, round(0.01 * size(img, 1)));
px = [reshape(outer(1:b, :, :), [], 3); reshape(outer(end - b + 1:end, :, :), [], 3)];
end

function tf = hasColour(px, rgb)
px = reshape(px, [], 3);
tf = any(all(abs(px - rgb) < 3 / 255, 2));
end
