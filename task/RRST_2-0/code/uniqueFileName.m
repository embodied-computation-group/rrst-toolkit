function name = uniqueFileName(folder, name)
%UNIQUEFILENAME A file name (without extension) that no .mat or .csv in folder uses yet.
%   name = uniqueFileName(folder, name)
%   Returns name unchanged if it is free, otherwise name_2, name_3, ...: two runs saved
%   in the same minute never overwrite each other.
base = name;
k = 1;
while isfile(fullfile(folder, [name, '.mat'])) || isfile(fullfile(folder, [name, '.csv']))
    k = k + 1;
    name = sprintf('%s_%d', base, k);
end
end
