function result = kiessigThickness(deltaQ)
%KIESSIGTHICKNESS  Estimate film thickness from Kiessig fringe spacing in Q.
%
%   Syntax
%   ------
%   result = calc.thinFilm.kiessigThickness(deltaQ)
%
%   Inputs
%   ------
%   deltaQ — Q-spacing between adjacent Kiessig fringes (Ang^-1)
%
%   Outputs
%   -------
%   result — struct with fields:
%     .thickness   — film thickness (Angstroms)
%     .thicknessNm — film thickness (nm)
%     .deltaQ      — input Q-spacing (Ang^-1)
%     .latex        — LaTeX-formatted result string
%
%   Notes
%   -----
%   Uses the relation t = 2*pi / deltaQ, valid for a single uniform layer
%   in the kinematic (Born) approximation.
%
%   Examples
%   --------
%   r = calc.thinFilm.kiessigThickness(0.0628);  % ~100 Ang film
%   r = calc.thinFilm.kiessigThickness(0.006);   % ~1047 Ang film

% ════════════════════════════════════════════════════════════════════

arguments
    deltaQ (1,1) double {mustBePositive}
end

thickness   = 2 * pi / deltaQ;      % Angstroms
thicknessNm = thickness * 0.1;      % nm

result.thickness   = thickness;
result.thicknessNm = thicknessNm;
result.deltaQ      = deltaQ;
result.latex       = sprintf( ...
    '$t = 2\\pi / \\Delta Q = %.4g\\,\\text{\\AA}\\;(%.4g\\,\\text{nm})$', ...
    thickness, thicknessNm);
end
