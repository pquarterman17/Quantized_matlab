%EXAMPLE_RSM  Load and visualise a PANalytical 2D reciprocal-space map (RSM).
%
%   Demonstrates:
%     - importXRDML auto-detecting a 2D area-detector file
%     - Inspecting the map2D struct (axis ranges, intensity matrix, Qx/Qz)
%     - Plotting the intensity map in angle-space (Omega × 2Theta)
%     - Plotting the same map in reciprocal space (Qx × Qz)
%     - Extracting 1D line-cuts (H-cut and V-cut) from the 2D map
%     - Using the integrated 1D fallback for peak finding
%
%   A synthetic test file is generated if no real RSM file is available, so
%   this script runs without instrument access.
%
%   Run from the project root:
%       cd G:\Onedrive\Coding\git\thin_film_toolkit_matlab
%       run examples/example_rsm
%
%   See also parser.importXRDML, DataPlotter

clear; clc;

ROOT    = fileparts(fileparts(mfilename('fullpath')));
addpath(ROOT);
setupToolbox;

XRDML_DIR = fullfile(ROOT, '+test_datasets', 'XRDML');
RSM_FILE  = fullfile(XRDML_DIR, 'synthetic_rsm.xrdml');

% ════════════════════════════════════════════════════════════════════════
%  0. Generate synthetic RSM if no real file is available
% ════════════════════════════════════════════════════════════════════════
%   writeTestXRDML2D produces a valid XRDML 2.1 file with a Gaussian peak
%   centred at (Omega=30.5°, 2Theta=61°) using a 20×64 grid.
%   Replace RSM_FILE with a real Empyrean output to use measured data.

if ~isfile(RSM_FILE)
    fprintf('Generating synthetic RSM test file...\n');
    addpath(XRDML_DIR);
    writeTestXRDML2D(RSM_FILE, 20, 64, ...
        'OmegaStart', 29.0, 'OmegaEnd',    32.0, ...
        'TwoThetaStart', 58.0, 'TwoThetaEnd', 64.0, ...
        'PeakScale', 50000, 'Background', 100, ...
        'CountingTime', 1.0);
    rmpath(XRDML_DIR);
    fprintf('  Written: %s\n\n', RSM_FILE);
end

% ════════════════════════════════════════════════════════════════════════
%  1. Import the XRDML file
% ════════════════════════════════════════════════════════════════════════
%   importXRDML detects 2D area-detector data automatically.
%   map2D is populated in data.metadata.parserSpecific when is2D == true.
%   The 1D output (data.time, data.values) is the integrated profile for
%   backward compatibility with existing 1D code.

fprintf('=== 1. Import XRDML file ===\n');
data = parser.importXRDML(RSM_FILE, Intensity='cps', Verbose=true);

ps  = data.metadata.parserSpecific;
map = ps.map2D;

fprintf('  is2D        : %d\n',   ps.is2D);
fprintf('  Omega range : %.3f to %.3f deg (%d frames)\n', ...
    map.axis1(1), map.axis1(end), numel(map.axis1));
fprintf('  2Theta range: %.3f to %.3f deg (%d pixels)\n', ...
    map.axis2(1), map.axis2(end), numel(map.axis2));
fprintf('  Intensity   : %.1f to %.1f %s\n', ...
    min(map.intensity(:)), max(map.intensity(:)), map.intensityUnit);
if isfield(map, 'Qx')
    fprintf('  Qx range    : %.4f to %.4f Ang^-1\n', min(map.Qx(:)), max(map.Qx(:)));
    fprintf('  Qz range    : %.4f to %.4f Ang^-1\n', min(map.Qz(:)), max(map.Qz(:)));
end

% ════════════════════════════════════════════════════════════════════════
%  2. Plot intensity map in angle-space (Omega × 2Theta)
% ════════════════════════════════════════════════════════════════════════
%   imagesc is appropriate here because the angle grid is uniform.
%   Log scale is standard for XRD intensity maps — it reveals weak features
%   that would be invisible on a linear scale.

th = styles.default();

fig1 = figure('Name', 'RSM — angle space');
ax1  = axes(fig1);

Ilog = log10(max(map.intensity, 1));   % floor at 1 cps to avoid log(0)
imagesc(ax1, map.axis2, map.axis1, Ilog);
ax1.YDir = 'normal';
colormap(ax1, parula(256));
cbh = colorbar(ax1);
cbh.Label.String = 'log_{10}(I / cps)';
cbh.Label.Interpreter = 'tex';

plotting.formatAxes(ax1, th, ...
    'XLabel', '2\theta (deg)', ...
    'YLabel', '\omega (deg)');
title(ax1, 'Reciprocal-space map — angle coordinates', 'Interpreter', 'tex');

% ════════════════════════════════════════════════════════════════════════
%  3. Plot in reciprocal space (Qx × Qz) — if wavelength was available
% ════════════════════════════════════════════════════════════════════════
%   The Qx/Qz grids are non-rectangular (iso-Omega lines are curved in
%   Q-space), so pcolor is used instead of imagesc.
%   pcolor clips the last row and column (known limitation); the trim is
%   negligible for typical RSM sizes.

if isfield(map, 'Qx')
    fig2 = figure('Name', 'RSM — Q-space');
    ax2  = axes(fig2);

    pcolor(ax2, map.Qx, map.Qz, Ilog);
    shading(ax2, 'flat');
    colormap(ax2, parula(256));
    cbh2 = colorbar(ax2);
    cbh2.Label.String = 'log_{10}(I / cps)';
    cbh2.Label.Interpreter = 'tex';

    plotting.formatAxes(ax2, th, ...
        'XLabel', 'Q_x (\AA^{-1})', ...
        'YLabel', 'Q_z (\AA^{-1})');
    title(ax2, 'Reciprocal-space map — Q-space coordinates', 'Interpreter', 'tex');
else
    fprintf('\n  [skip] Q-space plot: wavelength not available in this file.\n');
end

% ════════════════════════════════════════════════════════════════════════
%  4. Extract 1D line-cuts from the 2D map
% ════════════════════════════════════════════════════════════════════════
%   H-cut (fixed Omega): profile along 2Theta at the Omega row closest to
%   the peak centre.  Equivalent to a conventional θ–2θ scan at that Omega.
%
%   V-cut (fixed 2Theta): profile along Omega at the 2Theta column closest
%   to the peak centre.  Equivalent to a rocking curve.

omPeak = (map.axis1(1)  + map.axis1(end))  / 2;   % Omega at peak centre
ttPeak = (map.axis2(1)  + map.axis2(end))  / 2;   % 2Theta at peak centre

[~, rowPk] = min(abs(map.axis1 - omPeak));
[~, colPk] = min(abs(map.axis2 - ttPeak));

hCut = map.intensity(rowPk, :)';    % H-cut: I vs 2Theta at fixed Omega
vCut = map.intensity(:, colPk);     % V-cut: I vs Omega at fixed 2Theta

fig3 = figure('Name', 'RSM — line cuts');
cols = plotting.lineColors(2, th);

ax3a = subplot(1, 2, 1);
semilogy(ax3a, map.axis2, hCut, 'Color', cols(1,:), 'LineWidth', 1.2);
plotting.formatAxes(ax3a, th, ...
    'XLabel', '2\theta (deg)', ...
    'YLabel', 'Intensity (cps)');
title(ax3a, sprintf('H-cut  \\omega = %.3f\\circ', map.axis1(rowPk)), ...
    'Interpreter', 'tex');

ax3b = subplot(1, 2, 2);
semilogy(ax3b, map.axis1, vCut, 'Color', cols(2,:), 'LineWidth', 1.2);
plotting.formatAxes(ax3b, th, ...
    'XLabel', '\omega (deg)', ...
    'YLabel', 'Intensity (cps)');
title(ax3b, sprintf('V-cut  2\\theta = %.3f\\circ', map.axis2(colPk)), ...
    'Interpreter', 'tex');

% ════════════════════════════════════════════════════════════════════════
%  5. Use the integrated 1D fallback for peak analysis
% ════════════════════════════════════════════════════════════════════════
%   data.time / data.values hold sum(map.intensity, 1)' — the intensity
%   summed over all Omega frames.  This is identical to what the GUI shows
%   for 1D analysis of a 2D file.

fprintf('\n=== 5. Integrated 1D profile ===\n');
fprintf('  Label       : %s\n',   data.labels{1});
fprintf('  2Theta span : %.3f to %.3f deg (%d points)\n', ...
    data.time(1), data.time(end), numel(data.time));
fprintf('  Max intensity: %.1f %s\n', max(data.values), data.units{1});

% Verify the integrated profile matches the row-sum of the intensity matrix
expected1D = sum(map.intensity, 1)';
if max(abs(data.values - expected1D)) < 1e-9 * max(abs(expected1D))
    fprintf('  Consistency : OK — data.values == sum(map2D.intensity, 1)''\n');
else
    fprintf('  WARNING: integrated profile mismatch\n');
end

fig4 = figure('Name', 'RSM — integrated profile');
ax4  = axes(fig4);
semilogy(ax4, data.time, data.values, 'Color', th.colors(1,:), 'LineWidth', 1.2);
plotting.formatAxes(ax4, th, ...
    'XLabel', '2\theta (deg)', ...
    'YLabel', ['Intensity (' data.units{1} ')']);
title(ax4, 'Integrated profile  (sum over \omega)', 'Interpreter', 'tex');

fprintf('\nDone.  4 figures generated.\n');
