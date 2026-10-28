function validateConfig(cfg)
%VALIDATECONFIG Reject a task configuration that cannot run as intended.
%   validateConfig(cfg)   errors with rrst:badConfig and the reason.
%   Device-dependent limits (mm levels vs the device's range) are checked again by
%   rrst.Stimulator.validateLevels once the device record is known.

bad = @(msg, varargin) error('rrst:badConfig', ['Configuration: ' msg], varargin{:});

if ~any(cfg.stim.unit == ["percent" "mm"])
    bad('stim.unit must be "percent" or "mm" (got "%s").', cfg.stim.unit);
end
switch cfg.procedure
    case "psi"
        nTotal = cfg.psi.numTrials + cfg.metacogTrials;
        levels = cfg.psi.stimRange;
    case "quest"
        nTotal = cfg.quest.numStaircases * cfg.quest.numTrials + cfg.metacogTrials;
        levels = [cfg.quest.xMin cfg.quest.xMax];
    otherwise
        bad('procedure "%s" is not ported to 2.0 (use "psi" or "quest").', cfg.procedure);
end
if mod(nTotal, 2) ~= 0
    bad(['the total number of trials (%d) must be even, so the stimulus is in the ' ...
         'first and second breath equally often.'], nTotal);
end
if any(levels < 0)
    bad('stimulus levels must be >= 0.');
end
if cfg.stim.unit == "percent" && any([levels cfg.stim.restRange] > 100)
    bad('percent levels must be <= 100 (got max %g).', max([levels cfg.stim.restRange]));
end
if cfg.runTutorial && cfg.stim.unit == "percent" && ...
        any([cfg.tutorial.easyStim cfg.tutorial.hardStim cfg.tutorial.exampleStimuli] > 100)
    bad('tutorial levels must be <= 100 percent.');
end
if cfg.timing.itiMin > cfg.timing.itiMax
    bad('timing.itiMin must not exceed timing.itiMax.');
end
end
