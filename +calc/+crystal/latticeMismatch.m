function result = latticeMismatch(aFilm, aSub)
%LATTICEMISMATCH  Compute the epitaxial lattice mismatch between film and substrate.
%
%   Syntax
%   ------
%   result = calc.crystal.latticeMismatch(aFilm, aSub)
%
%   Inputs
%   ------
%   aFilm — in-plane lattice parameter of the film (Angstroms)
%   aSub  — lattice parameter of the substrate (Angstroms)
%
%   Outputs
%   -------
%   result — struct with fields:
%     .mismatch     — fractional mismatch f = (aFilm - aSub)/aSub
%     .mismatchPct  — mismatch as a percentage
%     .description  — 'tensile', 'compressive', or 'matched'
%     .latex        — LaTeX-formatted result string
%
%   Notes
%   -----
%   Positive mismatch (aFilm > aSub) → film is under biaxial tension.
%   Negative mismatch (aFilm < aSub) → film is under biaxial compression.
%
%   Examples
%   --------
%   % La0.7Sr0.3MnO3 on SrTiO3
%   r = calc.crystal.latticeMismatch(3.876, 3.905);  % f = -0.74% (compressive)

% ════════════════════════════════════════════════════════════════════

arguments
    aFilm (1,1) double {mustBePositive}
    aSub  (1,1) double {mustBePositive}
end

f    = (aFilm - aSub) / aSub;
fPct = f * 100;

if f > 1e-6
    desc = 'tensile';
elseif f < -1e-6
    desc = 'compressive';
else
    desc = 'matched';
end

result.mismatch    = f;
result.mismatchPct = fPct;
result.description = desc;
result.latex = sprintf('$f = %.4g\\%%\\;\\text{(%s)}$', fPct, desc);
end
