function pa = startMaskingNoise(noiseCfg)
%pa = startMaskingNoise(noiseCfg)
%
% Start looped masking noise on the default audio device (Psychtoolbox
% PsychPortAudio, its own playback thread). The buffer comes from
% rrst.maskingNoise and loops without a click. Replaces playSound.m, which loaded
% a 60-minute wav file (several GB as doubles) and hard-coded audio device 4.

InitializePsychSound(1);
x = noiseCfg.volume * rrst.maskingNoise(noiseCfg.fs, noiseCfg.durS, noiseCfg.colour, 1);
pa = PsychPortAudio('Open', [], 1, 1, noiseCfg.fs, 2);
PsychPortAudio('FillBuffer', pa, [x'; x']);
PsychPortAudio('Start', pa, 0, 0, 1);      % 0 repetitions = loop until stopped
fprintf('Masking noise: %s, volume %g, %g s loop.\n', noiseCfg.colour, noiseCfg.volume, noiseCfg.durS);
end
