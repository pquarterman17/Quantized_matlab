function [fp, fpp] = dispersionFactors(symbol, energy_keV)
%DISPERSIONFACTORS  Anomalous dispersion corrections (f', f'') for X-ray SLD.
%
%   Syntax
%   ------
%   [fp, fpp] = calc.xrayNeutron.dispersionFactors(symbol, energy_keV)
%
%   Returns the real and imaginary dispersion corrections to the atomic
%   scattering factor:
%
%       f(E) = f0(q) + f'(E) + i f''(E)
%
%   for use in anomalous-scattering SLD calculations.  Values are
%   tabulated at four common laboratory X-ray energies:
%
%       Cr Kα  (5.415 keV)
%       Co Kα  (6.930 keV)
%       Cu Kα  (8.048 keV)
%       Mo Kα  (17.479 keV)
%
%   The nearest tabulated energy is used; unknown elements return (0, 0)
%   which reduces xraySLD to its energy-independent form.  Source: Henke,
%   Gullikson & Davis (Atomic Data and Nuclear Data Tables, 54, 181,
%   1993); CXRO table at https://henke.lbl.gov/optical_constants/.
%
%   For sub-edge energies or elements not in the table, query the CXRO
%   database directly — the intent of this helper is to give reasonable
%   corrections for the majority of common lab-XRD materials, not to
%   replace a full dispersion database.
%
%   Inputs
%   ------
%   symbol      — element symbol (e.g. 'Fe', 'Cu')
%   energy_keV  — photon energy in keV (scalar)
%
%   Outputs
%   -------
%   fp   — f' (real part of the dispersion correction)
%   fpp  — f'' (imaginary part of the dispersion correction)

% ════════════════════════════════════════════════════════════════════

arguments
    symbol     (1,:) char
    energy_keV (1,1) double {mustBePositive}
end

% Tabulated energies (keV) — columns of the data table.
refE = [5.415, 6.930, 8.048, 17.479];

% Pick nearest tabulated energy.
[~, idx] = min(abs(refE - energy_keV));

% Element table: each row is {symbol, [fp @ each refE], [fpp @ each refE]}
% Values rounded from Henke/CXRO at the four Kα energies.
tbl = {
    'H',  [ 0.000,  0.000,  0.000,  0.000], [0.000, 0.000, 0.000, 0.000]
    'C',  [ 0.034,  0.022,  0.017,  0.002], [0.019, 0.012, 0.009, 0.001]
    'N',  [ 0.060,  0.039,  0.031,  0.004], [0.039, 0.024, 0.018, 0.002]
    'O',  [ 0.096,  0.063,  0.049,  0.008], [0.066, 0.041, 0.032, 0.004]
    'Na', [ 0.229,  0.164,  0.130,  0.024], [0.248, 0.156, 0.124, 0.018]
    'Mg', [ 0.287,  0.208,  0.166,  0.036], [0.353, 0.222, 0.177, 0.026]
    'Al', [ 0.359,  0.263,  0.213,  0.052], [0.489, 0.309, 0.246, 0.037]
    'Si', [ 0.401,  0.298,  0.244,  0.073], [0.658, 0.415, 0.330, 0.051]
    'P',  [ 0.423,  0.320,  0.283,  0.098], [0.863, 0.545, 0.434, 0.069]
    'S',  [ 0.417,  0.338,  0.319,  0.128], [1.107, 0.701, 0.559, 0.091]
    'Ca', [-0.366,  0.076,  0.287,  0.226], [2.461, 1.597, 1.282, 0.220]
    'Ti', [-1.690, -0.340,  0.219,  0.349], [3.412, 2.279, 1.807, 0.344]
    'Cr', [-2.201, -2.316, -0.198,  0.452], [0.621, 3.059, 2.642, 0.502]
    'Mn', [-0.590, -2.857, -0.568,  0.510], [0.715, 3.292, 2.808, 0.549]
    'Fe', [ 0.308, -1.134, -1.179,  0.347], [0.863, 3.499, 3.204, 0.650]
    'Co', [ 0.620, -0.018, -2.365,  0.402], [1.018, 1.054, 3.624, 0.706]
    'Ni', [ 0.773,  0.300, -2.956,  0.450], [1.210, 1.247, 0.509, 0.762]
    'Cu', [ 1.011,  0.530, -1.965,  0.512], [1.428, 1.475, 0.589, 0.823]
    'Zn', [ 1.218,  0.724, -1.612,  0.568], [1.658, 1.724, 0.678, 0.883]
    'Ga', [ 1.420,  0.915, -1.242,  0.620], [1.896, 1.967, 0.779, 0.948]
    'As', [ 1.800,  1.242, -0.930,  0.728], [2.447, 2.527, 1.006, 1.091]
    'Sr', [ 2.870,  2.202, -0.464,  1.028], [4.126, 4.259, 2.733, 1.588]
    'Y',  [ 3.126,  2.453,  0.298,  1.068], [4.430, 4.572, 2.961, 1.698]
    'Zr', [ 3.397,  2.734,  0.633,  1.109], [4.735, 4.886, 3.190, 1.810]
    'Mo', [ 4.456,  3.851,  1.810, -0.101], [6.095, 6.287, 4.247, 1.749]
    'In', [ 1.054, -1.098, -0.640,  0.174], [7.036, 7.240, 5.045, 2.726]
    'Ba', [-4.054,  0.268, -0.378, -0.178], [9.089, 9.330, 7.465, 2.282]
    'La', [-2.880, -0.568, -0.359,  0.173], [9.504, 9.753, 8.946, 2.418]
    'Ta', [-4.821, -4.911, -5.320, -2.226], [2.687, 4.114, 6.196, 6.196]
    'W',  [-5.039, -5.183, -5.577, -2.526], [2.840, 4.352, 6.872, 6.572]
    'Pt', [-5.884, -5.998, -4.996, -3.440], [3.389, 5.205, 6.925, 7.762]
    'Au', [-5.977, -6.121, -5.055, -3.618], [3.510, 5.393, 7.257, 8.021]
    'Pb', [-4.917, -5.064, -4.047, -4.818], [4.203, 6.508, 8.505, 9.752]
};

rowIdx = find(strcmpi(tbl(:,1), symbol), 1);
if isempty(rowIdx)
    fp  = 0;
    fpp = 0;
    return;
end

fpRow  = tbl{rowIdx, 2};
fppRow = tbl{rowIdx, 3};

fp  = fpRow(idx);
fpp = fppRow(idx);

end
