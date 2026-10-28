classdef TestObstructionToSteps < matlab.unittest.TestCase
    % Known-answer tests for rrst.obstructionToSteps and rrst.anchorsFromCalibration.
    % All step values below are FICTIONAL and were worked out by hand:
    %   zeroStep 21000, fullStep 44000, scaleMax 17 (mm):
    %     8.5 mm -> 21000 + 8.5/17 * 23000 = 32500
    %     1 mm   -> 21000 + 23000/17 = 22352.94 -> 22353
    %   scaleMax 100 (percent): 25 % -> 21000 + 0.25 * 23000 = 26750
    %   scaleMax 18, zeroStep 20000, fullStep 44000:
    %     12.5 mm -> 20000 + 12.5/18 * 24000 = 36666.67 -> 36667
    %   anchors: MaxPosition 45123, zeroOffset 24000, fullOffset 1000
    %     -> zeroStep 21123, fullStep 44123

    methods (Test)
        function midpointMm(tc)
            tc.verifyEqual(rrst.obstructionToSteps(8.5, 17, 21000, 44000), 32500);
        end

        function endpointsMm(tc)
            tc.verifyEqual(rrst.obstructionToSteps(0, 17, 21000, 44000), 21000);
            tc.verifyEqual(rrst.obstructionToSteps(17, 17, 21000, 44000), 44000);
        end

        function roundsToNearestStep(tc)
            tc.verifyEqual(rrst.obstructionToSteps(1, 17, 21000, 44000), 22353);
            tc.verifyEqual(rrst.obstructionToSteps(12.5, 18, 20000, 44000), 36667);
        end

        function percentScale(tc)
            tc.verifyEqual(rrst.obstructionToSteps(25, 100, 21000, 44000), 26750);
        end

        function aboveScaleIsAnErrorNotClipped(tc)
            % The original scale2motorstep used rescale([0 x 17], ...), which maps any
            % x > 17 to full obstruction. That is how the ITI "rest" of 20-80 became
            % full obstruction in mm mode. Out-of-range input must raise an error.
            tc.verifyError(@() rrst.obstructionToSteps(20, 17, 21000, 44000), 'rrst:outOfRange');
            tc.verifyError(@() rrst.obstructionToSteps(50, 17, 21000, 44000), 'rrst:outOfRange');
        end

        function belowZeroIsAnError(tc)
            tc.verifyError(@() rrst.obstructionToSteps(-1, 17, 21000, 44000), 'rrst:outOfRange');
        end

        function nonFiniteOrNonScalarIsAnError(tc)
            tc.verifyError(@() rrst.obstructionToSteps(NaN, 17, 21000, 44000), 'rrst:outOfRange');
            tc.verifyError(@() rrst.obstructionToSteps(Inf, 17, 21000, 44000), 'rrst:outOfRange');
            tc.verifyError(@() rrst.obstructionToSteps([1 2], 17, 21000, 44000), 'rrst:outOfRange');
        end

        function invalidMapIsAnError(tc)
            tc.verifyError(@() rrst.obstructionToSteps(5, 17, 44000, 21000), 'rrst:badMap');
            tc.verifyError(@() rrst.obstructionToSteps(5, 17, 21000, 21000), 'rrst:badMap');
            tc.verifyError(@() rrst.obstructionToSteps(5, 0, 21000, 44000), 'rrst:badMap');
            tc.verifyError(@() rrst.obstructionToSteps(5, 17, NaN, 44000), 'rrst:badMap');
        end

        function anchorsFollowMaxPosition(tc)
            [zeroStep, fullStep] = rrst.anchorsFromCalibration(45123, 24000, 1000);
            tc.verifyEqual(zeroStep, 21123);
            tc.verifyEqual(fullStep, 44123);
        end

        function fullScaleAtEndstopIsAllowed(tc)
            [~, fullStep] = rrst.anchorsFromCalibration(45123, 24000, 0);
            tc.verifyEqual(fullStep, 45123);
        end

        function invalidAnchorsAreErrors(tc)
            % zero must lie further from the max endstop than full scale
            tc.verifyError(@() rrst.anchorsFromCalibration(45123, 1000, 24000), 'rrst:badAnchors');
            tc.verifyError(@() rrst.anchorsFromCalibration(45123, 1000, 1000), 'rrst:badAnchors');
            % zero cannot lie behind the min endstop
            tc.verifyError(@() rrst.anchorsFromCalibration(45123, 50000, 1000), 'rrst:badAnchors');
            tc.verifyError(@() rrst.anchorsFromCalibration(45123, 24000, -5), 'rrst:badAnchors');
            tc.verifyError(@() rrst.anchorsFromCalibration(NaN, 24000, 1000), 'rrst:badAnchors');
        end
    end
end
