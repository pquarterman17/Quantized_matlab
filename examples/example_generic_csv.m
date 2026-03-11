%EXAMPLE_GENERIC_CSV  Import and process generic CSV / Excel / text data.
%
%   Demonstrates:
%     - importCSV (auto-detects delimiter, header rows, units)
%     - importExcel for .xlsx files
%     - importAuto for format-agnostic dispatch
%     - utilities.normalize, utilities.smoothData, utilities.convertUnits
%     - Writing synthetic data and verifying round-trip import
%     - Plotting with the +plotting package helpers
%
%   This example creates synthetic data for self-contained demonstration.
%   Swap the file paths for your real data files.
%
%   Run this script from any directory — it locates test data automatically.
%
%   See also parser.importCSV, parser.importExcel, parser.importAuto
%            utilities.normalize, utilities.smoothData, utilities.convertUnits

clear; clc;

ROOT = fileparts(fileparts(mfilename('fullpath')));
addpath(ROOT);
setupToolbox;

% ════════════════════════════════════════════════════════════════
%  1. Create a synthetic CSV file with typical lab data layout
% ════════════════════════════════════════════════════════════════
%   Many instruments export CSV with:
%     Row 1: column headers (name + unit in parentheses)
%     Row 2: data start
%   importCSV auto-detects this layout.

tmpCSV = fullfile(tempdir, 'example_labdata.csv');
fid = fopen(tmpCSV, 'w');
fprintf(fid, 'Temperature (K),Resistance (Ohm),Voltage (V),Current (A)\n');
T_write = linspace(300, 10, 200)';
R_write = 1000 * exp(-0.01*(T_write - 10)) + 5*randn(200,1);  % metallic R(T)
V_write = R_write * 1e-3;       % 1 mA drive current
I_write = ones(200,1) * 1e-3;
for k = 1:200
    fprintf(fid, '%.2f,%.4f,%.6f,%.6f\n', T_write(k), R_write(k), V_write(k), I_write(k));
end
fclose(fid);

fprintf('=== 1. Auto-detected CSV import ===\n');
data = parser.importCSV(tmpCSV, 'Verbose', true);
fprintf('  Rows: %d | Channels: %d\n', numel(data.time), size(data.values,2));
fprintf('  X-axis: %s\n', data.metadata.xColumnName);
for k = 1:numel(data.labels)
    fprintf('    Channel %d: %s (%s)\n', k, data.labels{k}, data.units{k});
end

% ════════════════════════════════════════════════════════════════
%  2. importAuto dispatch — same result, format-agnostic call
% ════════════════════════════════════════════════════════════════
%   importAuto inspects the file extension (and magic bytes for binary
%   formats) to pick the right parser automatically.

fprintf('\n=== 2. importAuto dispatch ===\n');
dataAuto = parser.importAuto(tmpCSV);
assert(isequal(dataAuto.time, data.time), 'importAuto result should match importCSV');
fprintf('  importAuto chose parser: %s\n', dataAuto.metadata.parserName);

% ════════════════════════════════════════════════════════════════
%  3. utilities.normalize — three normalisation methods
% ════════════════════════════════════════════════════════════════
%   Each normalisation is applied column-wise to data.values.

R = data.values(:,1);   % Resistance column

R_range  = utilities.normalize(R, 'Method', 'range');   % → [0, 1]
R_peak   = utilities.normalize(R, 'Method', 'peak');    % → max = 1
R_zscore = utilities.normalize(R, 'Method', 'zscore');  % → mean=0, std=1

fprintf('\n=== 3. Normalisation ===\n');
fprintf('  range:  min=%.3f  max=%.3f\n', min(R_range),  max(R_range));
fprintf('  peak:   min=%.3f  max=%.3f\n', min(R_peak),   max(R_peak));
fprintf('  zscore: mean=%.3f std=%.3f\n', mean(R_zscore), std(R_zscore));

% ════════════════════════════════════════════════════════════════
%  4. utilities.smoothData — remove measurement noise
% ════════════════════════════════════════════════════════════════
%   Moving average for speed, Gaussian for better edge handling.
%   Window is a half-width: total window = 2*Window + 1 samples.

R_smooth_ma   = utilities.smoothData(R, 'Method', 'moving',   'Window', 5);
R_smooth_gauss = utilities.smoothData(R, 'Method', 'gaussian', 'Window', 7);

th   = styles.default();
cols = plotting.lineColors(3, th);

fig1 = figure('Name', 'Smoothing comparison');
ax1  = axes(fig1);
hold(ax1, 'on');
plot(ax1, data.time, R,              'Color', [0.7 0.7 0.7], 'LineWidth', 0.5, 'DisplayName', 'Raw');
plot(ax1, data.time, R_smooth_ma,    'Color', cols(1,:),       'LineWidth', 1.2, 'DisplayName', 'Moving avg (W=5)');
plot(ax1, data.time, R_smooth_gauss, 'Color', cols(2,:),       'LineWidth', 1.2, 'DisplayName', 'Gaussian (W=7)');
plotting.formatAxes(ax1, th, 'XLabel', 'Temperature (K)', 'YLabel', 'Resistance (\Omega)');
title(ax1, 'R(T) — raw vs smoothed');
legend(ax1, 'Location', 'northwest');
grid(ax1, 'on');

% ════════════════════════════════════════════════════════════════
%  5. utilities.convertUnits — common lab unit conversions
% ════════════════════════════════════════════════════════════════
%   Supported categories: magnetic field (Oe ↔ T ↔ kOe),
%   moment (emu ↔ A·m²), temperature (K ↔ °C ↔ °F),
%   pressure (Pa ↔ atm), length (m ↔ nm ↔ Å).

T_K  = data.time;
[T_C, ~] = utilities.convertUnits(T_K, 'K', 'degC');

fprintf('\n=== 5. Unit conversions ===\n');
fprintf('  Temperature: %.1f K = %.1f °C\n', T_K(1), T_C(1));

% Example: field in Oe → Tesla
H_Oe = 5000;
[H_T, ~] = utilities.convertUnits(H_Oe, 'Oe', 'T');
fprintf('  Magnetic field: %.0f Oe = %.4f T\n', H_Oe, H_T);

% ════════════════════════════════════════════════════════════════
%  6. Import a real CSV from the test dataset directory
% ════════════════════════════════════════════════════════════════
%   La2NiO4_1.csv is an XRD CSV export (2θ vs cps).
%   importCSV handles it automatically.

realCSV = fullfile(ROOT, '+test_datasets', 'XRDML', 'La2NiO4_1.csv');
if isfile(realCSV)
    fprintf('\n=== 6. Real CSV import (La₂NiO₄ XRD export) ===\n');
    dataReal = parser.importCSV(realCSV, 'Verbose', true);

    fig2 = figure('Name', 'La2NiO4 XRD');
    ax2  = axes(fig2);
    plot(ax2, dataReal.time, dataReal.values(:,1), ...
        'Color', cols(1,:), 'LineWidth', 0.8);
    set(ax2, 'YScale', 'log');
    plotting.formatAxes(ax2, th, ...
        'XLabel', '2\theta (°)', ...
        'YLabel', 'Intensity (cps)');
    title(ax2, 'La_2NiO_4 — imported from CSV export');
    grid(ax2, 'on');
else
    fprintf('  [SKIP] %s not found\n', realCSV);
end

% ════════════════════════════════════════════════════════════════
%  7. Create and import a synthetic Excel file
% ════════════════════════════════════════════════════════════════
tmpXlsx = fullfile(tempdir, 'example_labdata.xlsx');
try
    N = 50;
    t = (0:N-1)' * 0.1;
    T_xl = array2table([t, sin(t), cos(t), rand(N,1)], ...
        'VariableNames', {'Time_s', 'CH1_V', 'CH2_V', 'Noise_V'});
    writetable(T_xl, tmpXlsx);

    fprintf('\n=== 7. Excel import ===\n');
    dataXL = parser.importExcel(tmpXlsx, 'Verbose', true);
    fprintf('  Rows: %d | Channels: %d\n', numel(dataXL.time), size(dataXL.values,2));
catch ME
    fprintf('  [SKIP] Excel write/read: %s\n', ME.message);
end

% Clean up temp files
if isfile(tmpCSV),  delete(tmpCSV);  end
if isfile(tmpXlsx), delete(tmpXlsx); end

fprintf('\nDone.\n');
