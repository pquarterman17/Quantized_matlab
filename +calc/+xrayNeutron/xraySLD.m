function result = xraySLD(formula, density, opts)
%XRAYSLD  Calculate the X-ray scattering length density (SLD) of a material.
%
%   Syntax
%   ------
%   result = calc.xrayNeutron.xraySLD(formula, density)
%   result = calc.xrayNeutron.xraySLD(formula, density, Energy_keV=8.048)
%
%   Inputs
%   ------
%   formula — chemical formula string, e.g. 'Ni', 'Fe3O4', 'SrTiO3'
%   density — bulk density (g/cm³)
%
%   Optional Name-Value
%   -------------------
%   Energy_keV — photon energy in keV to include anomalous dispersion
%                (f', f'') corrections.  When omitted or NaN, the SLD is
%                computed with f = Z (energy-independent limit, suitable
%                far from any absorption edge).  Tabulated at Cr/Co/Cu/Mo
%                Kα energies; the nearest is used for other input values.
%
%   Outputs
%   -------
%   result — struct with fields:
%     .SLD             — X-ray SLD, real part (Å⁻²)
%     .SLDe6           — X-ray SLD, real part × 10⁶ (Å⁻²)
%     .sldImag         — X-ray SLD, imaginary part (Å⁻²) [0 if no energy given]
%     .sldImagE6       — imaginary part × 10⁶
%     .SLD_complex     — complex SLD = real + i·imag (Å⁻²)
%     .electronDensity — electron density (electrons/Å³)
%     .formula         — input formula string (echoed)
%     .density         — input density (g/cm³, echoed)
%     .energy_keV      — echo of Energy_keV (NaN if unspecified)
%     .Z               — atomic numbers for each element
%     .fPrime          — f' for each element at the given energy
%     .fDoublePrime    — f'' for each element at the given energy
%     .elements        — cell array of element symbols
%     .counts          — stoichiometric coefficients
%     .latex           — LaTeX-formatted result string
%
%   Details
%   -------
%   The X-ray SLD with anomalous dispersion is:
%
%       SLD(E) = rₑ × N × Σ nᵢ (Zᵢ + f'ᵢ(E) + i·f''ᵢ(E))
%
%   where rₑ = 2.818 × 10⁻¹⁵ m is the classical electron radius, N is the
%   number density of formula units, and f'/f'' are the real/imaginary
%   dispersion corrections tabulated in calc.xrayNeutron.dispersionFactors.
%
%   Without Energy_keV the f', f'' terms default to zero (SLD ≡ rₑ·ρₑ).
%
%   Examples
%   --------
%   r = calc.xrayNeutron.xraySLD('Si', 2.329);
%   % r.SLDe6 ≈ 20.1  (literature ~20.1 × 10⁻⁶ Å⁻²)
%
%   % Near a transition metal K-edge, anomalous dispersion matters:
%   r = calc.xrayNeutron.xraySLD('Fe', 7.874, Energy_keV=8.048);
%   % r.SLDe6 drops from ~59.4 to ~50.4 due to negative f' at Cu Kα.
%   % r.sldImagE6 ≈ 16 × 10⁻⁶ from f'' ≈ 3.2.

% ════════════════════════════════════════════════════════════════════

arguments
    formula         (1,:) char
    density         (1,1) double {mustBePositive}
    opts.Energy_keV (1,1) double = NaN
end

C  = calc.constants();
mw = calc.xrayNeutron.molecularWeight(formula);

nEls = numel(mw.elements);
Zvec   = zeros(1, nEls);
fpVec  = zeros(1, nEls);
fppVec = zeros(1, nEls);

useDispersion = ~isnan(opts.Energy_keV);

for i = 1:nEls
    el = calc.elementData('bySymbol', mw.elements{i});
    Zvec(i) = el.Z;
    if useDispersion
        [fpVec(i), fppVec(i)] = calc.xrayNeutron.dispersionFactors( ...
            mw.elements{i}, opts.Energy_keV);
    end
end

% Classical electron radius in Angstroms (r_e = 2.8179e-15 m → 2.8179e-5 Å)
r_e_Ang = C.r_e * 1e10;   % m → Å

% Number density of formula units (mol/cm³)
numDens_cm3 = density * C.NA / mw.M;

% Sum over effective scattering factors (Z + f' + i f'').
fEffReal = sum(mw.counts .* (Zvec + fpVec));
fEffImag = sum(mw.counts .* fppVec);

% Electron density (real part, electrons/cm³ → electrons/Å³).
rhoE_cm3 = numDens_cm3 * fEffReal;
rhoE_Ang3 = rhoE_cm3 * 1e-24;

% Imaginary SLD density (absorption contribution).
rhoImag_Ang3 = numDens_cm3 * fEffImag * 1e-24;

% X-ray SLD in Å⁻²
SLD_real = r_e_Ang * rhoE_Ang3;
SLD_imag = r_e_Ang * rhoImag_Ang3;

result.SLD             = SLD_real;
result.SLDe6           = SLD_real * 1e6;
result.sldImag         = SLD_imag;
result.sldImagE6       = SLD_imag * 1e6;
result.SLD_complex     = complex(SLD_real, SLD_imag);
result.electronDensity = rhoE_Ang3;
result.formula         = formula;
result.density         = density;
result.energy_keV      = opts.Energy_keV;
result.Z               = Zvec;
result.fPrime          = fpVec;
result.fDoublePrime    = fppVec;
result.elements        = mw.elements;
result.counts          = mw.counts;

if useDispersion
    result.latex = sprintf( ...
        '$\\rho_x(\\text{%s}, %.2f\\,\\text{keV}) = (%.4g + %.4gi)\\times 10^{-6}\\,\\text{\\AA}^{-2}$', ...
        formula, opts.Energy_keV, SLD_real * 1e6, SLD_imag * 1e6);
else
    result.latex = sprintf( ...
        '$\\rho_x(\\text{%s}) = %.4g \\times 10^{-6}\\,\\text{\\AA}^{-2}$', ...
        formula, SLD_real * 1e6);
end

end
