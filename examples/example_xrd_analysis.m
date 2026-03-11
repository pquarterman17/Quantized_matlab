%EXAMPLE_XRD_ANALYSIS  Import and analyse XRD data from multiple file formats.
%
%   Demonstrates:
%     - importRigaku_raw  (.raw binary) and importXRDML (.xrdml XML)
%     - Smoothing and baseline removal
%     - Manual and automatic peak detection
%     - Scherrer crystallite size estimation from FWHM
%     - Exporting corrected data to CSV
%     - Batch XRD conversion (all files in a directory)
%
%   Run this script from any directory — it locates test data automatically.
%
%   See also parser.importRigaku_raw, parser.importXRDML, parser.importAuto
%            utilities.smoothData, utilities.normalize, scripts.batchConvertXRD

clear; clc;

ROOT = fileparts(fileparts(mfilename('fullpath')));
addpath(ROOT);
setupToolbox;

RIGAKU_DIR = fullfile(ROOT, '+test_datasets', 'rigaku');
XRDML_DIR  = fullfile(ROOT, '+test_datasets', 'XRDML');

% ════════════════════════════════════════════════════════════════
%  1. Import Rigaku .raw (binary format)
% ════════════════════════════════════════════════════════════════
%   UseCountsPerSec normalises by counting time so different scans
%   (with different counting times) can be directly compared.

fprintf('=== 1. Rigaku .raw import ===\n');
rawFile = fullfile(RIGAKU_DIR, 'YIG_Py_S7.raw');
dataRaw = parser.importRigaku_raw(rawFile, 'UseCountsPerSec', true, 'Verbose', true);

fprintf('  Points: %d | 2θ: %.3f° → %.3f° | step: %.4f°\n', ...
    numel(dataRaw.time), dataRaw.metadata.startAngle, ...
    dataRaw.metadata.endAngle, dataRaw.metadata.stepSize);

% ════════════════════════════════════════════════════════════════
%  2. Import PANalytical .xrdml (XML format)
% ════════════════════════════════════════════════════════════════
%   importXRDML parses PANalytical / Malvern Empyrean files.
%   The 'Intensity' option selects counts-per-second or raw counts.

fprintf('\n=== 2. PANalytical .xrdml import ===\n');
xrdmlFile = fullfile(XRDML_DIR, 'La2NiO4_1.xrdml');
dataXML = parser.importXRDML(xrdmlFile, 'Intensity', 'cps', 'Verbose', true);

% ════════════════════════════════════════════════════════════════
%  3. Plot raw XRD pattern
% ════════════════════════════════════════════════════════════════
th   = styles.default();
cols = plotting.lineColors(2, th);

fig1 = figure('Name', 'XRD — raw data');
ax1 = axes(fig1);
plot(ax1, dataRaw.time, dataRaw.values, 'Color', cols(1,:), 'LineWidth', 0.8, 'DisplayName', 'YIG/Py (Rigaku)');
hold(ax1, 'on');
plot(ax1, dataXML.time, dataXML.values, 'Color', cols(2,:), 'LineWidth', 0.8, 'DisplayName', 'La_2NiO_4 (XRDML)');
set(ax1, 'YScale', 'log');
plotting.formatAxes(ax1, th, 'XLabel', '2\theta (°)', 'YLabel', 'Intensity (cps)');
title(ax1, 'XRD — raw data comparison');
legend(ax1, 'Location', 'northeast');
grid(ax1, 'on');

% ════════════════════════════════════════════════════════════════
%  4. Smooth data and remove linear background
% ════════════════════════════════════════════════════════════════
%   Gaussian smoothing reduces shot noise while preserving peak shapes.
%   Linear background subtraction removes instrument/amorphous scattering.

tth  = dataRaw.time;
I    = dataRaw.values;

% Gaussian smooth with 5-point half-window (11 total)
Ismooth = utilities.smoothData(I, 'Method', 'gaussian', 'Window', 5);

% Estimate linear baseline from edge regions (first and last 5% of scan)
nPts = numel(tth);
edgePts = [1:round(0.05*nPts), round(0.95*nPts):nPts];
p = polyfit(tth(edgePts), Ismooth(edgePts), 1);
baseline = polyval(p, tth);
Icorr = Ismooth - baseline;
Icorr(Icorr < 0) = 0;   % clip negative artefacts after BG removal

% ════════════════════════════════════════════════════════════════
%  5. Find peak positions (local maxima, no toolbox required)
% ════════════════════════════════════════════════════════════════
%   Strategy: local maxima with prominence filter.
%   Threshold = 5% of maximum intensity (tune to your data noise floor).

threshold = 0.05 * max(Icorr);
isLocalMax = [false; Icorr(2:end-1) > Icorr(1:end-2) & ...
                      Icorr(2:end-1) > Icorr(3:end); false];
peakIdx = find(isLocalMax & Icorr > threshold);

fprintf('\n=== 4. Peak positions (Rigaku scan) ===\n');
for k = 1:numel(peakIdx)
    fprintf('  Peak %d: 2θ = %.3f° | I = %.0f cps\n', ...
        k, tth(peakIdx(k)), Icorr(peakIdx(k)));
end

% ════════════════════════════════════════════════════════════════
%  6. Scherrer crystallite size from FWHM
% ════════════════════════════════════════════════════════════════
%   t = (K · λ) / (β · cos θ)
%   K ≈ 0.94 (Scherrer constant for spherical crystallites)
%   λ = 1.5406 Å (Cu Kα1)
%   β = FWHM in radians
%   θ = Bragg angle (half of 2θ) in radians

K_scherrer = 0.94;
lambda_A    = 1.5406;   % Cu Kα1, Angstroms

fprintf('\n=== 5. Scherrer crystallite size ===\n');
for k = 1:numel(peakIdx)
    pk   = peakIdx(k);
    Ipk  = Icorr(pk);
    half = Ipk / 2;

    % Find half-maximum crossings on each side of the peak
    leftSide  = find(Icorr(1:pk)    < half, 1, 'last');
    rightSide = find(Icorr(pk:end)  < half, 1, 'first') + pk - 1;

    if isempty(leftSide) || isempty(rightSide), continue; end

    FWHM_deg = tth(rightSide) - tth(leftSide);
    beta_rad  = deg2rad(FWHM_deg);
    theta_rad = deg2rad(tth(pk) / 2);

    t_A = (K_scherrer * lambda_A) / (beta_rad * cos(theta_rad));
    t_nm = t_A / 10;

    fprintf('  Peak %d: 2θ = %.3f° | FWHM = %.3f° | Crystallite size ≈ %.1f nm\n', ...
        k, tth(pk), FWHM_deg, t_nm);
end

% ════════════════════════════════════════════════════════════════
%  7. Plot corrected pattern with peak markers
% ════════════════════════════════════════════════════════════════
fig2 = figure('Name', 'XRD — corrected + peaks');
ax2 = axes(fig2);
plot(ax2, tth, Icorr, 'Color', cols(1,:), 'LineWidth', 1);
hold(ax2, 'on');
plot(ax2, tth(peakIdx), Icorr(peakIdx), 'v', ...
    'MarkerFaceColor', cols(2,:), 'MarkerEdgeColor', 'none', ...
    'MarkerSize', 8, 'DisplayName', 'Peaks');
for k = 1:numel(peakIdx)
    text(ax2, tth(peakIdx(k)), Icorr(peakIdx(k))*1.05, ...
        sprintf('%.2f°', tth(peakIdx(k))), ...
        'HorizontalAlignment', 'center', 'FontSize', 8, 'Color', cols(2,:));
end
plotting.formatAxes(ax2, th, 'XLabel', '2\theta (°)', 'YLabel', 'Intensity (cps)');
title(ax2, 'XRD — background-subtracted with peak markers');
grid(ax2, 'on');

% ════════════════════════════════════════════════════════════════
%  8. Normalise and export corrected data to CSV
% ════════════════════════════════════════════════════════════════
%   writeXRDcsv writes a standard comma-delimited file with a metadata
%   header block compatible with Origin, Excel, and re-import via importCSV.

Inorm = utilities.normalize(Icorr, 'Method', 'peak');   % peak → max=1

outFile = fullfile(tempdir, 'YIG_Py_S7_corrected.csv');
utilities.writeXRDcsv(dataRaw, outFile, 'Format', 'standard', 'Intensity', 'cps');
fprintf('\nExported corrected data to: %s\n', outFile);

% ════════════════════════════════════════════════════════════════
%  9. Batch convert all XRD files in a directory
% ════════════════════════════════════════════════════════════════
%   batchConvertXRD walks a directory, auto-detects Rigaku/XRDML/Bruker,
%   and writes one _corrected.csv per file.

fprintf('\n=== 8. Batch convert ===\n');
outDir = fullfile(tempdir, 'xrd_batch_out');
if ~exist(outDir, 'dir'), mkdir(outDir); end

summary = scripts.batchConvertXRD(RIGAKU_DIR, ...
    'OutputDir',  outDir, ...
    'Recursive',  false, ...
    'Format',     'standard', ...
    'Intensity',  'cps', ...
    'ProgressFcn', @(msg) fprintf('  %s\n', msg));

fprintf('  Converted: %d files  |  Errors: %d\n', ...
    sum([summary.success]), sum(~[summary.success]));

fprintf('\nDone.\n');
