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
%     .SLD          — neutron SLD, real part (Å⁻²)
%     .SLDe6        — neutron SLD, real part × 10⁶ (Å⁻²)
%     .sldImag      — neutron SLD, imaginary part (Å⁻²) from thermal absorption
%     .sldImagE6    — imaginary SLD × 10⁶
%     .SLD_complex  — complex SLD = real + i·imag (Å⁻²)
%     .formula      — input formula string (echoed)
%     .density      — input density (g/cm³, echoed)
%     .bCoherent    — coherent scattering length per element (fm)
%     .sigmaAbs     — thermal absorption cross section per element (barns)
%     .elements     — cell array of element symbols
%     .counts       — stoichiometric coefficients
%     .latex        — LaTeX-formatted result string
%
%   Details
%   -------
%   Real SLD:
%       SLD = (ρ × Nₐ / M) × Σ( nᵢ × bᵢ )
%
%   Imaginary SLD (from the optical-theorem identity σ_abs = 2λ·b″, which
%   gives b″ = σ_abs(λ_ref) / (2·λ_ref) — wavelength-independent for 1/v
%   absorbers):
%       Im(SLD) = (ρ × Nₐ / M) × Σ( nᵢ × σ_absᵢ / (2·λ_ref) )
%
%   with λ_ref = 1.7982 Å (thermal neutrons at 2200 m/s).  Strong absorbers
%   (B, Cd, Gd, Sm, Eu, In, Li, Hg) give significant imaginary SLD that
%   controls the absorption depth μ = 4π·Im(SLD)/λ in reflectometry.
%   Non-1/v resonance absorbers are not accurately modelled.
%
%   Elements with NaN bCoherent are skipped with a warning.
%
%   Examples
%   --------
%   r = calc.xrayNeutron.neutronSLD('Ni', 8.908);
%   % r.SLDe6 ≈ 9.41  (literature value 9.40 × 10⁻⁶ Å⁻²)
%
%   r = calc.xrayNeutron.neutronSLD('Gd2O3', 7.41);
%   % r.sldImagE6 ≈ 50  — demonstrates the extreme absorption of Gd.

% ════════════════════════════════════════════════════════════════════

arguments
    formula (1,:) char
    density (1,1) double {mustBePositive}
end

LAMBDA_REF = 1.7982;   % Å — thermal neutron reference wavelength

C  = calc.constants();
mw = calc.xrayNeutron.molecularWeight(formula);

nEls = numel(mw.elements);
bVec     = zeros(1, nEls);
sigmaVec = zeros(1, nEls);

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
    sigmaVec(i) = calc.xrayNeutron.absorptionCrossSection(mw.elements{i});
end

% Number density of formula units (mol/cm³)
numDens = density * C.NA / mw.M;

% Real part: Σ nᵢ bᵢ (fm)
bSum = sum(mw.counts .* bVec);

% Imaginary scattering length per formula unit (fm):
%   b″ᵢ = σ_absᵢ(barns) / (2·λ_ref)
%       = σ_absᵢ · 1e-24 cm² / (2 · λ_ref · 1e-8 cm)
%       = σ_absᵢ · 1e-16 cm / (2·λ_ref)
%       = σ_absᵢ · 1e-1 fm / (2·λ_ref)                    (1 cm = 1e13 fm)
%   simpler: σ_abs[barns] / (2·λ_ref[Å]) × (1e-4 / 2) ... let's use dimensional math.
%
% Derivation in SLD units directly:
%   σ_abs in cm²:  σ_abs · 1e-24
%   λ_ref in cm:   λ_ref · 1e-8
%   b″ in cm   = σ_abs · 1e-24 / (2 · λ_ref · 1e-8) = σ_abs / (2·λ_ref) · 1e-16 cm
%   b″ in fm   = b″ cm · 1e13 = σ_abs / (2·λ_ref) · 1e-3  fm
bImagPerAtom = sigmaVec / (2 * LAMBDA_REF) * 1e-3;   % fm
bImagSum     = sum(mw.counts .* bImagPerAtom);       % fm

% Real SLD:  SLD [cm⁻²] = numDens · bSum · 1e-13,  then × 1e-16 → Å⁻²
SLD_real_cm2 = numDens * bSum     * 1e-13;
SLD_imag_cm2 = numDens * bImagSum * 1e-13;
SLD_real = SLD_real_cm2 * 1e-16;
SLD_imag = SLD_imag_cm2 * 1e-16;

result.SLD         = SLD_real;
result.SLDe6       = SLD_real * 1e6;
result.sldImag     = SLD_imag;
result.sldImagE6   = SLD_imag * 1e6;
result.SLD_complex = complex(SLD_real, SLD_imag);
result.formula     = formula;
result.density     = density;
result.bCoherent   = bVec;
result.sigmaAbs    = sigmaVec;
result.elements    = mw.elements;
result.counts      = mw.counts;
if SLD_imag * 1e6 > 1e-3
    result.latex = sprintf( ...
        '$\\rho_n(\\text{%s}) = (%.4g + %.4gi) \\times 10^{-6}\\,\\text{\\AA}^{-2}$', ...
        formula, SLD_real * 1e6, SLD_imag * 1e6);
else
    result.latex = sprintf( ...
        '$\\rho_n(\\text{%s}) = %.4g \\times 10^{-6}\\,\\text{\\AA}^{-2}$', ...
        formula, SLD_real * 1e6);
end

end
