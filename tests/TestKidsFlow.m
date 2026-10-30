classdef TestKidsFlow < matlab.unittest.TestCase
    % RRST-Kids breath feedback: the breath detector kidsFlow, the synthetic flow
    % source kidsSimFlow and the belly scale kidsBreathScale. Synthetic flow only:
    % no sensor, no LSL, no screen. Plan: docs/kids_flow_feedback_and_ux_plan_2026-10-30.md.

    properties (Constant)
        NOISE = 0.3          % slm, gaussian sensor noise in the synthetic flow
    end

    methods (TestClassSetup)
        function addKidsPath(tc)
            root = fileparts(fileparts(mfilename('fullpath')));
            p = fullfile(root, 'task', 'RRST_kids', {'config', 'code'});
            addpath(p{:});
            tc.addTeardown(@() rmpath(p{:}));
        end
    end

    methods (Static)
        function p = pilotFlow()
            % Pilot values of plan section 2, local so the tests do not follow tuning.
            p.enabled = true;
            p.feedback = "breath";
            p.timeout = 10;
            p.onsetSlm = 3;
            p.onsetHold = 0.05;
            p.offsetHold = 0.15;
            p.minVolumeFrac = 0.25;
            p.minVolumeL = 0.10;
            p.bellyFraction = 0.40;
            p.refVolumeDefault = 0.6;
            p.slurpTimeout = 8;
            p.maxSlurpDur = 6;
            p.smoothHz = 5;
        end

        function v = halfSineVolume(peakSlm, durS)
            v = peakSlm * durS * 2 / pi / 60;          % litres
        end
    end

    methods
        function [f, src] = started(tc, varargin)
            src = kidsSimFlow('Noise', tc.NOISE, 'Seed', 1, varargin{:});
            f = kidsFlow(src, tc.pilotFlow());
            f.start();
        end

        function ev = feed(~, f, src, seconds, step)
            % Advance the clock in frame-sized steps, calling update() like the task.
            if nargin < 5, step = 0.02; end
            ev = [];
            for k = 1:round(seconds / step)
                src.advance(step);
                ev = [ev; f.update()]; %#ok<AGROW>
            end
        end
    end

    methods (Test)
        % --- kidsBreathScale ------------------------------------------------------
        function scaleIsVolumeOverFractionOfReference(tc)
            tc.verifyEqual(kidsBreathScale(0.12, 0.6, 0.4), 0.5, 'AbsTol', 1e-12);
            tc.verifyEqual(kidsBreathScale(0.24, 0.6, 0.4), 1, 'AbsTol', 1e-12);
        end

        function scaleSaturatesAtOne(tc)
            tc.verifyEqual(kidsBreathScale(5, 0.6, 0.4), 1);
        end

        function scaleIsZeroForNoVolume(tc)
            tc.verifyEqual(kidsBreathScale(0, 0.6, 0.4), 0);
            tc.verifyEqual(kidsBreathScale(-0.1, 0.6, 0.4), 0);
        end

        function scaleRejectsBadReferenceOrFraction(tc)
            tc.verifyError(@() kidsBreathScale(0.1, 0, 0.4), 'rrst:outOfRange');
            tc.verifyError(@() kidsBreathScale(0.1, -1, 0.4), 'rrst:outOfRange');
            tc.verifyError(@() kidsBreathScale(0.1, 0.6, 0), 'rrst:outOfRange');
            tc.verifyError(@() kidsBreathScale(0.1, 0.6, -0.4), 'rrst:outOfRange');
        end

        % --- kidsSimFlow ----------------------------------------------------------
        function simSamplesArriveAtTheNominalRate(tc)
            src = kidsSimFlow();
            src.advance(1);
            s = src.pull();
            tc.verifySize(s, [1000 2]);
            tc.verifyEqual(diff(s(:, 1)), repmat(1e-3, 999, 1), 'AbsTol', 1e-9);
        end

        function simTimestampsIncreaseAcrossPulls(tc)
            src = kidsSimFlow('Noise', tc.NOISE);
            t = zeros(0, 1);
            for k = 1:150                              % uneven, frame-like chunks
                src.advance(0.0167);
                s = src.pull();
                tc.verifySize(s, [size(s, 1) 2]);
                t = [t; s(:, 1)]; %#ok<AGROW>
            end
            tc.verifyTrue(all(diff(t) > 0), 'timestamps must strictly increase');
            tc.verifyEqual(numel(t), floor(150 * 0.0167 * 1000), 'AbsTol', 1);
            tc.verifyEqual(median(diff(t)), 1e-3, 'AbsTol', 1e-9);
        end

        function simPullWithoutAdvanceIsEmpty(tc)
            src = kidsSimFlow();
            src.advance(0.1);
            src.pull();
            tc.verifySize(src.pull(), [0 2]);
            tc.verifyFalse(src.lost);
        end

        function simBreathIsAHalfSineThenBackflow(tc)
            src = kidsSimFlow();                       % no noise
            src.advance(0.5);
            src.pull();
            src.breathe(30, 1.5);
            src.advance(4);
            s = src.pull();
            tc.verifyEqual(max(s(:, 2)), 30, 'AbsTol', 0.01);
            vol = sum(max(s(:, 2), 0)) * 1e-3 / 60;
            tc.verifyEqual(vol, tc.halfSineVolume(30, 1.5), 'RelTol', 0.01);
            back = s(:, 1) > 0.5 + 1.6 & s(:, 1) < 0.5 + 2.9;
            tc.verifyEqual(s(back, 2), repmat(-2, nnz(back), 1), 'AbsTol', 1e-9);
            tc.verifyEqual(s(s(:, 1) > 0.5 + 3.1, 2), zeros(nnz(s(:, 1) > 0.5 + 3.1), 1));
        end

        function simQuietCancelsScheduledBreaths(tc)
            src = kidsSimFlow();
            src.breathe(30, 1.5, 3, 4);
            src.quiet();
            src.advance(15);
            tc.verifyEqual(max(abs(src.pull())), [15 0], 'AbsTol', 1e-9);
        end

        % --- kidsFlow: detection ----------------------------------------------------
        function cleanBreathGivesOneOnsetAndOneEnd(tc)
            [f, src] = tc.started();
            tc.feed(f, src, 1);
            t0 = src.t;
            src.breathe(30, 1.5);
            ev = tc.feed(f, src, 5);
            tc.assertEqual([ev.type], ["onset" "end"]);
            tc.verifyEqual(ev(1).t, t0, 'AbsTol', 0.15);
            tc.verifyEqual(ev(2).t, t0 + 1.5, 'AbsTol', 0.15);
            tc.verifyEqual(ev(2).volumeL, tc.halfSineVolume(30, 1.5), 'RelTol', 0.05);
            tc.verifyEqual(ev(2).peakSlm, 30, 'AbsTol', 1);
            tc.verifyEqual(ev(2).durationS, 1.5, 'AbsTol', 0.2);
            tc.verifyEqual(f.counted, 1);
            tc.verifyFalse(f.inSlurp);
            tc.verifyEqual(f.lastSampleT, src.t, 'AbsTol', 1.5e-3);
        end

        function slurpRecordHoldsTheBreath(tc)
            [f, src] = tc.started();
            src.breathe(30, 1.5);
            tc.feed(f, src, 4);
            s = f.slurps;
            tc.assertNumElements(s, 1);
            tc.verifyTrue(s.counted);
            tc.verifyEqual(s.durationS, s.endT - s.onsetT, 'AbsTol', 1e-12);
            tc.verifyEqual(s.volumeL, tc.halfSineVolume(30, 1.5), 'RelTol', 0.05);
            tc.verifyEqual(s.peakSlm, 30, 'AbsTol', 1);
        end

        function updateWithNothingNewReturnsNoEvents(tc)
            [f, src] = tc.started();
            ev = tc.feed(f, src, 1);
            tc.verifyEmpty(ev);
            ev = f.update();
            tc.verifyEmpty(ev);
            tc.verifyTrue(isstruct(ev));
            tc.verifyTrue(all(isfield(ev, {'type', 't', 'volumeL', 'peakSlm', 'durationS'})));
        end

        function backflowNeverTriggers(tc)
            [f, src] = tc.started();
            src.breathe(30, 1.5);                      % followed by -2 slm for 1.5 s
            ev = tc.feed(f, src, 8);
            tc.verifyEqual([ev.type], ["onset" "end"]);
            tc.verifyEqual(ev(2).volumeL, tc.halfSineVolume(30, 1.5), 'RelTol', 0.05, ...
                'backflow must not subtract from the volume');
        end

        function backflowAloneIsIgnored(tc)
            src = kidsSimFlow('Noise', tc.NOISE, 'Seed', 2);
            src.extra = @(t) -2 * (t > 1 & t < 2.5);
            f = kidsFlow(src, tc.pilotFlow());
            f.start();
            ev = tc.feed(f, src, 4);
            tc.verifyEmpty(ev);
            tc.verifyEqual(f.belly, 0);
        end

        function smallWobbleNeverTriggers(tc)
            [f, src] = tc.started();
            src.extra = @(t) sin(2 * pi * 1 * t);      % +-1 slm at 1 Hz, plus noise
            ev = tc.feed(f, src, 7);
            tc.verifyEmpty(ev);
            tc.verifyFalse(f.inSlurp);
            tc.verifyEqual(f.counted, 0);
        end

        function tinyBreathIsWeak(tc)
            [f, src] = tc.started();
            src.breathe(6, 0.8);                       % 0.05 L: below 0.10 L and 25 % of 0.6
            ev = tc.feed(f, src, 4);
            tc.assertEqual([ev.type], ["onset" "weak"]);
            tc.verifyLessThan(ev(2).volumeL, 0.10);
            tc.verifyEqual(f.counted, 0);
            tc.verifyFalse(f.slurps.counted);
            tc.verifyEqual(f.belly, 0);
        end

        function breathBelowQuarterOfLargeReferenceIsWeak(tc)
            [f, src] = tc.started();
            f.setReference([2 2]);                     % min volume 0.5 L
            src.breathe(20, 1);                        % 0.21 L: above 0.10 L, below 0.5 L
            ev = tc.feed(f, src, 4);
            tc.assertEqual([ev.type], ["onset" "weak"]);
            tc.verifyGreaterThan(ev(2).volumeL, 0.10);
            tc.verifyLessThan(ev(2).volumeL, 0.5);
            tc.verifyEqual(f.counted, 0);
        end

        function longBreathIsOverlong(tc)
            [f, src] = tc.started();
            src.breathe(20, 7);
            ev = tc.feed(f, src, 10);
            tc.assertEqual([ev.type], ["onset" "overlong"]);
            tc.verifyEqual(ev(2).t - ev(1).t, 6, 'AbsTol', 0.05);
            tc.verifyEqual(f.counted, 0);
            tc.verifyFalse(f.slurps.counted);
            tc.verifyEqual(f.belly, 0);
            tc.verifyFalse(f.inSlurp);
        end

        function detectorRecoversAfterOverlong(tc)
            [f, src] = tc.started();
            src.breathe(20, 7);
            tc.feed(f, src, 10);
            src.breathe(30, 1.5);
            ev = tc.feed(f, src, 4);
            tc.verifyEqual([ev.type], ["onset" "end"]);
            tc.verifyEqual(f.counted, 1);
            tc.verifyNumElements(f.slurps, 2);
        end

        function threeGoodBreathsAreCounted(tc)
            [f, src] = tc.started();
            src.breathe(30, 1.5, 3, 4);                % every 4 s
            ev = tc.feed(f, src, 14);
            tc.verifyEqual([ev.type], repmat(["onset" "end"], 1, 3));
            tc.verifyEqual(f.counted, 3);
            tc.verifyNumElements(f.slurps, 3);
            tc.verifyTrue(all([f.slurps.counted]));
        end

        % --- kidsFlow: belly ----------------------------------------------------------
        function bellyFillsMonotonicallyAndSaturates(tc)
            [f, src] = tc.started();
            f.setReference(1);                         % belly full at 0.4 L
            tc.feed(f, src, 1);
            t0 = src.t;
            src.breathe(30, 2);                        % 0.64 L
            b = [];
            t = [];
            while src.t < t0 + 2.5
                src.advance(0.02);
                f.update();
                if f.inSlurp
                    b(end+1) = f.belly; %#ok<AGROW>
                    t(end+1) = src.t; %#ok<AGROW>
                end
            end
            tc.verifyGreaterThanOrEqual(diff(b), 0, 'belly must never shrink during a slurp');
            tc.verifyLessThan(b(find(t >= t0 + 0.8, 1)), 1, ...
                '0.22 L in: belly not yet full');
            tc.verifyEqual(b(find(t >= t0 + 1.4, 1)), 1, ...
                '0.50 L in: past 40 % of the reference, belly full');
            tc.feed(f, src, 2);
            tc.verifyEqual(f.belly, 0, 'belly empties after the end');
        end

        function bellyIsZeroBeforeAnySlurp(tc)
            [f, src] = tc.started();
            tc.feed(f, src, 1);
            tc.verifyEqual(f.belly, 0);
            tc.verifyFalse(f.inSlurp);
        end

        % --- kidsFlow: reference volume -------------------------------------------------
        function referenceStartsAtTheDefault(tc)
            f = kidsFlow(kidsSimFlow(), tc.pilotFlow());
            tc.verifyEqual(f.refVolume, 0.6);
        end

        function setReferenceUsesTheMedianAndReturnsThresholds(tc)
            f = kidsFlow(kidsSimFlow(), tc.pilotFlow());
            [minL, fullL] = f.setReference([0.4 0.5]);
            tc.verifyEqual(f.refVolume, 0.45, 'AbsTol', 1e-12);
            tc.verifyEqual(minL, 0.1125, 'AbsTol', 1e-12);
            tc.verifyEqual(fullL, 0.18, 'AbsTol', 1e-12);
        end

        function setReferenceClamps(tc)
            f = kidsFlow(kidsSimFlow(), tc.pilotFlow());
            [minL, fullL] = f.setReference([0.05 0.1]);
            tc.verifyEqual(f.refVolume, 0.15, 'AbsTol', 1e-12);
            tc.verifyEqual(minL, 0.10, 'AbsTol', 1e-12, 'absolute floor wins');
            tc.verifyEqual(fullL, 0.06, 'AbsTol', 1e-12);
            [minL, fullL] = f.setReference([3 4]);
            tc.verifyEqual(f.refVolume, 2, 'AbsTol', 1e-12);
            tc.verifyEqual(minL, 0.5, 'AbsTol', 1e-12);
            tc.verifyEqual(fullL, 0.8, 'AbsTol', 1e-12);
        end

        function setReferenceWithoutSlurpsKeepsTheReference(tc)
            f = kidsFlow(kidsSimFlow(), tc.pilotFlow());
            [minL, fullL] = f.setReference([]);
            tc.verifyEqual(f.refVolume, 0.6);
            tc.verifyEqual(minL, 0.15, 'AbsTol', 1e-12);
            tc.verifyEqual(fullL, 0.24, 'AbsTol', 1e-12);
            f.setReference([NaN NaN]);
            tc.verifyEqual(f.refVolume, 0.6);
            f.setReference([0.4 NaN]);
            tc.verifyEqual(f.refVolume, 0.4, 'AbsTol', 1e-12);
        end

        % --- kidsFlow: phase control ---------------------------------------------------
        function timesOutWithoutABreath(tc)
            [f, src] = tc.started();
            tc.verifyFalse(f.timedOut);
            tc.feed(f, src, 7.5);
            tc.verifyFalse(f.timedOut);
            tc.feed(f, src, 1);
            tc.verifyTrue(f.timedOut);
        end

        function timeoutRestartsAfterEachEnd(tc)
            [f, src] = tc.started();
            tc.feed(f, src, 5);
            src.breathe(30, 1.5);
            tc.feed(f, src, 1);
            tc.verifyTrue(f.inSlurp);
            tc.verifyFalse(f.timedOut);
            tc.feed(f, src, 6);                         % breath ended about 5.4 s ago
            tc.verifyEqual(f.counted, 1);
            tc.verifyFalse(f.timedOut);
            tc.feed(f, src, 3);
            tc.verifyTrue(f.timedOut);
        end

        function breathsBeforeStartAreIgnored(tc)
            src = kidsSimFlow('Noise', tc.NOISE, 'Seed', 1);
            f = kidsFlow(src, tc.pilotFlow());
            src.breathe(30, 1.5);
            ev = tc.feed(f, src, 4);                    % update() before start()
            tc.verifyEmpty(ev);
            f.start();
            ev = tc.feed(f, src, 1);
            tc.verifyEmpty(ev);
            tc.verifyEqual(f.counted, 0);
            tc.verifyEmpty(f.slurps);
        end

        function breathInProgressAtStartIsIgnored(tc)
            src = kidsSimFlow('Noise', tc.NOISE, 'Seed', 1);
            f = kidsFlow(src, tc.pilotFlow());
            src.breathe(30, 1.5);
            src.advance(0.5);
            f.start();
            ev = tc.feed(f, src, 4);
            tc.verifyEmpty(ev);
            src.breathe(30, 1.5);
            ev = tc.feed(f, src, 4);
            tc.verifyEqual([ev.type], ["onset" "end"]);
        end

        function startClearsThePreviousPhase(tc)
            [f, src] = tc.started();
            src.breathe(30, 1.5);
            tc.feed(f, src, 4);
            f.setReference(0.5);
            s = f.stop();
            tc.verifyNumElements(s, 1);
            f.start();
            tc.verifyEqual(f.counted, 0);
            tc.verifyEmpty(f.slurps);
            tc.verifyEqual(f.refVolume, 0.5, 'the reference survives a new phase');
        end

        function stopEndsDetection(tc)
            [f, src] = tc.started();
            src.breathe(30, 1.5);
            tc.feed(f, src, 4);
            s = f.stop();
            tc.verifyNumElements(s, 1);
            src.breathe(30, 1.5);
            ev = tc.feed(f, src, 4);
            tc.verifyEmpty(ev);
            tc.verifyNumElements(f.slurps, 1);
        end

        function stopDuringASlurpRecordsItUncounted(tc)
            [f, src] = tc.started();
            src.breathe(30, 1.5);
            tc.feed(f, src, 0.8);
            tc.verifyTrue(f.inSlurp);
            s = f.stop();
            tc.assertNumElements(s, 1);
            tc.verifyFalse(s.counted);
            tc.verifyEqual(f.counted, 0);
            tc.verifyFalse(f.inSlurp);
            tc.verifyEqual(f.belly, 0);
        end

        function lostFollowsTheSource(tc)
            src = kidsSimFlow();
            f = kidsFlow(src, tc.pilotFlow());
            tc.verifyFalse(f.lost);
            src.lost = true;
            tc.verifyTrue(f.lost);
        end

        % --- kidsFlow: configuration ----------------------------------------------------
        function constructorRejectsBadConfig(tc)
            src = kidsSimFlow();
            bad = {'onsetSlm', 0; 'onsetSlm', -3; 'onsetHold', -0.05; 'offsetHold', 0; ...
                'minVolumeFrac', 0; 'minVolumeFrac', 1.5; 'bellyFraction', 0; ...
                'bellyFraction', 1.2; 'minVolumeL', 0; 'refVolumeDefault', -1; ...
                'slurpTimeout', 0; 'maxSlurpDur', 0; 'smoothHz', 0; 'smoothHz', NaN; ...
                'onsetSlm', [3 4]; 'onsetSlm', "3"};
            for k = 1:size(bad, 1)
                p = tc.pilotFlow();
                p.(bad{k, 1}) = bad{k, 2};
                tc.verifyError(@() kidsFlow(src, p), 'rrst:badConfig', ...
                    sprintf('%s = %s', bad{k, 1}, mat2str(bad{k, 2})));
            end
            p = rmfield(tc.pilotFlow(), 'smoothHz');
            tc.verifyError(@() kidsFlow(src, p), 'rrst:badConfig', 'missing field');
            p = tc.pilotFlow();
            p.bellyFraction = 1;                       % fractions may be 1
            kidsFlow(src, p);
        end

        function kidsConfigHasAValidFlowBlock(tc)
            cfg = kidsConfig();
            tc.verifyTrue(cfg.flow.enabled);
            tc.verifyEqual(cfg.flow.feedback, "breath");
            tc.verifyEqual(cfg.flow.minVolumeFrac, 0.25);
            tc.verifyEqual(cfg.flow.minVolumeL, 0.10);
            tc.verifyEqual(cfg.flow.bellyFraction, 0.40);
            f = kidsFlow(kidsSimFlow(), cfg.flow);
            tc.verifyEqual(f.refVolume, cfg.flow.refVolumeDefault);
        end
    end
end
