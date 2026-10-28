function isCatch = kidsSchedule(nPsi, nCatch, seed)
%KIDSSCHEDULE Positions of the catch trials among nPsi + nCatch trials.
%   isCatch = kidsSchedule(30, 10, seed)   logical row; a catch trial is never first
%   and never follows another catch trial. The same seed gives the same schedule.
if nCatch > nPsi
    error('rrst:badConfig', 'Cannot place %d catch trials among %d Psi trials without two in a row.', ...
        nCatch, nPsi);
end
rs = RandStream('mt19937ar', 'Seed', seed);
% Each catch trial goes right after a distinct Psi trial: no catch first, none adjacent.
after = sort(randperm(rs, nPsi, nCatch));
isCatch = false(1, nPsi + nCatch);
isCatch(after + (1:nCatch)) = true;
end
