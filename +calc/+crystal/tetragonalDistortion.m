function result = tetragonalDistortion(aRelaxed, cMeasured, opts)
%TETRAGONALDISTORTION  Compute c/a ratio and tetragonal distortion of an epitaxial film.
%
%   Syntax
%   ------
%   result = calc.crystal.tetragonalDistortion(aRelaxed, cMeasured)
%   result = calc.crystal.tetragonalDistortion(aRelaxed, cMeasured, cRelaxed=cRelaxed)
%
%   Inputs
%   ------
%   aRelaxed  — relaxed (bulk) in-plane lattice parameter a (Angstroms)
%   cMeasured — measured out-of-plane lattice parameter c (Angstroms)
%   cRelaxed  — relaxed out-of-plane lattice parameter c (Ang);
%               default = aRelaxed (assumes cubic bulk reference)
%
%   Outputs
%   -------
%   result — struct with fields:
%     .cOverA        — measured c/a ratio
%     .distortionPct — tetragonal distortion (cMeasured - cRelaxed)/cRelaxed * 100 (%)
%     .aRelaxed      — relaxed a (Ang)
%     .cMeasured     — measured c (Ang)
%     .cRelaxed      — relaxed c reference (Ang)
%     .latex         — LaTeX-formatted result string
%
%   Examples
%   --------
%   % BaTiO3 thin film: bulk a=4.00, measured c=4.03
%   r = calc.crystal.tetragonalDistortion(4.00, 4.03);
%   % r.cOverA=1.0075, r.distortionPct=0.75%
%
%   % Non-cubic reference (e.g. CrO2): aR=4.42, cR=2.92, cM=2.97
%   r = calc.crystal.tetragonalDistortion(4.42, 2.97, cRelaxed=2.92);

% ════════════════════════════════════════════════════════════════════

arguments
    aRelaxed  (1,1) double {mustBePositive}
    cMeasured (1,1) double {mustBePositive}
    opts.cRelaxed (1,1) double {mustBePositive} = aRelaxed
end

cRelaxed = opts.cRelaxed;

cOverA        = cMeasured / aRelaxed;
distortionPct = (cMeasured - cRelaxed) / cRelaxed * 100;

result.cOverA        = cOverA;
result.distortionPct = distortionPct;
result.aRelaxed      = aRelaxed;
result.cMeasured     = cMeasured;
result.cRelaxed      = cRelaxed;
result.latex = sprintf('$c/a = %.4g,\\;\\delta = %.4g\\%%$', cOverA, distortionPct);
end
