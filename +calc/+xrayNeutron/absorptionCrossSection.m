function sigma_b = absorptionCrossSection(symbol)
%ABSORPTIONCROSSSECTION  Thermal neutron absorption cross section (barns).
%
%   Syntax
%   ------
%   sigma_b = calc.xrayNeutron.absorptionCrossSection(symbol)
%
%   Returns the thermal-neutron (2200 m/s, λ = 1.7982 Å) absorption cross
%   section for a natural-isotopic-abundance element, in units of barns
%   (1 barn = 10⁻²⁴ cm²).
%
%   Unknown elements return 0 (no absorption contribution).  Source:
%   Sears, Neutron News 3, 26 (1992); NIST NCNR Neutron Scattering Lengths
%   table.  The table covers ~45 elements — the strong absorbers (B, Cd,
%   Gd, Sm, Eu, In, Li, Hg) and the most common materials-science ones.
%
%   The 1/v law means σ_abs scales linearly with λ; when combined with the
%   optical-theorem identity σ_abs = 2λ·b″, the imaginary coherent
%   scattering length b″ = σ_abs(λ_ref) / (2·λ_ref) is wavelength-
%   independent for 1/v absorbers.  Non-1/v resonance absorbers (Cd at
%   epithermal energies, Gd near its resonance) are not accurately
%   captured by this simple model.
%
%   Input
%   -----
%   symbol — element symbol (e.g. 'B', 'Cd', 'Ni')
%
%   Output
%   ------
%   sigma_b — thermal absorption cross section in barns

% ════════════════════════════════════════════════════════════════════

arguments
    symbol (1,:) char
end

tbl = {
    'H',   0.3326
    'Li', 70.5
    'Be',  0.0076
    'B', 767
    'C',   0.00350
    'N',   1.91
    'O',   0.00019
    'F',   0.0096
    'Na',  0.530
    'Mg',  0.063
    'Al',  0.231
    'Si',  0.171
    'P',   0.172
    'S',   0.53
    'Cl', 33.5
    'K',   2.10
    'Ca',  0.43
    'Ti',  6.09
    'V',   5.08
    'Cr',  3.05
    'Mn', 13.3
    'Fe',  2.56
    'Co', 37.18
    'Ni',  4.49
    'Cu',  3.78
    'Zn',  1.11
    'Ga',  2.75
    'Ge',  2.20
    'As',  4.50
    'Se', 11.7
    'Br',  6.90
    'Sr',  1.28
    'Y',   1.28
    'Zr',  0.185
    'Nb',  1.15
    'Mo',  2.48
    'Ag', 63.3
    'Cd', 2520.0
    'In', 193.8
    'Sn',  0.626
    'Sb',  4.91
    'Te',  4.70
    'I',   6.15
    'Cs', 29.0
    'Ba',  1.10
    'La',  8.97
    'Sm', 5922.0
    'Eu', 4530.0
    'Gd', 49700.0
    'Dy', 994.0
    'Er', 159.0
    'Hf', 104.1
    'Ta', 20.6
    'W',  18.3
    'Ir', 425.0
    'Pt', 10.3
    'Au', 98.65
    'Hg', 372.3
    'Pb',  0.171
    'Bi',  0.0338
};

idx = find(strcmpi(tbl(:,1), symbol), 1);
if isempty(idx)
    sigma_b = 0;
else
    sigma_b = tbl{idx, 2};
end

end
