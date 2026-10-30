classdef TestKidsSound < matlab.unittest.TestCase
    % RRST-Kids cue sounds: the generated waveforms (kidsCueWave) and the
    % kidsSound player when sound is off. Only liveMasterSlavePlaysReady opens the
    % sound card; it skips when PsychPortAudio or the audio device is not available.

    properties (TestParameter)
        cue = struct('ready', {{'ready', 0.4}}, 'slurp', {{'slurp', 0.6}}, ...
            'bubbles', {{'bubbles', 0.8}}, 'star', {{'star', 0.5}}, 'cup', {{'cup', 1.2}}, ...
            'mouse', {{'mouse', 0.8}}, 'tryagain', {{'tryagain', 0.5}});
        fs = {44100, 48000};
    end

    methods (TestClassSetup)
        function addKidsPath(tc)
            root = fileparts(fileparts(mfilename('fullpath')));
            p = [fullfile(root, 'task', 'RRST_kids', {'config', 'code'}), {fullfile(root, 'device')}];
            addpath(p{:});
            tc.addTeardown(@() rmpath(p{:}));
        end
    end

    methods (Test)
        % --- kidsCueWave ------------------------------------------------------
        function cueIsStereoAtTheRequestedRate(tc, cue, fs)
            x = kidsCueWave(cue{1}, fs);
            tc.verifyClass(x, 'double');
            tc.verifyTrue(ismatrix(x));
            tc.verifyEqual(size(x, 2), 2);
            tc.verifyEqual(size(x, 1) / fs, cue{2}, 'RelTol', 0.2, ...
                sprintf('%s should last about %g s', cue{1}, cue{2}));
        end

        function cueIsNormalisedAndInRange(tc, cue)
            x = kidsCueWave(cue{1}, 48000);
            tc.verifyTrue(all(isfinite(x(:))));
            tc.verifyLessThanOrEqual(max(abs(x(:))), 1);
            tc.verifyGreaterThanOrEqual(max(abs(x(:))), 0.85);
            tc.verifyLessThanOrEqual(max(abs(x(:))), 0.95);
        end

        function cueStartsAndEndsWithoutAClick(tc, cue, fs)
            x = kidsCueWave(cue{1}, fs);
            n = round(0.005 * fs);
            tc.verifyLessThan(max(abs(x(1:n, :)), [], 'all'), 0.05, 'onset click');
            tc.verifyLessThan(max(abs(x(end-n+1:end, :)), [], 'all'), 0.05, 'offset click');
        end

        function cueIsNotSilentInTheMiddle(tc, cue)
            % the normalisation must not come from a single spike: some energy throughout
            x = kidsCueWave(cue{1}, 48000);
            tc.verifyGreaterThan(sqrt(mean(x(:, 1) .^ 2)), 0.05);
        end

        function cueIsDeterministic(tc, cue)
            % the same sound every session, and the global random stream is untouched
            rng(7); before = rand;
            rng(7); a = kidsCueWave(cue{1}, 48000); after = rand;
            b = kidsCueWave(cue{1}, 48000);
            tc.verifyEqual(a, b);
            tc.verifyEqual(after, before);
        end

        function cueNamesAreCaseInsensitiveStrings(tc)
            tc.verifyEqual(kidsCueWave("Ready", 48000), kidsCueWave('ready', 48000));
        end

        function unknownCueIsAnError(tc)
            tc.verifyError(@() kidsCueWave('ding', 48000), 'rrst:badCue');
            tc.verifyError(@() kidsCueWave('', 48000), 'rrst:badCue');
        end

        function tryAgainFallsBySmallInterval(tc)
            % neutral, never "sad": two notes, the second a little lower (at most
            % a whole tone), not a dramatic drop
            fsx = 48000;
            x = kidsCueWave('tryagain', fsx);
            n = size(x, 1);
            f1 = dominantFrequency(x(round(0.05 * n):round(0.40 * n), 1), fsx);
            f2 = dominantFrequency(x(round(0.60 * n):round(0.95 * n), 1), fsx);
            semitones = 12 * log2(f1 / f2);
            tc.verifyGreaterThan(semitones, 0.5, 'second note should be lower');
            tc.verifyLessThanOrEqual(semitones, 2.5, 'fall should be at most a whole tone');
        end

        function readyRises(tc)
            fsx = 48000;
            x = kidsCueWave('ready', fsx);
            n = size(x, 1);
            f1 = dominantFrequency(x(round(0.05 * n):round(0.35 * n), 1), fsx);
            f2 = dominantFrequency(x(round(0.55 * n):round(0.95 * n), 1), fsx);
            tc.verifyGreaterThan(f2, f1);
        end

        % --- kidsSound without a sound card -----------------------------------
        function disabledSoundIsASilentNoOp(tc)
            cfg = kidsConfig();
            cfg.sound.enabled = false;
            cfg.noise.enabled = false;
            snd = tc.verifyWarningFree(@() kidsSound(cfg.noise, cfg.sound));
            tc.verifyFalse(snd.active);
            tc.verifyWarningFree(@() snd.play('ready'));
            tc.verifyWarningFree(@() snd.play('tryagain'));
            tc.verifyWarningFree(@() snd.stop());
            tc.verifyWarningFree(@() snd.close());
            tc.verifyFalse(snd.active);
            snd.close();                              % twice is fine
            delete(snd);
        end

        function playRejectsAnUnknownCueEvenWhenSilent(tc)
            % a typo in the task code must show up on a test machine, not only on the rig
            cfg = kidsConfig();
            cfg.sound.enabled = false;
            cfg.noise.enabled = false;
            snd = kidsSound(cfg.noise, cfg.sound);
            tc.verifyError(@() snd.play('ding'), 'rrst:badCue');
        end

        function configHasSoundDefaults(tc)
            cfg = kidsConfig();
            tc.verifyTrue(cfg.sound.enabled);
            tc.verifyEqual(cfg.sound.volume, 0.8);
            tc.verifyEqual(cfg.sound.fs, 48000);
            validateKidsConfig(cfg);
        end

        function volumeOutsideZeroToOneIsRejected(tc)
            cfg = kidsConfig();
            cfg.noise.enabled = false;
            for v = {0, -0.1, 1.01, 2, [0.5 0.5], NaN}
                cfg.sound.volume = v{1};
                tc.verifyError(@() kidsSound(cfg.noise, cfg.sound), 'rrst:badConfig', ...
                    sprintf('volume %s', mat2str(v{1})));
            end
            cfg.sound.volume = 1;                     % the upper bound is allowed
            cfg.sound.enabled = false;
            snd = kidsSound(cfg.noise, cfg.sound);
            tc.verifyFalse(snd.active);
        end

        function badSampleRateIsRejected(tc)
            cfg = kidsConfig();
            cfg.noise.enabled = false;
            cfg.sound.enabled = false;
            cfg.sound.fs = 0;
            tc.verifyError(@() kidsSound(cfg.noise, cfg.sound), 'rrst:badConfig');
        end

        % --- kidsSound on this machine's sound card ---------------------------
        function liveMasterSlavePlaysReady(tc)
            tc.assumeEqual(exist('PsychPortAudio', 'file'), 3, 'PsychPortAudio is not available.');
            cfg = kidsConfig();                       % rain on, cues on
            snd = kidsSound(cfg.noise, cfg.sound);
            tc.addTeardown(@() delete(snd));
            if ~snd.active
                tc.assumeFail('The audio device could not be opened (busy or missing).');
            end
            tc.verifyTrue(snd.rainOn);
            snd.play('ready');
            WaitSecs(0.5);
            snd.play('star');
            snd.play('tryagain');                     % interrupts the star
            WaitSecs(0.6);
            snd.stop();
            snd.close();
            tc.verifyFalse(snd.active);
            tc.verifyFalse(snd.rainOn);
        end
    end
end

function f = dominantFrequency(x, fs)
n = 2 ^ nextpow2(8 * numel(x));
X = abs(fft(x .* hann(numel(x)), n));
[~, k] = max(X(1:n/2));
f = (k - 1) * fs / n;
end

function w = hann(n)
w = 0.5 - 0.5 * cos(2 * pi * (0:n-1)' / (n - 1));
end
