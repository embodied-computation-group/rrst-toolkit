% Run all tests from the repository root:  matlab -batch runTests
root = fileparts(mfilename('fullpath'));
addpath(fullfile(root, 'device'));
results = runtests(fullfile(root, 'tests'));
disp(table(results));
fprintf('%d passed, %d failed, %d incomplete\n', ...
    nnz([results.Passed]), nnz([results.Failed]), nnz([results.Incomplete]));
assertSuccess(results);
