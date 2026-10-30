classdef kidsSound < handle
    %KIDSSOUND Rain masking loop plus short cue sounds for RRST-Kids.
    %   snd = kidsSound(cfg.noise, cfg.sound)
    %   snd.play("ready")   % returns at once; a cue still playing is cut off first
    %   snd.stop()          % stop the cue (the rain keeps going)
    %   snd.close()         % stop and close everything (delete(snd) does the same)
    %
    %   One PsychPortAudio master device (playback, mode 1+8) is opened at the rain
    %   file's sample rate (cfg.sound.fs when the rain is off) and started for the
    %   whole session. Two slaves are mixed into it: one loops the rain at
    %   cfg.noise.volume (when cfg.noise.enabled), the other plays the cues at
    %   cfg.sound.volume (when cfg.sound.enabled). The cue waveforms come from
    %   kidsCueWave and are made once, here. Cue names: ready, slurp, bubbles, star,
    %   cup, mouse, tryagain.
    %
    %   This replaces startMaskingNoise/stopMaskingNoise for the kids task:
    %       snd = kidsSound(cfg.noise, cfg.sound);   % instead of startMaskingNoise
    %       ...
    %       snd.close();                             % instead of stopMaskingNoise
    %   Do not use both: they would open the audio device twice.
    %
    %   cfg.sound.enabled = false turns the cues off; the rain still follows
    %   cfg.noise.enabled. snd.active says whether cues can play, snd.rainOn whether
    %   the rain is playing.
    %
    %   A sound failure never stops the task: if PsychPortAudio is missing (test
    %   machines) or the device cannot be opened, one warning (rrst:soundOff) is
    %   printed and every method is a silent no-op. A failure in play() turns the cues
    %   off and leaves the rain running. Configuration errors (rrst:badConfig) and an
    %   unknown cue name (rrst:badCue) do throw: they are bugs, not sound failures.

    properties (Constant)
        cueNames = ["ready" "slurp" "bubbles" "star" "cup" "mouse" "tryagain"]
    end

    properties (SetAccess = private)
        active = false      % cues can play
        rainOn = false      % rain loop playing
        fs = NaN            % master sample rate (Hz)
    end

    properties (Access = private)
        master = []
        rain = []
        cue = []
        waves = struct()    % cue name -> 2-by-N samples, volume applied
        warned = false
    end

    methods
        function obj = kidsSound(noiseCfg, soundCfg)
            checkConfig(noiseCfg, soundCfg);
            wantRain = logical(noiseCfg.enabled);
            wantCues = logical(soundCfg.enabled);
            if ~wantRain && ~wantCues
                return
            end
            if exist('PsychPortAudio', 'file') ~= 3
                obj.fail('PsychPortAudio (Psychtoolbox) is not on the path');
                return
            end
            try
                if wantRain
                    [x, obj.fs] = rrst.loadMaskingSound(noiseCfg.file);
                else
                    obj.fs = soundCfg.fs;
                end
                if wantCues
                    for name = kidsSound.cueNames
                        obj.waves.(char(name)) = soundCfg.volume * kidsCueWave(name, obj.fs)';
                    end
                end
                InitializePsychSound(1);
                obj.master = PsychPortAudio('Open', [], 1 + 8, 1, obj.fs, 2);
                PsychPortAudio('Start', obj.master, 0, 0, 1);
                if wantRain
                    obj.rain = PsychPortAudio('OpenSlave', obj.master, 1);
                    PsychPortAudio('FillBuffer', obj.rain, noiseCfg.volume * x');
                    PsychPortAudio('Start', obj.rain, 0, 0, 1);   % 0 = loop until stopped
                    obj.rainOn = true;
                end
                if wantCues
                    obj.cue = PsychPortAudio('OpenSlave', obj.master, 1);
                    obj.active = true;
                end
            catch err
                if obj.rainOn
                    obj.closeCue();       % the rain is running: keep the masking
                else
                    obj.close();
                end
                obj.fail(err.message);
                return
            end
            if wantRain
                [~, f, e] = fileparts(noiseCfg.file);
                rainText = sprintf('rain %s at volume %g (%.0f s loop)', [f e], ...
                    noiseCfg.volume, size(x, 1) / obj.fs);
            else
                rainText = 'no rain';
            end
            if wantCues
                cueText = sprintf('cues at volume %g', soundCfg.volume);
            else
                cueText = 'no cues';
            end
            fprintf('Sound: %s, %s, %g Hz.\n', rainText, cueText, obj.fs);
        end

        function play(obj, name)
            %PLAY Start a cue without waiting for it; cut off a cue still playing.
            name = lower(string(name));
            if ~isscalar(name) || ~ismember(name, kidsSound.cueNames)
                error('rrst:badCue', 'Unknown cue sound "%s". Known: %s.', ...
                    strjoin(string(name), ''), strjoin(kidsSound.cueNames, ', '));
            end
            if ~obj.active
                return
            end
            try
                PsychPortAudio('Stop', obj.cue);
                PsychPortAudio('FillBuffer', obj.cue, obj.waves.(char(name)));
                PsychPortAudio('Start', obj.cue, 1, 0, 0);     % once, now, do not wait
            catch err
                obj.fail(err.message);
                obj.closeCue();
            end
        end

        function stop(obj)
            %STOP Stop the cue now. The rain keeps playing.
            if ~obj.active
                return
            end
            try
                PsychPortAudio('Stop', obj.cue);
            catch err
                obj.fail(err.message);
                obj.closeCue();
            end
        end

        function close(obj)
            %CLOSE Stop and close the cue, the rain and the master. Safe to repeat.
            obj.closeCue();
            obj.rain = closeDevice(obj.rain);
            obj.rainOn = false;
            obj.master = closeDevice(obj.master);
        end

        function delete(obj)
            obj.close();
        end
    end

    methods (Access = private)
        function closeCue(obj)
            obj.cue = closeDevice(obj.cue);
            obj.active = false;
        end

        function fail(obj, msg)
            if ~obj.warned
                warning('rrst:soundOff', 'Sound problem (%s). The task continues; %s.', ...
                    msg, ternary(obj.rainOn, 'cue sounds are off, the rain keeps playing', ...
                    'no sound (no rain masking, no cues)'));
                obj.warned = true;
            end
        end
    end
end

function h = closeDevice(h)
% Stop and close one PsychPortAudio handle, ignoring errors; returns [].
if isempty(h)
    return
end
try
    PsychPortAudio('Stop', h);
catch
end
try
    PsychPortAudio('Close', h);
catch
end
h = [];
end

function checkConfig(noiseCfg, soundCfg)
bad = @(msg, varargin) error('rrst:badConfig', ['Kids sound configuration: ' msg], varargin{:});
isFlag = @(v) isscalar(v) && (islogical(v) || isnumeric(v)) && ismember(v, [0 1]);
inUnit = @(v) isscalar(v) && isnumeric(v) && isreal(v) && v > 0 && v <= 1;
if ~isFlag(soundCfg.enabled)
    bad('sound.enabled must be true or false.');
end
if ~inUnit(soundCfg.volume)
    bad('sound.volume must be in (0, 1] (got %s).', mat2str(soundCfg.volume));
end
if ~(isscalar(soundCfg.fs) && isnumeric(soundCfg.fs) && isfinite(soundCfg.fs) && soundCfg.fs >= 8000)
    bad('sound.fs must be a sample rate of at least 8000 Hz (got %s).', mat2str(soundCfg.fs));
end
if ~isFlag(noiseCfg.enabled)
    bad('noise.enabled must be true or false.');
end
if noiseCfg.enabled
    if ~inUnit(noiseCfg.volume)
        bad('noise.volume must be in (0, 1] (got %s).', mat2str(noiseCfg.volume));
    end
    if ~(isfield(noiseCfg, 'file') && strlength(string(noiseCfg.file)) > 0)
        bad('noise.file must name the rain loop when noise.enabled is true.');
    end
end
end

function out = ternary(c, a, b)
if c, out = a; else, out = b; end
end
