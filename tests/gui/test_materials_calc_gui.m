%TEST_MATERIALS_CALC_GUI  Headless API tests for materialsCalcGUI.
%
%   Run:
%     run tests/test_materials_calc_gui

clear; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(fileparts(thisDir));
if ~contains(path, rootDir)
    addpath(rootDir);
end

fprintf('\n=== test_materials_calc_gui ===\n');
passed = 0;
failed = 0;

% ════════════════════════════════════════════════════════════════════
%  LAUNCH GUI
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- Launch ---\n');

api = materialsCalcGUI();

if isvalid(api.fig)
    fprintf('  PASS: GUI launched\n'); passed = passed + 1;
else
    fprintf('  FAIL: GUI not valid\n'); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  UNIT CONVERTER
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- Unit Converter ---\n');

% Basic conversion: 1 Oe -> T
result = api.convert(1, 'Oe', 'T');
val = str2double(result);
if abs(val - 1e-4) / 1e-4 < 1e-4
    fprintf('  PASS: 1 Oe -> 0.0001 T\n'); passed = passed + 1;
else
    fprintf('  FAIL: 1 Oe -> T (got %s)\n', result); failed = failed + 1;
end

% eV to nm
result = api.convert(1, 'eV', 'nm');
val = str2double(result);
if abs(val - 1239.84) / 1239.84 < 0.001
    fprintf('  PASS: 1 eV -> 1239.84 nm\n'); passed = passed + 1;
else
    fprintf('  FAIL: eV -> nm (got %s)\n', result); failed = failed + 1;
end

% Temperature
result = api.convert(0, 'C', 'K');
val = str2double(result);
if abs(val - 273.15) < 0.01
    fprintf('  PASS: 0 C -> 273.15 K\n'); passed = passed + 1;
else
    fprintf('  FAIL: C -> K (got %s)\n', result); failed = failed + 1;
end

% Compound units
result = api.convert(1, 'mA/cm^2', 'A/m^2');
val = str2double(result);
if abs(val - 10) < 0.001
    fprintf('  PASS: mA/cm^2 -> A/m^2\n'); passed = passed + 1;
else
    fprintf('  FAIL: mA/cm^2 -> A/m^2 (got %s)\n', result); failed = failed + 1;
end

% History populated
h = api.getHistory();
if numel(h) >= 4
    fprintf('  PASS: history has %d entries\n', numel(h)); passed = passed + 1;
else
    fprintf('  FAIL: history has %d entries (expected >=4)\n', numel(h)); failed = failed + 1;
end

% Status bar shows something
st = api.getStatus();
if ~isempty(st) && ~strcmp(st, 'Ready')
    fprintf('  PASS: status bar updated\n'); passed = passed + 1;
else
    fprintf('  FAIL: status bar not updated\n'); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  TAB SWITCHING
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- Tab Switching ---\n');

tabNames = {'unitConverter', 'crystal', 'electrical', 'semiconductor', 'thinFilm', 'periodicTable'};
allTabsOk = true;
for i = 1:numel(tabNames)
    try
        api.selectTab(tabNames{i});
    catch
        allTabsOk = false;
    end
end
if allTabsOk
    fprintf('  PASS: all 6 tabs selectable\n'); passed = passed + 1;
else
    fprintf('  FAIL: some tabs not selectable\n'); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  CRYSTAL TAB
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- Crystal Tab ---\n');

% d-spacing: SrTiO3 (001) -> d = 3.905
api.selectTab('crystal');
txt = api.calcDSpacing(3.905, 0, 0, 1);
if contains(txt, '3.905') || contains(txt, '3.9050')
    fprintf('  PASS: d-spacing STO(001) = 3.905\n'); passed = passed + 1;
else
    fprintf('  FAIL: d-spacing STO(001) (got: %s)\n', txt); failed = failed + 1;
end

% d-spacing: Si (111) -> d ~ 3.136
txt = api.calcDSpacing(5.431, 1, 1, 1);
if contains(txt, '3.13')
    fprintf('  PASS: d-spacing Si(111) ~ 3.136\n'); passed = passed + 1;
else
    fprintf('  FAIL: d-spacing Si(111) (got: %s)\n', txt); failed = failed + 1;
end

% Result label contains system name
if contains(txt, 'cubic')
    fprintf('  PASS: system identified as cubic\n'); passed = passed + 1;
else
    fprintf('  FAIL: system not identified (got: %s)\n', txt); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  SEMICONDUCTOR TAB
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- Semiconductor Tab ---\n');

% Intrinsic carrier concentration: Si
api.selectTab('semiconductor');
txt = api.calcIntrinsic('Si');
if contains(txt, 'n<sub>i</sub>') || contains(txt, 'ni')
    fprintf('  PASS: intrinsic calc runs for Si\n'); passed = passed + 1;
else
    fprintf('  FAIL: intrinsic calc for Si (got: %s)\n', txt); failed = failed + 1;
end

% Check ni value is in reasonable range (should contain e+09 or e+10)
if contains(txt, 'e+09') || contains(txt, 'e+10') || contains(txt, 'E+09') || contains(txt, 'E+10') || contains(txt, '8.88')
    fprintf('  PASS: Si ni ~ 1e10 range\n'); passed = passed + 1;
else
    fprintf('  FAIL: Si ni unexpected (got: %s)\n', txt); failed = failed + 1;
end

% GaAs
txt2 = api.calcIntrinsic('GaAs');
if contains(txt2, 'n<sub>i</sub>') || contains(txt2, 'ni')
    fprintf('  PASS: intrinsic calc runs for GaAs\n'); passed = passed + 1;
else
    fprintf('  FAIL: intrinsic calc for GaAs (got: %s)\n', txt2); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  PERIODIC TABLE
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- Periodic Table ---\n');

api.selectTab('periodicTable');

% Select Fe
api.selectElement('Fe');
detail = api.getElementDetail();
detailStr = strjoin(detail, ' ');

if contains(detailStr, 'Iron')
    fprintf('  PASS: Fe shows Iron\n'); passed = passed + 1;
else
    fprintf('  FAIL: Fe detail missing Iron\n'); failed = failed + 1;
end

if contains(detailStr, '55.845')
    fprintf('  PASS: Fe mass = 55.845\n'); passed = passed + 1;
else
    fprintf('  FAIL: Fe mass not shown\n'); failed = failed + 1;
end

if contains(detailStr, '26')
    fprintf('  PASS: Fe Z = 26\n'); passed = passed + 1;
else
    fprintf('  FAIL: Fe Z not shown\n'); failed = failed + 1;
end

% Select Si
api.selectElement('Si');
detail = api.getElementDetail();
detailStr = strjoin(detail, ' ');

if contains(detailStr, 'Silicon')
    fprintf('  PASS: Si shows Silicon\n'); passed = passed + 1;
else
    fprintf('  FAIL: Si detail missing Silicon\n'); failed = failed + 1;
end

% Select H (edge case: first element)
api.selectElement('H');
detail = api.getElementDetail();
detailStr = strjoin(detail, ' ');

if contains(detailStr, 'Hydrogen')
    fprintf('  PASS: H shows Hydrogen\n'); passed = passed + 1;
else
    fprintf('  FAIL: H detail missing\n'); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  PLANE SPACING TABLE
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- Plane Spacing Table ---\n');

api.selectTab('crystal');

% FCC Si: should have reflections
tbl = api.calcPlaneSpacings(5.431, 'F');
if ~isempty(tbl) && size(tbl, 1) > 0
    fprintf('  PASS: plane spacings returns data (%d rows)\n', size(tbl, 1)); passed = passed + 1;
else
    fprintf('  FAIL: plane spacings empty\n'); failed = failed + 1;
end

% Check (111) present in FCC results
found111 = false;
for ri = 1:size(tbl, 1)
    if tbl{ri,1} == 1 && tbl{ri,2} == 1 && tbl{ri,3} == 1
        found111 = true;
        break;
    end
end
if found111
    fprintf('  PASS: (111) found in FCC table\n'); passed = passed + 1;
else
    fprintf('  FAIL: (111) missing from FCC table\n'); failed = failed + 1;
end

% Check (100) absent in FCC
found100 = false;
for ri = 1:size(tbl, 1)
    if tbl{ri,1} == 1 && tbl{ri,2} == 0 && tbl{ri,3} == 0
        found100 = true;
        break;
    end
end
if ~found100
    fprintf('  PASS: (100) correctly absent in FCC\n'); passed = passed + 1;
else
    fprintf('  FAIL: (100) should be absent in FCC\n'); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  ERROR HANDLING
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- Error Handling ---\n');

% Invalid conversion should not crash
result = api.convert(1, 'm', 'kg');
if ischar(result) || isstring(result)
    fprintf('  PASS: bad conversion does not crash\n'); passed = passed + 1;
else
    fprintf('  FAIL: bad conversion crashed\n'); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  HISTORY TABLE & COPY-AS-MATLAB-CODE
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- History table / Copy as MATLAB code ---\n');

% History tab is selectable
try
    api.selectTab('history');
    fprintf('  PASS: history tab selectable\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: history tab not selectable (%s)\n', ME.message); failed = failed + 1;
end

% Unit converter stores a MATLAB call in history (already ran api.convert above)
api.selectTab('unitConverter');
api.convert(1, 'Oe', 'T');
h = api.getHistory();
if ~isempty(h)
    lastEntry = h{end};
    if numel(lastEntry) >= 5 && ~isempty(lastEntry{5})
        fprintf('  PASS: unit-converter history entry has MATLAB call\n'); passed = passed + 1;
    else
        fprintf('  FAIL: unit-converter history entry missing MATLAB call\n'); failed = failed + 1;
    end
else
    fprintf('  FAIL: history is empty after unit converter\n'); failed = failed + 1;
end

% Semiconductor intrinsic stores a MATLAB call
api.selectTab('semiconductor');
api.calcIntrinsic('Si');
h = api.getHistory();
lastEntry = h{end};
if numel(lastEntry) >= 5 && contains(lastEntry{5}, 'intrinsicCarrierConc')
    fprintf('  PASS: semiconductor intrinsic has MATLAB call\n'); passed = passed + 1;
else
    fprintf('  FAIL: semiconductor intrinsic missing MATLAB call (got: %s)\n', ...
        lastEntry{end}); failed = failed + 1;
end

% Crystal d-spacing stores a MATLAB call
api.selectTab('crystal');
api.calcDSpacing(3.905, 0, 0, 1);
h = api.getHistory();
lastEntry = h{end};
if numel(lastEntry) >= 5 && contains(lastEntry{5}, 'dSpacing')
    fprintf('  PASS: crystal d-spacing has MATLAB call\n'); passed = passed + 1;
else
    fprintf('  FAIL: crystal d-spacing missing MATLAB call (got: %s)\n', ...
        lastEntry{end}); failed = failed + 1;
end

% getHistoryMatlabCall returns the stored call string
nRows = numel(api.getHistory());
call = api.getHistoryMatlabCall(nRows);
if ischar(call) && ~isempty(call)
    fprintf('  PASS: getHistoryMatlabCall returns non-empty string\n'); passed = passed + 1;
else
    fprintf('  FAIL: getHistoryMatlabCall returned empty or non-char\n'); failed = failed + 1;
end

% copyHistoryRowAsMatlabCode returns the string and copies to clipboard
copied = api.copyHistoryRowAsMatlabCode(nRows);
if ischar(copied) && ~isempty(copied)
    fprintf('  PASS: copyHistoryRowAsMatlabCode returns non-empty string\n'); passed = passed + 1;
else
    fprintf('  FAIL: copyHistoryRowAsMatlabCode returned empty (row %d)\n', nRows); failed = failed + 1;
end

% Out-of-range row does not crash
try
    api.copyHistoryRowAsMatlabCode(99999);
    fprintf('  PASS: out-of-range row handled gracefully\n'); passed = passed + 1;
catch
    fprintf('  FAIL: out-of-range row threw error\n'); failed = failed + 1;
end

% History entry structure: {time, tabKey, description, latex, matlabCall}
h = api.getHistory();
if ~isempty(h)
    e = h{1};
    if numel(e) == 5 && ischar(e{1}) && ischar(e{2})
        fprintf('  PASS: history entry has 5-cell structure\n'); passed = passed + 1;
    else
        fprintf('  FAIL: history entry structure unexpected (numel=%d)\n', numel(e)); failed = failed + 1;
    end
end

% ════════════════════════════════════════════════════════════════════
%  CLEANUP
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- Cleanup ---\n');

api.close();
pause(0.1);

if ~isvalid(api.fig)
    fprintf('  PASS: GUI closed\n'); passed = passed + 1;
else
    fprintf('  FAIL: GUI still valid after close\n'); failed = failed + 1;
    delete(api.fig);
end

% ════════════════════════════════════════════════════════════════════
%  SUMMARY
% ════════════════════════════════════════════════════════════════════

fprintf('\n=== Results: %d passed, %d failed ===\n', passed, failed);
