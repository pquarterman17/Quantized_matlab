function result = xraySLD(formula, density)
%XRAYSLD  Calculate the X-ray scattering length density (SLD) of a material.
%
%   Syntax
%   ------
%   result = calc.xrayNeutron.xraySLD(formula, density)
%
%   Inputs
%   ------
%   formula — chemical formula string, e.g. 'Ni', 'Fe3O4', 'SrTiO3'
%   density — bulk density (g/cm³)
%
%   Outputs
%   -------
%   result — struct with fields:
%     .SLD             — X-ray SLD (Å⁻²)
%     .SLDe6           — X-ray SLD × 10⁻⁶ (Å⁻²)
%     .electronDensity — electron density (electrons/Å³)
%     .formula         — input formula string (echoed)
%     .density         — input density (g/cm³, echoed)
%     .Z               — atomic numbers for each element
%     .elements        — cell array of element symbols
%     .counts          — stoichiometric coefficients
%     .latex           — LaTeX-formatted result string
%
%   Details
%   -------
%   The X-ray SLD is defined as:
%
%       SLD = rₑ × ρₑ
%
%   where rₑ = 2.818 × 10⁻¹⁵ m is the classical electron radius and ρₑ is
%   the electron density (electrons/volume).  For a compound of formula weight M:
%
%       ρₑ [electrons/cm³] = (ρ [g/cm³] × Nₐ / M [g/mol]) × Σ( nᵢ Zᵢ )
%
%   Converting to Å⁻²:  rₑ in Å = 2.818×10⁻⁵ Å; ρₑ in electrons/Å³.
%   1 cm³ = 10²⁴ Å³, so ρₑ [el/Å³] = ρₑ [el/cm³] × 10⁻²⁴.
%   SLD [Å⁻²] = rₑ [Å] × ρₑ [el/Å³]
%
%   Examples
%   --------
%   r = calc.xrayNeutron.xraySLD('Si', 2.329);
%   % r.SLDe6 ≈ 20.1  (literature ~20.1 × 10⁻⁶ Å⁻²)
%
%   r = calc.xrayNeutron.xraySLD('SrTiO3', 5.12);
%   % r.SLDe6 ≈ 34.2  (approximately)

% ════════════════════════════════════════════════════════════════════

arguments
    formula (1,:) char
    density (1,1) double {mustBePositive}
end

C  = calc.constants();
mw = calc.xrayNeutron.molecularWeight(formula);

nEls = numel(mw.elements);
Zvec = zeros(1, nEls);

for i = 1:nEls
    el = calc.elementData('bySymbol', mw.elements{i});
    Zvec(i) = el.Z;
end

% Classical electron radius in Angstroms (r_e = 2.8179e-15 m → 2.8179e-5 Å)
r_e_Ang = C.r_e * 1e10;   % m → Å

% Number density of formula units (mol/cm³)
numDens_cm3 = density * C.NA / mw.M;

% Total electron count per formula unit
Zsum = sum(mw.counts .* Zvec);

% Electron density in electrons/cm³
rhoE_cm3 = numDens_cm3 * Zsum;

% Convert electron density to electrons/Å³ (1 cm³ = 1e24 Å³)
rhoE_Ang3 = rhoE_cm3 * 1e-24;

% X-ray SLD in Å⁻²
SLD = r_e_Ang * rhoE_Ang3;

result.SLD             = SLD;
result.SLDe6           = SLD * 1e6;
result.electronDensity = rhoE_Ang3;
result.formula         = formula;
result.density         = density;
result.Z               = Zvec;
result.elements        = mw.elements;
result.counts          = mw.counts;
result.latex           = sprintf( ...
    '$\\rho_x(\\text{%s}) = %.4g \\times 10^{-6}\\,\\text{\\AA}^{-2}$', ...
    formula, SLD * 1e6);

end
