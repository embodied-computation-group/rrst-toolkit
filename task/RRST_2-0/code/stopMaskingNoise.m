function stopMaskingNoise(pa)
%stopMaskingNoise(pa)   Stop and close the masking noise; does nothing if pa is empty.
if isempty(pa)
    return
end
PsychPortAudio('Stop', pa);
PsychPortAudio('Close', pa);
end
