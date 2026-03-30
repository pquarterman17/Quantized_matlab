%TEST_FILTERROWS  Unit tests for dataplotter.filterRows().
%
%   Run via: runAllTests(Group="gui")
%   Run standalone: cd tests; run gui/test_filterRows
%
%   Tests:
%     1.  Simple >  comparison
%     2.  Simple <  comparison
%     3.  Compound & (AND)
%     4.  Compound | (OR)
%     5.  between() function
%     6.  abs() function
%     7.  'x' token maps to .time
%     8.  Empty expression → all-true mask
%     9.  Invalid column name → error
%    10.  Case-insensitive exact match
%    11.  Partial / sub-word match  (e.g. "Temp" inside "Temperature (K)")
%    12.  ~= inequality operator
%    13.  NOT (~) prefix operator
%    14.  == equality operator
%    15.  Chained comparisons with parentheses

clear; clc;

% ── Path setup ───────────────────────────────────────────────────────────
thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(fileparts(thisDir));
if ~contains(path, rootDir)
    addpath(rootDir);
end

passed = 0;
failed = 0;

% ════════════════════════════════════════════════════════════════════════
%  Synthetic dataset
%   x     (time) : 1..10
%   col 1 Temp   : 100 200 300 400 500 600 700 800 900 1000
%   col 2 Field  : -4 -3 -2 -1 0 1 2 3 4 5
%   col 3 Moment : 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0
% ════════════════════════════════════════════════════════════════════════
N    = 10;
xVec = (1:N)';
vals = [(100:100:1000)', (-4:5)', (0.1:0.1:1.0)'];
d = parser.createDataStruct(xVec, vals, ...
    'labels', {'Temp', 'Field', 'Moment'}, ...
    'units',  {'K', 'Oe', 'emu'});

% ════════════════════════════════════════════════════════════════════════
%  TEST 1 — Simple > comparison
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 1: Simple > comparison ══\n');
try
    mask = dataplotter.filterRows(d, 'Temp > 500');
    expected = vals(:,1) > 500;
    assert(isequal(mask, expected), 'mask mismatch for Temp > 500');
    assert(sum(mask) == 5, sprintf('expected 5 passing rows, got %d', sum(mask)));
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  TEST 2 — Simple < comparison
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 2: Simple < comparison ══\n');
try
    mask = dataplotter.filterRows(d, 'Field < 0');
    expected = vals(:,2) < 0;
    assert(isequal(mask, expected), 'mask mismatch for Field < 0');
    assert(sum(mask) == 4, sprintf('expected 4 passing rows, got %d', sum(mask)));
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  TEST 3 — Compound & (AND)
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 3: Compound & (AND) ══\n');
try
    mask = dataplotter.filterRows(d, 'Temp > 200 & Field < 3');
    expected = (vals(:,1) > 200) & (vals(:,2) < 3);
    assert(isequal(mask, expected), 'mask mismatch for AND expression');
    fprintf('  Passing rows: %d (expected %d)\n', sum(mask), sum(expected));
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  TEST 4 — Compound | (OR)
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 4: Compound | (OR) ══\n');
try
    mask = dataplotter.filterRows(d, 'Temp < 200 | Temp > 900');
    expected = (vals(:,1) < 200) | (vals(:,1) > 900);
    assert(isequal(mask, expected), 'mask mismatch for OR expression');
    assert(sum(mask) == 2, sprintf('expected 2 passing rows, got %d', sum(mask)));
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  TEST 5 — between() function
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 5: between() function ══\n');
try
    mask = dataplotter.filterRows(d, 'between(Temp, 300, 700)');
    expected = (vals(:,1) >= 300) & (vals(:,1) <= 700);
    assert(isequal(mask, expected), 'mask mismatch for between(Temp,300,700)');
    assert(sum(mask) == 5, sprintf('expected 5 passing rows, got %d', sum(mask)));
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  TEST 6 — abs() function
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 6: abs() function ══\n');
try
    mask = dataplotter.filterRows(d, 'abs(Field) <= 2');
    expected = abs(vals(:,2)) <= 2;
    assert(isequal(mask, expected), 'mask mismatch for abs(Field) <= 2');
    assert(sum(mask) == 5, sprintf('expected 5 passing rows, got %d', sum(mask)));
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  TEST 7 — 'x' token maps to .time
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 7: ''x'' token → .time ══\n');
try
    mask = dataplotter.filterRows(d, 'x >= 5');
    expected = xVec >= 5;
    assert(isequal(mask, expected), 'mask mismatch for x >= 5');
    assert(sum(mask) == 6, sprintf('expected 6 passing rows, got %d', sum(mask)));
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  TEST 8 — Empty expression → all-true mask
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 8: Empty expression → all-true mask ══\n');
try
    mask = dataplotter.filterRows(d, '');
    assert(all(mask), 'empty expression should return all-true mask');
    assert(numel(mask) == N, sprintf('mask length should be %d, got %d', N, numel(mask)));
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  TEST 9 — Invalid column name → error
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 9: Invalid column name → error ══\n');
try
    didError = false;
    try
        dataplotter.filterRows(d, 'Nonexistent > 0'); %#ok<NASGU>
    catch
        didError = true;
    end
    assert(didError, 'expected an error for unknown column name');
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  TEST 10 — Case-insensitive exact match
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 10: Case-insensitive label match ══\n');
try
    maskLower = dataplotter.filterRows(d, 'temp > 500');
    maskUpper = dataplotter.filterRows(d, 'TEMP > 500');
    maskMixed = dataplotter.filterRows(d, 'Temp > 500');
    assert(isequal(maskLower, maskMixed), 'lower vs mixed case mismatch');
    assert(isequal(maskUpper, maskMixed), 'upper vs mixed case mismatch');
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  TEST 11 — Partial / sub-word match  (label contains longer string)
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 11: Partial (sub-word) label match ══\n');
try
    % Dataset with "Temperature (K)" label — token "temperature" should resolve
    dLong = parser.createDataStruct(xVec, vals, ...
        'labels', {'Temperature (K)', 'Field', 'Moment'}, ...
        'units',  {'K', 'Oe', 'emu'});
    mask = dataplotter.filterRows(dLong, 'Temperature > 500');
    expected = vals(:,1) > 500;
    assert(isequal(mask, expected), 'partial label match failed');
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  TEST 12 — ~= inequality operator
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 12: ~= inequality operator ══\n');
try
    mask = dataplotter.filterRows(d, 'Field ~= 0');
    expected = vals(:,2) ~= 0;
    assert(isequal(mask, expected), 'mask mismatch for Field ~= 0');
    assert(sum(mask) == 9, sprintf('expected 9 passing rows, got %d', sum(mask)));
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  TEST 13 — NOT (~) prefix operator
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 13: NOT (~) prefix operator ══\n');
try
    maskFilter  = dataplotter.filterRows(d, '~(Temp > 500)');
    maskExpected = ~(vals(:,1) > 500);
    assert(isequal(maskFilter, maskExpected), 'NOT operator produced wrong mask');
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  TEST 14 — == equality operator
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 14: == equality operator ══\n');
try
    mask = dataplotter.filterRows(d, 'Field == 0');
    expected = vals(:,2) == 0;
    assert(isequal(mask, expected), 'mask mismatch for Field == 0');
    assert(sum(mask) == 1, sprintf('expected 1 passing row, got %d', sum(mask)));
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  TEST 15 — Nested parentheses and chained operators
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 15: Nested parentheses and chained operators ══\n');
try
    mask = dataplotter.filterRows(d, '(Temp > 200 & Temp < 800) | Field == 5');
    expected = ((vals(:,1) > 200) & (vals(:,1) < 800)) | (vals(:,2) == 5);
    assert(isequal(mask, expected), 'mask mismatch for nested expression');
    fprintf('  Passing rows: %d (expected %d)\n', sum(mask), sum(expected));
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  Summary
% ════════════════════════════════════════════════════════════════════════
fprintf('\n════════════════════════════════════════\n');
fprintf('  filterRows tests: %d passed, %d failed\n', passed, failed);
fprintf('════════════════════════════════════════\n');

if failed > 0
    error('test_filterRows:failures', '%d test(s) failed.', failed);
end
