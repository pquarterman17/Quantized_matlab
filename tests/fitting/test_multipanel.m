%TEST_MULTIPANEL  Tests for multi-panel figure builder (+bosonPlotter/multiPanel).
%
%   Run:
%     run tests/fitting/test_multipanel
%     runAllTests(Group="fitting")

clear; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(fileparts(thisDir));
if ~contains(path, rootDir)
    addpath(rootDir);
end

fprintf('\n=== test_multipanel ===\n');
passed = 0;
failed = 0;

% Create synthetic datasets
x = linspace(0, 10, 100)';
d1 = struct('time', x, 'values', sin(x), 'labels', {{'sin'}}, ...
    'units', {{''}}, 'metadata', struct());
d2 = struct('time', x, 'values', cos(x), 'labels', {{'cos'}}, ...
    'units', {{''}}, 'metadata', struct());
d3 = struct('time', x, 'values', exp(-x/3), 'labels', {{'exp decay'}}, ...
    'units', {{''}}, 'metadata', struct());
d4 = struct('time', x, 'values', x.^2, 'labels', {{'quadratic'}}, ...
    'units', {{''}}, 'metadata', struct());

% ════════════════════════════════════════════════════════════════════
%  LAYOUT TESTS
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- Layout creation ---\n');

% 1x1 layout
r = bosonPlotter.multiPanel({d1}, Layout='1x1');
if strcmp(r.layout, '1x1') && r.nPanels == 1 && isvalid(r.fig)
    fprintf('  PASS: 1x1 layout created\n'); passed = passed + 1;
else
    fprintf('  FAIL: 1x1 layout\n'); failed = failed + 1;
end
close(r.fig);

% 2x1 layout
r = bosonPlotter.multiPanel({d1, d2}, Layout='2x1');
if strcmp(r.layout, '2x1') && r.nPanels == 2 && numel(r.axes) == 2
    fprintf('  PASS: 2x1 layout created with 2 panels\n'); passed = passed + 1;
else
    fprintf('  FAIL: 2x1 layout\n'); failed = failed + 1;
end
close(r.fig);

% 1x2 layout
r = bosonPlotter.multiPanel({d1, d2}, Layout='1x2');
if strcmp(r.layout, '1x2') && r.nPanels == 2
    fprintf('  PASS: 1x2 layout created\n'); passed = passed + 1;
else
    fprintf('  FAIL: 1x2 layout\n'); failed = failed + 1;
end
close(r.fig);

% 2x2 layout
r = bosonPlotter.multiPanel({d1, d2, d3, d4}, Layout='2x2');
if strcmp(r.layout, '2x2') && r.nPanels == 4 && numel(r.axes) == 4
    fprintf('  PASS: 2x2 layout created with 4 panels\n'); passed = passed + 1;
else
    fprintf('  FAIL: 2x2 layout\n'); failed = failed + 1;
end
close(r.fig);

% 3x1 layout
r = bosonPlotter.multiPanel({d1, d2, d3}, Layout='3x1');
if strcmp(r.layout, '3x1') && r.nPanels == 3
    fprintf('  PASS: 3x1 layout created\n'); passed = passed + 1;
else
    fprintf('  FAIL: 3x1 layout\n'); failed = failed + 1;
end
close(r.fig);

% Auto-layout selection
r = bosonPlotter.multiPanel({d1});
if strcmp(r.layout, '1x1')
    fprintf('  PASS: auto-layout selects 1x1 for 1 dataset\n'); passed = passed + 1;
else
    fprintf('  FAIL: auto-layout for 1 dataset: %s\n', r.layout); failed = failed + 1;
end
close(r.fig);

r = bosonPlotter.multiPanel({d1, d2});
if strcmp(r.layout, '2x1')
    fprintf('  PASS: auto-layout selects 2x1 for 2 datasets\n'); passed = passed + 1;
else
    fprintf('  FAIL: auto-layout for 2 datasets: %s\n', r.layout); failed = failed + 1;
end
close(r.fig);

% ════════════════════════════════════════════════════════════════════
%  FEATURE TESTS
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- Features ---\n');

% Panel labels
r = bosonPlotter.multiPanel({d1, d2}, Layout='2x1', Labels='abc');
% Check that text objects exist on the axes
txt1 = findobj(r.axes(1), 'Type', 'Text');
hasLabel = false;
for ti = 1:numel(txt1)
    if contains(txt1(ti).String, '(a)')
        hasLabel = true;
    end
end
if hasLabel
    fprintf('  PASS: panel label (a) present\n'); passed = passed + 1;
else
    fprintf('  FAIL: panel label (a) not found\n'); failed = failed + 1;
end
close(r.fig);

% No labels
r = bosonPlotter.multiPanel({d1, d2}, Layout='2x1', Labels='none');
txt1 = findobj(r.axes(1), 'Type', 'Text');
noLabel = true;
for ti = 1:numel(txt1)
    if contains(txt1(ti).String, '(')
        noLabel = false;
    end
end
if noLabel
    fprintf('  PASS: Labels=none produces no panel labels\n'); passed = passed + 1;
else
    fprintf('  FAIL: Labels=none still has labels\n'); failed = failed + 1;
end
close(r.fig);

% Template application
r = bosonPlotter.multiPanel({d1}, Layout='1x1', Template='aps');
if r.axes(1).FontSize == 9 && strcmp(r.axes(1).FontName, 'Helvetica')
    fprintf('  PASS: APS template applied (9pt Helvetica)\n'); passed = passed + 1;
else
    fprintf('  FAIL: template not applied: %dpt %s\n', ...
        r.axes(1).FontSize, r.axes(1).FontName); failed = failed + 1;
end
close(r.fig);

% {x, y} pair input
r = bosonPlotter.multiPanel({{x, sin(x)}}, Layout='1x1');
lines = findobj(r.axes(1), 'Type', 'Line');
if ~isempty(lines)
    fprintf('  PASS: {x,y} pair input works\n'); passed = passed + 1;
else
    fprintf('  FAIL: {x,y} pair not plotted\n'); failed = failed + 1;
end
close(r.fig);

% Plot styles
for st = ["line", "scatter", "both"]
    r = bosonPlotter.multiPanel({d1}, PlotStyle=st);
    lines = findobj(r.axes(1), 'Type', 'Line');
    if ~isempty(lines)
        fprintf('  PASS: PlotStyle="%s" works\n', st); passed = passed + 1;
    else
        fprintf('  FAIL: PlotStyle="%s"\n', st); failed = failed + 1;
    end
    close(r.fig);
end

% Fewer datasets than panels
r = bosonPlotter.multiPanel({d1}, Layout='2x2');
if r.nPanels == 4 && isvalid(r.fig)
    fprintf('  PASS: 1 dataset in 2x2 layout — extra panels empty\n'); passed = passed + 1;
else
    fprintf('  FAIL: fewer datasets than panels\n'); failed = failed + 1;
end
close(r.fig);

% Residuals mode (2x1r)
yFit = sin(x) + 0.1*randn(size(x));
r = bosonPlotter.multiPanel({d1}, Layout='2x1r', ...
    Residuals=struct('yFit', yFit), YLabels={{'sin'}, {'Residual'}});
if r.nPanels == 2
    % Check bottom panel has data (residuals)
    lines2 = findobj(r.axes(2), 'Type', 'Line');
    if ~isempty(lines2)
        fprintf('  PASS: 2x1r residuals mode works\n'); passed = passed + 1;
    else
        fprintf('  FAIL: residuals panel empty\n'); failed = failed + 1;
    end
else
    fprintf('  FAIL: 2x1r layout\n'); failed = failed + 1;
end
close(r.fig);

% Custom axis labels
r = bosonPlotter.multiPanel({d1, d2}, Layout='2x1', ...
    XLabel='Time (s)', YLabels={{'Signal A'}, {'Signal B'}});
if strcmp(r.axes(2).XLabel.String, 'Time (s)')
    fprintf('  PASS: custom X label on bottom panel\n'); passed = passed + 1;
else
    fprintf('  FAIL: X label = "%s"\n', r.axes(2).XLabel.String); failed = failed + 1;
end
close(r.fig);

% Figure size
r = bosonPlotter.multiPanel({d1}, FigureSize=[20 15]);
figPos = r.fig.Position;
expectedW = 20 * 96/2.54;
if abs(figPos(3) - expectedW) < 5
    fprintf('  PASS: custom figure size applied\n'); passed = passed + 1;
else
    fprintf('  FAIL: figure width = %.0f (exp %.0f)\n', figPos(3), expectedW); failed = failed + 1;
end
close(r.fig);

% ════════════════════════════════════════════════════════════════════
%  SUMMARY
% ════════════════════════════════════════════════════════════════════

fprintf('\n=== test_multipanel: %d passed, %d failed ===\n\n', passed, failed);
if failed > 0
    error('test_multipanel:failures', '%d test(s) failed.', failed);
end
