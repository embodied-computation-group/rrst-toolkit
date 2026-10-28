function cfg = zurichConfig()
%ZURICHCONFIG Configuration for the Zurich study. Refuses to run until decided.
%   Copy pilotConfig.m's structure here once these decisions are made and
%   pre-registered (see TASKS.md "Open questions" and the decision sheet):
%     {{STIMULUS_UNIT}}      percent of device range, or mm past zero (max 15.5 mm on
%                            the first unit), or a non-uniform / resistance-based grid
%     {{STIMULUS_GRID}}      the levels Psi may choose from
%     {{PSI_PRIORS}}         alpha, beta (paper: log 1-16) and lambda (paper: 0.02)
%     {{REST_POSITION}}      where the wedge rests between trials
%     {{CALIBRATION_TUBE}}   calibrate with the tube in or out (must match the record)
%     {{TUBE_LENGTH}}        production tube length; re-measure full scale after cutting
%     {{NOISE}}              masking noise on/off, colour and level

error('rrst:decisionsPending', ...
    ['The Zurich configuration is not decided yet: stimulus unit and grid, Psi priors, ' ...
     'rest position, calibration condition, tube length and masking noise. ' ...
     'Use pilotConfig() for piloting.']);
cfg = struct(); %#ok<UNRCH>
end
