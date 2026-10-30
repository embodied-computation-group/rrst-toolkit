function validateKidsConfig(cfg)
%VALIDATEKIDSCONFIG Reject an RRST-Kids configuration that is unsafe or cannot run.
%   validateKidsConfig(cfg)   errors with rrst:badConfig and the reason.

ABSOLUTE_MAX = 100;      % percent of the adult scale (full scale); no configuration may exceed it
bad = @(msg, varargin) error('rrst:badConfig', ['Kids configuration: ' msg], varargin{:});

c = cfg.child;
if cfg.stim.unit ~= "percent"
    bad('stim.unit must be "percent" (the cap is a percent of the adult scale).');
end
if ~(isscalar(c.hardCap) && c.hardCap > 0 && c.hardCap <= ABSOLUTE_MAX)
    bad('child.hardCap must be in (0, %d] (got %g).', ABSOLUTE_MAX, c.hardCap);
end
if ~isfield(cfg, 'tutorial') || ~isstruct(cfg.tutorial)
    bad('the tutorial block is missing; start from kidsConfig().');
end
tu = cfg.tutorial;
if ~isfield(tu, 'enabled') || ~isLogicalScalar(tu.enabled)
    bad('tutorial.enabled must be true or false.');
end
if ~isfield(tu, 'pinchLevel') || ~(isPositive(tu.pinchLevel) && tu.pinchLevel <= c.hardCap)
    bad('tutorial.pinchLevel (the pinch demo) must be in (0, %g], the cap.', c.hardCap);
end
if ~isfield(tu, 'demoOrder') || ~(isstring(tu.demoOrder) || iscellstr(tu.demoOrder)) || ...
        isempty(tu.demoOrder) || ~all(ismember(string(tu.demoOrder), ["pinch" "sleep"])) || ...
        numel(unique(string(tu.demoOrder))) < numel(tu.demoOrder)
    bad('tutorial.demoOrder must list "pinch" and/or "sleep", each once.');
end
levels = [cfg.psi.stimRange(:); cfg.psi.priorAlphaRange(:); cfg.practice.levels(:); ...
    cfg.stim.restRange(:); c.startLevel; tu.pinchLevel];
if any(levels > c.hardCap) || any(levels < 0)
    bad('every level (grid, prior, practice, rest, start, tutorial) must be in [0, %g]; max is %g.', ...
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
nFree = cfg.practice.nFree;
if ~(isscalar(nFree) && nFree >= 0 && nFree == round(nFree))
    bad('practice.nFree must be a whole number from 0.');
end
if tu.enabled && nFree > 0
    bad(['practice.nFree must be 0 with the tutorial (its free play replaces the free ' ...
        'slurps); drop the first %d practice levels, or set tutorial.enabled = false.'], nFree);
end
if ~isfield(cfg.timing, 'drain') || ~isPositive(cfg.timing.drain)
    bad('timing.drain (s, the milkshake draining after a slurp) must be a positive number.');
end
if numel(cfg.practice.levels) <= cfg.practice.nFree
    bad('practice.levels must include questioned trials after the %d free ones.', cfg.practice.nFree);
end
if cfg.noise.enabled && strlength(string(cfg.noise.file)) > 0 && ~isfile(cfg.noise.file)
    bad('noise.file not found: %s', cfg.noise.file);
end
if ~isfield(cfg, 'markers') || ~isfield(cfg.markers, 'lsl') || ~isLogicalScalar(cfg.markers.lsl)
    bad('markers.lsl must be true or false.');
end
if ~isfield(cfg.markers, 'requireRecorder') || ~isLogicalScalar(cfg.markers.requireRecorder)
    bad('markers.requireRecorder must be true or false.');
end
if ~isfield(cfg.markers, 'liblslDir') || ~isText(cfg.markers.liblslDir)
    bad('markers.liblslDir must be a folder name (text).');
end
if ~isfield(cfg, 'flow') || ~isstruct(cfg.flow)
    bad('the flow block (breath feedback) is missing; start from kidsConfig().');
end
f = cfg.flow;
if ~isfield(f, 'enabled') || ~isLogicalScalar(f.enabled)
    bad('flow.enabled must be true or false.');
end
if ~isfield(f, 'feedback') || ~isText(f.feedback) || ~ismember(string(f.feedback), ["breath" "none"])
    bad('flow.feedback must be "breath" or "none".');
end
if f.feedback == "breath" && ~f.enabled
    bad(['flow.feedback "breath" needs the airflow sensor (flow.enabled = true); ' ...
        'to run without it set flow.enabled = false and flow.feedback = "none".']);
end
if ~isfield(f, 'timeout') || ~isPositive(f.timeout)
    bad('flow.timeout (s to find the airflow stream) must be a positive number.');
end
if ~isfield(cfg, 'recording') || ~isstruct(cfg.recording) || ~isfield(cfg.recording, 'mode') || ...
        ~isText(cfg.recording.mode) || ~ismember(string(cfg.recording.mode), ["physio" "standalone"])
    bad(['recording.mode must be "physio" (the Physio Recorder records) or "standalone" ' ...
        '(the task records flow and markers itself); start from kidsConfig().']);
end
if string(cfg.recording.mode) == "standalone"
    if ~f.enabled
        bad(['recording.mode "standalone" records the airflow sensor: it needs ' ...
            'flow.enabled = true (and flow.feedback "breath" or "none").']);
    end
    % the files themselves are checked only when the streamer has to be started
    for name = ["streamer" "streamerScript"]
        if ~isfield(f, name) || ~isText(f.(name))
            bad('flow.%s must be a file name (text) in standalone mode; start from kidsConfig().', name);
        end
    end
end
if ~isfield(cfg, 'sound') || ~isstruct(cfg.sound)
    bad('the sound block (cue sounds) is missing; start from kidsConfig().');
end
if ~isfield(cfg.sound, 'enabled') || ~isLogicalScalar(cfg.sound.enabled)
    bad('sound.enabled must be true or false.');
end
if ~isfield(cfg.sound, 'volume') || ~(isPositive(cfg.sound.volume) && cfg.sound.volume <= 1)
    bad('sound.volume must be in (0, 1].');
end
if ~isfield(cfg.sound, 'fs') || ~isPositive(cfg.sound.fs)
    bad('sound.fs must be a positive sample rate (Hz).');
end
end

function tf = isPositive(x)
tf = isnumeric(x) && isreal(x) && isscalar(x) && isfinite(x) && x > 0;
end

function tf = isLogicalScalar(x)
tf = islogical(x) && isscalar(x);
end

function tf = isText(x)
tf = ((isstring(x) && isscalar(x)) || (ischar(x) && isrow(x))) && strlength(string(x)) > 0;
end
