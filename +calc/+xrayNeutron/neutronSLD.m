function result = neutronSLD(formula, density)
%NEUTRONSLD  Calculate the neutron scattering length density (SLD) of a material.
%
%   Syntax
%   ------
%   result = calc.xrayNeutron.neutronSLD(formula, density)
%
%   Inputs
%   ------
%   formula — chemical formula string, e.g. 'Ni', 'Fe3O4', 'SrTiO3'
%   density — bulk density (g/cm³)
%
%   Outputs
%   -------
%   result — struct with fields:
%     .SLD          — neutron SLD (Å⁻²)
%     .SLDe6        — neutron SLD × 10⁻⁶ (Å⁻²), i.e. ρ in units of 10⁻⁶ Å⁻²
%     .formula      — input formula string (echoed)
%     .density      — input density (g/cm³, echoed)
%     .bCoherent    — coherent scattering length per element (fm)
%     .elements     — cell array of element symbols
%     .counts       — stoichiometric coefficients
%     .latex        — LaTeX-formatted result string
%
%   Details
%   -------
%   SLD = (ρ × Nₐ / M) × Σ( nᵢ × bᵢ )
%
%   where ρ is density (g/cm³), Nₐ is Avogadro's number, M is the molecular
%   weight (g/mol), nᵢ is the stoichiometric count, and bᵢ is the coherent
%   neutron scattering length in fm.  Units: fm/cm³ → 10⁻¹³ cm / cm³ = 10⁻¹³/cm².
%   Converting to Å⁻²: 1/cm² = 10⁻¹⁶ Å⁻², so 1 fm/cm³ = 10⁻¹³ × 10⁻¹⁶ Å⁻² ...
%   The consistent conversion is: b in fm = b × 10⁻¹³ cm; density in g/cm³.
%   SLD [cm⁻²] = (ρ [g/cm³] × Nₐ [mol⁻¹] / M [g/mol]) × Σ(nᵢ bᵢ [cm])
%   SLD [Å⁻²]  = SLD [cm⁻²] × 10⁻¹⁶
%
%   Elements with NaN bCoherent are skipped with a warning.
%
%   Examples
%   --------
%   r = calc.xrayNeutron.neutronSLD('Ni', 8.908);
%   % r.SLDe6 ≈ 9.41  (literature value 9.40 × 10⁻⁶ Å⁻²)
%
%   r = calc.xrayNeutron.neutronSLD('SrTiO3', 5.12);
%   % r.SLDe6 ≈ 3.48  (literature ~3.5 × 10⁻⁶ Å⁻²)

% ════════════════════════════════════════════════════════════════════

arguments
    formula (1,:) char
    density (1,1) double {mustBePositive}
end

C  = calc.constants();
mw = calc.xrayNeutron.molecularWeight(formula);

nEls = numel(mw.elements);
bVec = zeros(1, nEls);

for i = 1:nEls
    el = calc.elementData('bySymbol', mw.elements{i});
    if isnan(el.bCoherent)
        warning('calc:xrayNeutron:neutronSLD:missingB', ...
            'Coherent scattering length for %s is NaN — treated as 0.', ...
            mw.elements{i});
        bVec(i) = 0;
    else
        bVec(i) = el.bCoherent;
    end
end

% Number density of formula units (mol/cm³)
numDens = density * C.NA / mw.M;

% Sum of scattering lengths weighted by stoichiometry (fm)
bSum = sum(mw.counts .* bVec);

% SLD in cm⁻²: b in fm → cm by multiplying by 1e-13
SLD_cm2 = numDens * bSum * 1e-13;

% Convert to Å⁻²: 1 cm⁻² = 1e-16 Å⁻²
SLD = SLD_cm2 * 1e-16;

result.SLD       = SLD;
result.SLDe6     = SLD * 1e6;
result.formula   = formula;
result.density   = density;
result.bCoherent = bVec;
result.elements  = mw.elements;
result.counts    = mw.counts;
result.latex     = sprintf( ...
    '$\\rho_n(\\text{%s}) = %.4g \\times 10^{-6}\\,\\text{\\AA}^{-2}$', ...
    formula, SLD * 1e6);

end
