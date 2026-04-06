%TEST_PHASE8_QOL  Tests for Phase 8 QoL features: composeFigure, actionLog,
%   surface3D, datasetGroups.
%
%   Run:
%     run tests/fitting/test_phase8_qol
%     runAllTests(Group="fitting")

clear; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(fileparts(thisDir));
if ~contains(path, rootDir)
    addpath(rootDir);
end

fprintf('\n=== test_phase8_qol ===\n');
passed = 0;
failed = 0;

% Synthetic data
x = linspace(0, 10, 100)';
d1 = struct('time', x, 'values', sin(x), 'labels', {{'sin'}}, ...
    'units', {{''}}, 'metadata', struct());
d2 = struct('time', x, 'values', cos(x), 'labels', {{'cos'}}, ...
    'units', {{''}}, 'metadata', struct());

% ════════════════════════════════════════════════════════════════════
%  FIGURE COMPOSER
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- plotting.composeFigure ---\n');

% Basic compose from data structs
r = plotting.composeFigure({d1, d2}, Layout=[1 2]);
if r.nPanels == 2 && isvalid(r.fig)
    fprintf('  PASS: 1x2 composition created\n'); passed = passed + 1;
else
    fprintf('  FAIL: 1x2 composition\n'); failed = failed + 1;
end
close(r.fig);

% 2x2 with {x,y} pairs
r = plotting.composeFigure({{x,sin(x)}, {x,cos(x)}, {x,exp(-x)}, {x,x.^2}}, ...
    Layout=[2 2], Labels='abc');
if r.nPanels == 4
    fprintf('  PASS: 2x2 composition with {x,y} pairs\n'); passed = passed + 1;
else
    fprintf('  FAIL: 2x2 composition\n'); failed = failed + 1;
end
% Check panel labels
txt = findobj(r.axes(1), 'Type', 'Text');
hasLabel = false;
for ti = 1:numel(txt)
    if contains(txt(ti).String, '(a)'), hasLabel = true; end
end
if hasLabel
    fprintf('  PASS: panel labels present\n'); passed = passed + 1;
else
    fprintf('  FAIL: panel labels missing\n'); failed = failed + 1;
end
close(r.fig);

% With annotations
ann = {struct('panel', 1, 'text', 'Peak', 'position', [0.5 0.8])};
r = plotting.composeFigure({d1}, Annotations=ann);
if isvalid(r.fig)
    fprintf('  PASS: annotation added\n'); passed = passed + 1;
else
    fprintf('  FAIL: annotation\n'); failed = failed + 1;
end
close(r.fig);

% With template
r = plotting.composeFigure({d1}, Template='aps');
if r.axes(1).FontSize == 9
    fprintf('  PASS: APS template applied\n'); passed = passed + 1;
else
    fprintf('  FAIL: template\n'); failed = failed + 1;
end
close(r.fig);

% Panel titles
r = plotting.composeFigure({d1, d2}, Layout=[1 2], ...
    PanelTitles={{'Panel A'}, {'Panel B'}});
if strcmp(r.axes(1).Title.String, 'Panel A')
    fprintf('  PASS: panel titles set\n'); passed = passed + 1;
else
    fprintf('  FAIL: panel titles\n'); failed = failed + 1;
end
close(r.fig);

% Auto layout
r = plotting.composeFigure({d1, d2, d1, d2});
if r.nPanels == 4
    fprintf('  PASS: auto layout selects 2x2 for 4 sources\n'); passed = passed + 1;
else
    fprintf('  FAIL: auto layout\n'); failed = failed + 1;
end
close(r.fig);

% ════════════════════════════════════════════════════════════════════
%  ACTION LOG
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- boson.actionLog ---\n');

log = boson.actionLog();

% Empty log
if log.nEntries() == 0
    fprintf('  PASS: new log is empty\n'); passed = passed + 1;
else
    fprintf('  FAIL: new log has %d entries\n', log.nEntries()); failed = failed + 1;
end

% Record commands
log.record("d = parser.importAuto('file.dat');");
log.record("d.corrData = utilities.smoothData(d.data.time, d.data.values, 5);");
log.record("plotting.saveFigure(gcf, 'output.pdf');");

if log.nEntries() == 3
    fprintf('  PASS: 3 commands recorded\n'); passed = passed + 1;
else
    fprintf('  FAIL: %d entries (exp 3)\n', log.nEntries()); failed = failed + 1;
end

% Get log
cmds = log.getLog();
if numel(cmds) == 3 && contains(cmds{1}, 'importAuto')
    fprintf('  PASS: getLog returns correct commands\n'); passed = passed + 1;
else
    fprintf('  FAIL: getLog\n'); failed = failed + 1;
end

% Undo
log.undo();
if log.nEntries() == 2
    fprintf('  PASS: undo removes last command\n'); passed = passed + 1;
else
    fprintf('  FAIL: undo — %d entries (exp 2)\n', log.nEntries()); failed = failed + 1;
end

% Get script
txt = log.getScript();
if contains(txt, 'setupToolbox') && contains(txt, 'importAuto')
    fprintf('  PASS: getScript contains setupToolbox and commands\n'); passed = passed + 1;
else
    fprintf('  FAIL: getScript content\n'); failed = failed + 1;
end

% Export script
tmpFile = fullfile(tempdir, 'test_actionlog_export.m');
log.exportScript(tmpFile);
if exist(tmpFile, 'file')
    content = fileread(tmpFile);
    delete(tmpFile);
    if contains(content, 'importAuto')
        fprintf('  PASS: exportScript writes valid file\n'); passed = passed + 1;
    else
        fprintf('  FAIL: exported file content\n'); failed = failed + 1;
    end
else
    fprintf('  FAIL: exportScript did not create file\n'); failed = failed + 1;
end

% Clear
log.clear();
if log.nEntries() == 0
    fprintf('  PASS: clear empties the log\n'); passed = passed + 1;
else
    fprintf('  FAIL: clear — %d entries\n', log.nEntries()); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  3D SURFACE PLOTS
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- plotting.surface3D ---\n');

% Plain matrix
Z = peaks(50);
r = plotting.surface3D(Z);
if isvalid(r.fig) && isvalid(r.surf)
    fprintf('  PASS: surface from matrix\n'); passed = passed + 1;
else
    fprintf('  FAIL: surface from matrix\n'); failed = failed + 1;
end
close(r.fig);

% Struct with X, Y, Z
[Xg, Yg] = meshgrid(linspace(-3,3,50));
Zg = sin(Xg) .* cos(Yg);
r = plotting.surface3D(struct('X',Xg,'Y',Yg,'Z',Zg), Style='mesh');
if isvalid(r.fig)
    fprintf('  PASS: mesh from XYZ struct\n'); passed = passed + 1;
else
    fprintf('  FAIL: mesh from XYZ struct\n'); failed = failed + 1;
end
close(r.fig);

% Contour3
r = plotting.surface3D(Z, Style='contour3');
if isvalid(r.fig)
    fprintf('  PASS: contour3 style\n'); passed = passed + 1;
else
    fprintf('  FAIL: contour3\n'); failed = failed + 1;
end
close(r.fig);

% Log scale
r = plotting.surface3D(abs(Z) + 1, LogScale=true);
if isvalid(r.fig)
    fprintf('  PASS: log scale surface\n'); passed = passed + 1;
else
    fprintf('  FAIL: log scale\n'); failed = failed + 1;
end
close(r.fig);

% Custom labels and title
r = plotting.surface3D(Z, XLabel='2theta', YLabel='chi', Title='RSM');
if strcmp(r.ax.XLabel.String, '2theta') && strcmp(r.ax.Title.String, 'RSM')
    fprintf('  PASS: custom labels and title\n'); passed = passed + 1;
else
    fprintf('  FAIL: labels/title\n'); failed = failed + 1;
end
close(r.fig);

% All styles work without error
stylesOk = true;
for st = ["surface", "mesh", "contour3", "waterfall3"]
    try
        r = plotting.surface3D(Z, Style=st);
        close(r.fig);
    catch
        stylesOk = false;
    end
end
if stylesOk
    fprintf('  PASS: all 4 styles work\n'); passed = passed + 1;
else
    fprintf('  FAIL: some styles failed\n'); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  DATASET GROUPS
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- boson.datasetGroups ---\n');

grp = boson.datasetGroups();

% Empty
if grp.nGroups() == 0
    fprintf('  PASS: new groups object is empty\n'); passed = passed + 1;
else
    fprintf('  FAIL: not empty\n'); failed = failed + 1;
end

% Create groups
grp.createGroup('Temperature', [1 2 3]);
grp.createGroup('Field', [4 5]);

if grp.nGroups() == 2
    fprintf('  PASS: 2 groups created\n'); passed = passed + 1;
else
    fprintf('  FAIL: %d groups\n', grp.nGroups()); failed = failed + 1;
end

% Get group
idx = grp.getGroup('Temperature');
if isequal(idx, [1 2 3])
    fprintf('  PASS: getGroup returns [1 2 3]\n'); passed = passed + 1;
else
    fprintf('  FAIL: getGroup = [%s]\n', num2str(idx)); failed = failed + 1;
end

% Add to group
grp.addToGroup('Temperature', [4 5]);
idx = grp.getGroup('Temperature');
if isequal(idx, [1 2 3 4 5])
    fprintf('  PASS: addToGroup works\n'); passed = passed + 1;
else
    fprintf('  FAIL: addToGroup result = [%s]\n', num2str(idx)); failed = failed + 1;
end

% Remove from group
grp.removeFromGroup('Temperature', [4 5]);
idx = grp.getGroup('Temperature');
if isequal(idx, [1 2 3])
    fprintf('  PASS: removeFromGroup works\n'); passed = passed + 1;
else
    fprintf('  FAIL: removeFromGroup\n'); failed = failed + 1;
end

% Rename
grp.renameGroup('Field', 'Magnetic Field');
if grp.hasGroup('Magnetic Field') && ~grp.hasGroup('Field')
    fprintf('  PASS: renameGroup works\n'); passed = passed + 1;
else
    fprintf('  FAIL: renameGroup\n'); failed = failed + 1;
end

% getGroupNames
names = grp.getGroupNames();
if isequal(names, {'Temperature', 'Magnetic Field'})
    fprintf('  PASS: getGroupNames returns correct order\n'); passed = passed + 1;
else
    fprintf('  FAIL: getGroupNames = {%s}\n', strjoin(names, ', ')); failed = failed + 1;
end

% Delete group
grp.deleteGroup('Magnetic Field');
if grp.nGroups() == 1 && ~grp.hasGroup('Magnetic Field')
    fprintf('  PASS: deleteGroup works\n'); passed = passed + 1;
else
    fprintf('  FAIL: deleteGroup\n'); failed = failed + 1;
end

% Duplicate name error
try
    grp.createGroup('Temperature');
    fprintf('  FAIL: duplicate name should error\n'); failed = failed + 1;
catch
    fprintf('  PASS: duplicate name throws error\n'); passed = passed + 1;
end

% Not found error
try
    grp.getGroup('Nonexistent');
    fprintf('  FAIL: nonexistent group should error\n'); failed = failed + 1;
catch
    fprintf('  PASS: nonexistent group throws error\n'); passed = passed + 1;
end

% toStruct / fromStruct round-trip
grp.createGroup('XRD', [10 11 12]);
s = grp.toStruct();
grp2 = boson.datasetGroups();
grp2.fromStruct(s);
if grp2.nGroups() == 2 && isequal(grp2.getGroup('XRD'), [10 11 12])
    fprintf('  PASS: toStruct/fromStruct round-trip\n'); passed = passed + 1;
else
    fprintf('  FAIL: serialisation round-trip\n'); failed = failed + 1;
end

% getAll
all = grp.getAll();
if numel(all) == 2 && strcmp(all(1).name, 'Temperature')
    fprintf('  PASS: getAll returns struct array\n'); passed = passed + 1;
else
    fprintf('  FAIL: getAll\n'); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  SUMMARY
% ════════════════════════════════════════════════════════════════════

fprintf('\n=== test_phase8_qol: %d passed, %d failed ===\n\n', passed, failed);
if failed > 0
    error('test_phase8_qol:failures', '%d test(s) failed.', failed);
end
