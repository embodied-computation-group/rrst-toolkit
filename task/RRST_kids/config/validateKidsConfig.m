function validateKidsConfig(cfg)
%VALIDATEKIDSCONFIG Reject an RRST-Kids configuration that is unsafe or cannot run.
%   validateKidsConfig(cfg)   errors with rrst:badConfig and the reason.

ABSOLUTE_MAX = 85;       % percent of the adult scale; no child configuration may exceed it
bad = @(msg, varargin) error('rrst:badConfig', ['Kids configuration: ' msg], varargin{:});

c = cfg.child;
if cfg.stim.unit ~= "percent"
    bad('stim.unit must be "percent" (the cap is a percent of the adult scale).');
end
if ~(isscalar(c.hardCap) && c.hardCap > 0 && c.hardCap <= ABSOLUTE_MAX)
    bad('child.hardCap must be in (0, %d] (got %g).', ABSOLUTE_MAX, c.hardCap);
end
levels = [cfg.psi.stimRange(:); cfg.psi.priorAlphaRange(:); cfg.practice.levels(:); ...
    cfg.stim.restRange(:); c.startLevel];
if any(levels > c.hardCap) || any(levels < 0)
    bad('every level (grid, prior, practice, rest, start) must be in [0, %g]; max is %g.', ...
        c.hardCap, max(levels));
end
if ~ismember(0, cfg.psi.stimRange) || ~ismember(c.startLevel, cfg.psi.stimRange)
    bad('psi.stimRange must contain 0 (catch trials) and the start level %g.', c.startLevel);
end
if c.numCatchTrials > c.numPsiTrials
    bad('more catch trials (%d) than Psi trials (%d).', c.numCatchTrials, c.numPsiTrials);
end
if ~(isscalar(c.slurps) && c.slurps >= 1 && c.slurps == round(c.slurps))
    bad('child.slurps (breaths per trial) must be a whole number from 1.');
end
if c.rampMax <= 0 || c.stopMinTrials > c.numPsiTrials
    bad('child.rampMax must be positive and child.stopMinTrials at most numPsiTrials.');
end
if numel(cfg.practice.levels) <= cfg.practice.nFree
    bad('practice.levels must include questioned trials after the %d free ones.', cfg.practice.nFree);
end
if cfg.noise.enabled && strlength(string(cfg.noise.file)) > 0 && ~isfile(cfg.noise.file)
    bad('noise.file not found: %s', cfg.noise.file);
end
end
