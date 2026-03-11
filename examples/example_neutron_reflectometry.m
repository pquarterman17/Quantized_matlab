%EXAMPLE_NEUTRON_REFLECTOMETRY  Import and visualise NCNR neutron reflectometry data.
%
%   Demonstrates:
%     - importNCNRRefl (.refl files — CANDOR / PBR reductus output)
%     - importNCNRDat  (.datA/.datD — polarised spin-up / spin-down)
%     - importNCNRPNR  (.pnr — polarised NR with NSF/SF variants)
%     - Plotting R vs Q and R*Q⁴ vs Q (Fresnel-normalised)
%     - Spin asymmetry: SA = (R++ - R--) / (R++ + R--)
%     - Kiessig fringe thickness via FFT
%
%   Run this script from any directory — it locates test data automatically.
%
%   See also parser.importNCNRRefl, parser.importNCNRDat, parser.importNCNRPNR

clear; clc;

ROOT = fileparts(fileparts(mfilename('fullpath')));
addpath(ROOT);
setupToolbox;

NCNR_DIR = fullfile(ROOT, '+test_datasets', 'NCNR');

% ════════════════════════════════════════════════════════════════
%  1. Import unpolarised .refl data (NR_Nickelate raw_data)
% ════════════════════════════════════════════════════════════════
%   .refl files contain Q (Å⁻¹), R, dR, and dQ columns.
%   importNCNRRefl reads both CANDOR (polychromatic) and PBR (monochromatic).

fprintf('=== 1. Unpolarised .refl import ===\n');
reflDir  = fullfile(NCNR_DIR, 'NR_Nickelate', 'raw_data');
reflFiles = dir(fullfile(reflDir, '*.refl'));

if isempty(reflFiles)
    % Fall back to PNR_NoSpinFlip directory which also has .refl files
    reflDir   = fullfile(NCNR_DIR, 'PNR_NoSpinFlip');
    reflFiles = dir(fullfile(reflDir, '*.refl'));
end

if ~isempty(reflFiles)
    rFile = fullfile(reflDir, reflFiles(1).name);
    dataR = parser.importNCNRRefl(rFile, 'Verbose', true);
    fprintf('  Q range: %.4f → %.4f Å⁻¹ | %d points\n', ...
        min(dataR.time), max(dataR.time), numel(dataR.time));
end

% ════════════════════════════════════════════════════════════════
%  2. Import polarised .datA / .datD (R++ and R--)
% ════════════════════════════════════════════════════════════════
%   File extension encodes polarisation:
%     .datA → spin-up/spin-up (R++)
%     .datD → spin-down/spin-down (R--)
%   (importNCNRDat reads the extension automatically)

fprintf('\n=== 2. Polarised .datA / .datD import ===\n');
pnrDir = fullfile(NCNR_DIR, 'PNR_NoSpinFlip');

datAfile = fullfile(pnrDir, 'S3_Si_YIG_Py_300K_700mT_multi-1-refl.datA');
datDfile = fullfile(pnrDir, 'S3_Si_YIG_Py_300K_700mT_multi-1-refl.datD');

hasDatA = isfile(datAfile);
hasDatD = isfile(datDfile);

if hasDatA
    datA = parser.importNCNRDat(datAfile, 'Verbose', true);
    fprintf('  R++ (datA): %d Q points | polarisation: %s\n', ...
        numel(datA.time), datA.metadata.parserSpecific.polarization);
end
if hasDatD
    datD = parser.importNCNRDat(datDfile, 'Verbose', true);
    fprintf('  R-- (datD): %d Q points | polarisation: %s\n', ...
        numel(datD.time), datD.metadata.parserSpecific.polarization);
end

% ════════════════════════════════════════════════════════════════
%  3. Plot R vs Q (log scale) for polarised data
% ════════════════════════════════════════════════════════════════
th = styles.default();

if hasDatA && hasDatD
    fig1 = figure('Name', 'Polarised NR — R vs Q');
    ax1  = axes(fig1);
    hold(ax1, 'on');

    % R column is index 1 in .values; dR is index 2 (uncertainty)
    errorbar(ax1, datA.time, datA.values(:,1), datA.values(:,2), ...
        'o', 'MarkerSize', 3, 'LineWidth', 0.5, ...
        'Color', [0.85 0.15 0.15], 'DisplayName', 'R++ (up)');
    errorbar(ax1, datD.time, datD.values(:,1), datD.values(:,2), ...
        's', 'MarkerSize', 3, 'LineWidth', 0.5, ...
        'Color', [0.10 0.40 0.80], 'DisplayName', 'R-- (down)');

    set(ax1, 'YScale', 'log');
    plotting.formatAxes(ax1, th, ...
        'XLabel', 'Q_z (Å^{-1})', ...
        'YLabel', 'Reflectivity R');
    title(ax1, 'Si/YIG/Py — 300 K, 700 mT');
    legend(ax1, 'Location', 'northeast');
    grid(ax1, 'on');
end

% ════════════════════════════════════════════════════════════════
%  4. Fresnel-normalised plot: R × Q⁴ vs Q
% ════════════════════════════════════════════════════════════════
%   Multiplying by Q⁴ removes the steep Fresnel decay and flattens
%   the curve, making Kiessig fringes easier to see at high Q.

if hasDatA && hasDatD
    fig2 = figure('Name', 'Polarised NR — R×Q⁴ vs Q');
    ax2  = axes(fig2);
    hold(ax2, 'on');

    Q4A = datA.time.^4;
    Q4D = datD.time.^4;

    plot(ax2, datA.time, datA.values(:,1) .* Q4A, ...
        'o-', 'MarkerSize', 3, 'LineWidth', 0.7, ...
        'Color', [0.85 0.15 0.15], 'DisplayName', 'R++ × Q^4');
    plot(ax2, datD.time, datD.values(:,1) .* Q4D, ...
        's-', 'MarkerSize', 3, 'LineWidth', 0.7, ...
        'Color', [0.10 0.40 0.80], 'DisplayName', 'R-- × Q^4');

    set(ax2, 'YScale', 'log');
    plotting.formatAxes(ax2, th, ...
        'XLabel', 'Q_z (Å^{-1})', ...
        'YLabel', 'R \times Q^4');
    title(ax2, 'Fresnel-normalised reflectivity');
    legend(ax2, 'Location', 'northeast');
    grid(ax2, 'on');
end

% ════════════════════════════════════════════════════════════════
%  5. Spin asymmetry: SA = (R++ - R--) / (R++ + R--)
% ════════════════════════════════════════════════════════════════
%   Spin asymmetry is directly sensitive to the depth-resolved
%   magnetisation profile. SA = 0 in non-magnetic regions.

if hasDatA && hasDatD
    % Interpolate to common Q grid (datasets may have slightly different Q points)
    Q_common = sort(unique([datA.time; datD.time]));
    Rpp = interp1(datA.time, datA.values(:,1), Q_common, 'pchip', NaN);
    Rmm = interp1(datD.time, datD.values(:,1), Q_common, 'pchip', NaN);

    valid = ~isnan(Rpp) & ~isnan(Rmm) & (Rpp + Rmm > 0);
    SA    = (Rpp(valid) - Rmm(valid)) ./ (Rpp(valid) + Rmm(valid));

    fig3 = figure('Name', 'Spin Asymmetry');
    ax3  = axes(fig3);
    plot(ax3, Q_common(valid), SA, 'k-', 'LineWidth', 1.2);
    yline(ax3, 0, '--', 'Color', [0.5 0.5 0.5]);
    plotting.formatAxes(ax3, th, ...
        'XLabel', 'Q_z (Å^{-1})', ...
        'YLabel', 'Spin Asymmetry');
    title(ax3, 'SA = (R++ - R--) / (R++ + R--)');
    grid(ax3, 'on');

    fprintf('\n=== Spin asymmetry ===\n');
    fprintf('  Max |SA| = %.3f at Q = %.4f Å⁻¹\n', ...
        max(abs(SA)), Q_common(valid(find(abs(SA) == max(abs(SA)), 1))));
end

% ════════════════════════════════════════════════════════════════
%  6. Kiessig fringe FFT — estimate total film thickness
% ════════════════════════════════════════════════════════════════
%   Kiessig fringes have period ΔQ = 2π/t, so the FFT of log(R) vs Q
%   gives a peak at t = 2π/ΔQ (in Angstroms).

if hasDatA
    Q  = datA.time;
    R  = datA.values(:,1);
    dR = datA.values(:,2);

    % Use only points with R > 3*dR (reasonable signal-to-noise)
    good = R > 3*dR & R > 0;
    Qg = Q(good);
    Rg = R(good);

    if numel(Qg) > 20
        % Resample to uniform Q grid
        Quni = linspace(min(Qg), max(Qg), 1024);
        logR = interp1(Qg, log10(Rg), Quni, 'pchip');
        logR = logR - mean(logR);   % remove DC offset

        % Hann window to suppress spectral leakage
        win  = hann(numel(Quni))';
        spec = abs(fft(logR .* win, 4*numel(Quni)));
        spec = spec(1:end/2);

        dQ    = Quni(2) - Quni(1);
        freqs = (0:numel(spec)-1) / (4*numel(Quni) * dQ);  % cycles per Å⁻¹
        thick = 2*pi * freqs;                               % thickness in Å

        % Find dominant peak (ignore DC, t < 20 Å noise floor)
        validT = thick > 20 & thick < 5000;
        [~, imax] = max(spec(validT));
        domThick  = thick(validT);
        domThick  = domThick(imax);

        fprintf('\n=== Kiessig FFT thickness ===\n');
        fprintf('  Dominant thickness ≈ %.0f Å = %.1f nm\n', domThick, domThick/10);

        fig4 = figure('Name', 'Kiessig FFT');
        ax4  = axes(fig4);
        plot(ax4, thick(validT)/10, spec(validT), 'Color', [0.15 0.45 0.75], 'LineWidth', 1);
        xline(ax4, domThick/10, '--r', sprintf('%.0f nm', domThick/10));
        xlim(ax4, [0 500]);
        plotting.formatAxes(ax4, th, ...
            'XLabel', 'Thickness (nm)', ...
            'YLabel', 'FFT amplitude');
        title(ax4, 'Kiessig fringe FFT — R++ data');
        grid(ax4, 'on');
    end
end

fprintf('\nDone.\n');
