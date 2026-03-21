%TEST_POLAR  Tests for polar plots (+plotting/polarPlot).
%
%   Run:
%     run tests/fitting/test_polar
%     runAllTests(Group="fitting")

clear; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(fileparts(thisDir));
if ~contains(path, rootDir)
    addpath(rootDir);
end

fprintf('\n=== test_polar ===\n');
passed = 0;
failed = 0;

% ════════════════════════════════════════════════════════════════════
%  POLAR PLOT
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- plotting.polarPlot ---\n');

theta = (0:5:355)';
r_4fold = abs(cosd(2*theta));  % 4-fold symmetry

% Test 1: Basic polar plot
result = plotting.polarPlot(theta, r_4fold);
if isvalid(result.fig) && isvalid(result.ax)
    fprintf('  PASS: basic polar plot created\n'); passed = passed + 1;
else
    fprintf('  FAIL: basic polar plot\n'); failed = failed + 1;
end
close(result.fig);

% Test 2: Line style
result = plotting.polarPlot(theta, r_4fold, Style='line');
lines = findobj(result.ax, 'Type', 'Line');
if ~isempty(lines)
    fprintf('  PASS: line style works\n'); passed = passed + 1;
else
    fprintf('  FAIL: line style\n'); failed = failed + 1;
end
close(result.fig);

% Test 3: Scatter style
result = plotting.polarPlot(theta, r_4fold, Style='scatter');
if isvalid(result.fig)
    fprintf('  PASS: scatter style works\n'); passed = passed + 1;
else
    fprintf('  FAIL: scatter style\n'); failed = failed + 1;
end
close(result.fig);

% Test 4: Stem style
result = plotting.polarPlot(theta, r_4fold, Style='stem');
if isvalid(result.fig)
    fprintf('  PASS: stem style works\n'); passed = passed + 1;
else
    fprintf('  FAIL: stem style\n'); failed = failed + 1;
end
close(result.fig);

% Test 5: Multiple datasets
r_2fold = abs(cosd(theta));
result = plotting.polarPlot(theta, [r_4fold, r_2fold], ...
    Labels={'4-fold', '2-fold'});
if numel(result.lines) == 2
    fprintf('  PASS: multi-dataset (%d lines)\n', numel(result.lines)); passed = passed + 1;
else
    fprintf('  FAIL: multi-dataset\n'); failed = failed + 1;
end
close(result.fig);

% Test 6: Symmetric (mirror half-scan)
theta_half = (0:5:175)';
r_half = abs(cosd(2*theta_half));
result = plotting.polarPlot(theta_half, r_half, Symmetric=true);
if isvalid(result.fig)
    fprintf('  PASS: symmetric mode works\n'); passed = passed + 1;
else
    fprintf('  FAIL: symmetric mode\n'); failed = failed + 1;
end
close(result.fig);

% Test 7: Normalize
result = plotting.polarPlot(theta, r_4fold * 1e6, Normalize=true);
if isvalid(result.fig)
    fprintf('  PASS: normalize mode works\n'); passed = passed + 1;
else
    fprintf('  FAIL: normalize\n'); failed = failed + 1;
end
close(result.fig);

% Test 8: Template application
result = plotting.polarPlot(theta, r_4fold, Template='aps');
if result.ax.FontSize == 9
    fprintf('  PASS: APS template applied\n'); passed = passed + 1;
else
    fprintf('  FAIL: template\n'); failed = failed + 1;
end
close(result.fig);

% Test 9: Title and R-label
result = plotting.polarPlot(theta, r_4fold, ...
    Title='Phi Scan', RLabel='Intensity (cps)');
if contains(result.ax.Title.String, 'Phi Scan')
    fprintf('  PASS: title and label set\n'); passed = passed + 1;
else
    fprintf('  FAIL: title/label\n'); failed = failed + 1;
end
close(result.fig);

% Test 10: ThetaZero and ThetaDir
result = plotting.polarPlot(theta, r_4fold, ...
    ThetaZero='right', ThetaDir='clockwise');
if strcmp(result.ax.ThetaZeroLocation, 'right') && ...
   strcmp(result.ax.ThetaDir, 'clockwise')
    fprintf('  PASS: ThetaZero=right, ThetaDir=clockwise\n'); passed = passed + 1;
else
    fprintf('  FAIL: theta config\n'); failed = failed + 1;
end
close(result.fig);

% Test 11: Radians input
theta_rad = deg2rad(theta);
result = plotting.polarPlot(theta_rad, r_4fold, ThetaUnit='radians');
if isvalid(result.fig)
    fprintf('  PASS: radians input works\n'); passed = passed + 1;
else
    fprintf('  FAIL: radians\n'); failed = failed + 1;
end
close(result.fig);

% Test 12: Custom RLim
result = plotting.polarPlot(theta, r_4fold, RLim=[0 2]);
if result.ax.RLim(2) == 2
    fprintf('  PASS: custom RLim applied\n'); passed = passed + 1;
else
    fprintf('  FAIL: RLim\n'); failed = failed + 1;
end
close(result.fig);

% Test 13: Figure size
result = plotting.polarPlot(theta, r_4fold, FigureSize=[20 20]);
pos = result.fig.Position;
expectedW = 20 * 96/2.54;
if abs(pos(3) - expectedW) < 5
    fprintf('  PASS: custom figure size\n'); passed = passed + 1;
else
    fprintf('  FAIL: figure size\n'); failed = failed + 1;
end
close(result.fig);

% ════════════════════════════════════════════════════════════════════
%  SUMMARY
% ════════════════════════════════════════════════════════════════════

fprintf('\n=== test_polar: %d passed, %d failed ===\n\n', passed, failed);
if failed > 0
    error('test_polar:failures', '%d test(s) failed.', failed);
end
