function T = trialTable(Results)
%T = trialTable(Results)
%
% One row per trial: the Results fields that are column vectors with one value
% per trial (as long as Results.trialN). Rating matrices, scalars and the stair
% are left out; they are in the .mat file. ExpRateTask and ExpRareEnd are
% excluded by name, because with few trials they can have the same shape as a
% trial column.

notPerTrial = {'ExpRateTask', 'ExpRareEnd'};
n = numel(Results.trialN);
names = fieldnames(Results)';
keep = false(size(names));
for k = 1:numel(names)
    v = Results.(names{k});
    keep(k) = ~ismember(names{k}, notPerTrial) && (isnumeric(v) || islogical(v)) ...
        && iscolumn(v) && numel(v) == n;
end
T = struct2table(rmfield(Results, names(~keep)));
end
