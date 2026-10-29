classdef TestEscape < matlab.unittest.TestCase
    % Esc must abort the adult task from every participant-facing screen, also when
    % answers are given with the mouse. Psychtoolbox is replaced by the stand-ins in
    % tests/ptbstubs (scripted mouse buttons, Esc from a given KbCheck call, fake clock).

    properties
        scr
    end

    methods (TestClassSetup)
        function addPaths(tc)
            here = fileparts(mfilename('fullpath'));
            root = fileparts(here);
            p = {fullfile(here, 'ptbstubs'), fullfile(root, 'task', 'helpers')};
            addpath(p{:});                      % stubs first: they shadow Psychtoolbox
            tc.addTeardown(@() rmpath(p{:}));
            tc.addTeardown(@() clear('global', 'PTBSTUB'));
        end
    end

    methods (TestMethodSetup)
        function screenAndInput(tc)
            tc.scr = struct('pluxDur', [4 4], 'hz', 60, 'win', 1, 'BackgroundGray', 0.5, ...
                'winRect', [0 0 2560 1440], 'height', 1440, 'TextColour', 1, 'rad', 240, ...
                'x_middle', 1280, 'y_middle', 720);
            script(zeros(1, 3), Inf);
        end
    end

    methods (Test)
        function escOnMouseResponseScreenAborts(tc)
            global PTBSTUB
            script(zeros(1, 3), 5);
            vars = getResponse(keys(), tc.scr, responseVars());
            tc.verifyEqual(vars.abortFlag, 1);
            tc.verifyEqual(vars.ValidTrial(1), 0);
            tc.verifyLessThan(PTBSTUB.t, 1, 'returned long before the 3-s response window ended');
        end

        function mouseResponseWithoutEscStillWorks(tc)
            script([zeros(5, 3); 1 0 0], Inf);
            vars = getResponse(keys(), tc.scr, responseVars());
            tc.verifyEqual(vars.abortFlag, 0);
            tc.verifyEqual(vars.RespLR, 0);
            tc.verifyEqual(vars.ValidTrial(1), 1);
        end

        function responseAfterAnAbortReturnsAtOnce(tc)
            global PTBSTUB
            v = responseVars(); v.abortFlag = 1;
            vars = getResponse(keys(), tc.scr, v);
            tc.verifyEqual(vars.ValidTrial(1), 0);
            tc.verifyEqual(PTBSTUB.nMouse, 0, 'no response is collected after Esc');
        end

        function escOnConfidenceSliderAborts(tc)
            script(zeros(1, 3), 5);
            v = responseVars();
            v.InstructionConf = 'How confident?'; v.ConfEndPoins = {'Guess', 'Certain'};
            v.ConfT = 5; v.ConfResp = NaN;
            vars = getConfidence(keys(), tc.scr, v);
            tc.verifyEqual(vars.abortFlag, 1);
            tc.verifyEqual(vars.ValidTrial(2), 0);
        end

        function sliderReportsEsc(tc)
            script(zeros(1, 3), 5);
            [~, ~, ~, answer] = slideScale(1, 'q', [0 0 2560 1440], {'a', 'b'}, 'scalalength', 0.6, ...
                'device', 'mouse', 'startposition', 'shuffle', 'range', 2, 'aborttime', 5);
            tc.verifyEqual(answer, -1);
        end

        function escDuringBreathingCircleAborts(tc)
            global PTBSTUB
            script(zeros(1, 3), Inf);
            [~, full] = showExpandingRingGenerated(tc.scr, ringVars());
            nFull = PTBSTUB.nFlip;
            tc.verifyEqual(full.abortFlag, 0);
            script(zeros(1, 3), 3);
            [~, vars] = showExpandingRingGenerated(tc.scr, ringVars());
            tc.verifyEqual(vars.abortFlag, 1);
            tc.verifyLessThan(PTBSTUB.nFlip, nFull / 2, 'the circle stops soon after Esc');
        end
    end
end

function script(buttons, escAt)
global PTBSTUB
PTBSTUB = struct('buttons', buttons, 'escAt', escAt, 't', 0, 'nMouse', 0, 'nKb', 0, 'nFlip', 0);
end

function k = keys()
k = struct('Escape', 27, 'Left', 37, 'Right', 39, 'One', 49, 'Two', 50, 'Three', 51, ...
    'KeyCode', zeros(1, 256));
end

function v = responseVars()
v = struct('StartRT', 0, 'RespT', 3, 'InputDevice', 2, 'fixedTiming', 0, 'RespLR', NaN, ...
    'ValidTrial', [0 0], 'InstructionQ', 'Which was harder?', 'pluxSynch', 0, 'abortFlag', 0);
end

function v = ringVars()
v = struct('breathPauseT', 0.2, 'inhaleT', 0.8, 'exhaleT', 1, 'pluxSynch', 0, ...
    'InstructionInhale', 'Inhale', 'stimIsHere', 1, 'abortFlag', 0);
end
