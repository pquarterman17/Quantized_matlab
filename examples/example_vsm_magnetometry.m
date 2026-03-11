%EXAMPLE_VSM_MAGNETOMETRY  Import and plot Quantum Design VSM/DynaCool data.
%
%   Demonstrates:
%     - importQDVSM with field/moment shorthands
%     - M vs H hysteresis loop plotting
%     - Coercivity and saturation moment extraction
%     - Stacking multiple datasets (e.g. different temperatures)
%     - Unit conversion: Oe → T, emu → emu/cm³ (volume normalisation)
%
%   Run this script from any directory — it locates test data automatically.
%
%   See also parser.importQDVSM, parser.importAuto, utilities.convertUnits

clear; clc;

% ── Locate project root and test data ─────────────────────────────────────
ROOT = fileparts(fileparts(mfilename('fullpath')));  % examples/ → project root
addpath(ROOT);
setupToolbox;

QD_DIR = fullfile(ROOT, '+test_datasets', 'QuantumDesign');

% ════════════════════════════════════════════════════════════════
%  1. Import a single VSM file (M vs H hysteresis loop)
% ════════════════════════════════════════════════════════════════
%   XAxis 'field'  → reads the Magnetic Field (Oe) column
%   YAxis 'moment' → reads the Moment (emu) column

fprintf('=== 1. Single M vs H import ===\n');
filepath = fullfile(QD_DIR, 'EDP136_Perp_StrawNew.dat');
data = parser.importQDVSM(filepath, 'XAxis', 'field', 'YAxis', 'moment');

fprintf('  Points: %d\n', numel(data.time));
fprintf('  Field range: %.0f to %.0f Oe\n', min(data.time), max(data.time));
fprintf('  Max |moment|: %.4g %s\n', max(abs(data.values)), data.units{1});

% ════════════════════════════════════════════════════════════════
%  2. Basic M vs H plot
% ════════════════════════════════════════════════════════════════
th = styles.default();          % load default colour/font theme
cols = plotting.lineColors(1, th);

fig1 = figure('Name', 'M vs H — EDP136 Perp');
ax = axes(fig1);
plot(ax, data.time, data.values, 'Color', cols(1,:), 'LineWidth', 1.2);
plotting.formatAxes(ax, th, ...
    'XLabel', 'Magnetic Field (Oe)', ...
    'YLabel', 'Moment (emu)');
title(ax, 'M vs H — EDP136 Perpendicular');
grid(ax, 'on');

% ════════════════════════════════════════════════════════════════
%  3. Extract coercivity (Hc) and saturation moment (Ms)
% ════════════════════════════════════════════════════════════════
%   Coercivity: field value where moment crosses zero
%   Saturation:  moment at maximum field (assumes saturation is reached)

H   = data.time;
M   = data.values(:,1);

% Find zero-crossings of M (sign change between adjacent points)
signChanges = find(diff(sign(M)) ~= 0);
Hc_vals = zeros(numel(signChanges), 1);
for k = 1:numel(signChanges)
    i = signChanges(k);
    % linear interpolation for zero crossing
    Hc_vals(k) = H(i) - M(i) * (H(i+1) - H(i)) / (M(i+1) - M(i));
end
Hc = mean(abs(Hc_vals));   % average of ±Hc branches
Ms = max(abs(M));           % saturation moment

fprintf('\n=== Extracted parameters ===\n');
fprintf('  Coercivity Hc   = %.1f Oe\n', Hc);
fprintf('  Saturation Ms   = %.4g emu\n', Ms);

% ════════════════════════════════════════════════════════════════
%  4. Unit conversion: Oe → T, emu → A·m²
% ════════════════════════════════════════════════════════════════
%   utilities.convertUnits handles common lab unit pairs automatically.

[H_T, ~]   = utilities.convertUnits(H, 'Oe', 'T');
[M_Am2, ~] = utilities.convertUnits(M, 'emu', 'A*m^2');

fig2 = figure('Name', 'M vs H — SI units');
ax2 = axes(fig2);
plot(ax2, H_T, M_Am2, 'Color', cols(1,:), 'LineWidth', 1.2);
plotting.formatAxes(ax2, th, ...
    'XLabel', 'Magnetic Field (T)', ...
    'YLabel', 'Moment (A·m²)');
title(ax2, 'M vs H — SI units');
grid(ax2, 'on');

% ════════════════════════════════════════════════════════════════
%  5. Stack multiple datasets (perpendicular vs in-plane comparison)
% ════════════════════════════════════════════════════════════════
files = {
    fullfile(QD_DIR, 'EDP136_Perp_StrawNew.dat'), 'EDP136 Perp';
    fullfile(QD_DIR, 'EDP125_Perp_StrawNew.dat'), 'EDP125 Perp';
    fullfile(QD_DIR, 'EDP125_IP_StrawNew.dat'),   'EDP125 IP';
};

fig3 = figure('Name', 'M vs H — multiple datasets');
ax3 = axes(fig3);
hold(ax3, 'on');

nFiles = size(files, 1);
cols3  = plotting.lineColors(nFiles, th);
legends = cell(nFiles, 1);

for k = 1:nFiles
    if ~isfile(files{k,1}), continue; end   % skip missing files gracefully
    d = parser.importQDVSM(files{k,1}, 'XAxis', 'field', 'YAxis', 'moment', 'Verbose', false);
    % Normalise to saturation so different sample volumes are comparable
    M_norm = d.values(:,1) / max(abs(d.values(:,1)));
    plot(ax3, d.time, M_norm, 'Color', cols3(k,:), 'LineWidth', 1.2);
    legends{k} = files{k,2};
end

plotting.formatAxes(ax3, th, ...
    'XLabel', 'Magnetic Field (Oe)', ...
    'YLabel', 'M/Ms');
title(ax3, 'M vs H — normalised comparison');
legend(ax3, legends(~cellfun(@isempty, legends)), 'Location', 'southeast');
grid(ax3, 'on');

% ════════════════════════════════════════════════════════════════
%  6. Import all channels (XAxis 'field', YAxis 'all')
% ════════════════════════════════════════════════════════════════
%   'all' returns every numeric column except the x-axis.
%   Useful for inspecting which channels are present before choosing.

fprintf('\n=== 6. All channels ===\n');
dataAll = parser.importQDVSM(filepath, 'XAxis', 'field', 'YAxis', 'all', 'Verbose', false);
fprintf('  Available channels:\n');
for k = 1:numel(dataAll.labels)
    fprintf('    [%d] %s (%s)\n', k, dataAll.labels{k}, dataAll.units{k});
end

fprintf('\nDone. Figures: M vs H (Oe), M vs H (SI), multi-dataset comparison.\n');
