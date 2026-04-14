function result = kiessigThickness(deltaQ, options)
%KIESSIGTHICKNESS  Estimate film thickness from Kiessig fringe spacing in Q.
%
%   Syntax
%   ------
%   result = calc.thinFilm.kiessigThickness(deltaQ)
%   result = calc.thinFilm.kiessigThickness(deltaQ, SLD=3.47e-6)
%   result = calc.thinFilm.kiessigThickness(deltaQ, Qc=0.032)
%
%   Inputs
%   ------
%   deltaQ — Q-spacing between adjacent Kiessig fringes (Ang^-1)
%
%   Options
%   -------
%   SLD  — layer scattering length density (Ang^-2). When supplied, the
%          critical edge Qc = 4*sqrt(pi*SLD) is computed and the refracted
%          kinematic formula is used instead of the sharp-interface limit.
%          Leave empty / NaN (default) to disable the correction.
%   Qc   — Alternative to SLD: pass the critical-edge momentum transfer
%          directly (Ang^-1). Ignored when SLD is supplied.
%
%   Outputs
%   -------
%   result — struct with fields:
%     .thickness    — film thickness (Angstroms)
%     .thicknessNm  — film thickness (nm)
%     .deltaQ       — input Q-spacing (Ang^-1)
%     .Qc           — critical-edge Q used in the correction (Ang^-1; NaN
%                     when uncorrected)
%     .thicknessRaw — uncorrected 2*pi/deltaQ value (for reference)
%     .latex        — LaTeX-formatted result string
%
%   Notes
%   -----
%   The uncorrected relation t = 2*pi/deltaQ assumes the kinematic (Born)
%   approximation where refraction at the vacuum-film interface is
%   neglected.  That is accurate well above the critical edge; close to
%   Qc the incident beam refracts inside the denser film and the fringe
%   spacing measured at the air-side Q underestimates the true optical
%   path length.
%
%   The corrected formula (Tolan, "X-Ray Scattering from Soft-Matter
%   Thin Films", Ch. 3.3) uses the refracted kz inside the film:
%       t = 2*pi / sqrt(deltaQ^2 - 4*Qc^2)
%   where Qc^2 = 16*pi*SLD is the critical-edge momentum-transfer.
%   For dense films the correction is 10–20 % near the edge; at
%   deltaQ >> Qc the two formulas agree to better than 1 %.
%
%   Examples
%   --------
%   % Kinematic (far from edge)
%   r = calc.thinFilm.kiessigThickness(0.0628);  % ~100 Ang film
%
%   % Refraction-corrected for a Pt film (SLD ~ 6.3e-6)
%   r = calc.thinFilm.kiessigThickness(0.050, SLD=6.3e-6);
%
%   References
%   ----------
%   Tolan, M., "X-Ray Scattering from Soft-Matter Thin Films", Ch. 3.3
%   (Springer 1999).
%   Als-Nielsen, J. & McMorrow, D., "Elements of Modern X-Ray Physics",
%   2nd ed. Ch. 3.

% ════════════════════════════════════════════════════════════════════

arguments
    deltaQ         (1,1) double {mustBePositive}
    options.SLD    (1,1) double = NaN
    options.Qc     (1,1) double = NaN
end

% Determine Qc from SLD if provided
Qc = options.Qc;
if ~isnan(options.SLD) && options.SLD > 0
    % Q_c^2 = 16 pi SLD (standard reflectometry definition)
    Qc = 4 * sqrt(pi * options.SLD);
end

thicknessRaw = 2 * pi / deltaQ;
if isnan(Qc) || Qc <= 0
    thickness = thicknessRaw;
    QcUsed    = NaN;
else
    arg = deltaQ^2 - 4 * Qc^2;
    if arg <= 0
        % deltaQ too close to (or below) 2*Qc — correction diverges; fall
        % back to kinematic value and warn so the caller sees the issue.
        warning('calc:thinFilm:kiessigBelowEdge', ...
            ['deltaQ = %.4g is at or below 2*Qc = %.4g; refraction-', ...
             'corrected formula would diverge. Returning uncorrected ', ...
             '2*pi/deltaQ and Qc=NaN.'], deltaQ, 2 * Qc);
        thickness = thicknessRaw;
        QcUsed    = NaN;
    else
        thickness = 2 * pi / sqrt(arg);
        QcUsed    = Qc;
    end
end
thicknessNm = thickness * 0.1;      % nm

result.thickness    = thickness;
result.thicknessNm  = thicknessNm;
result.deltaQ       = deltaQ;
result.Qc           = QcUsed;
result.thicknessRaw = thicknessRaw;
if isnan(QcUsed)
    result.latex = sprintf( ...
        '$t = 2\\pi / \\Delta Q = %.4g\\,\\text{\\AA}\\;(%.4g\\,\\text{nm})$', ...
        thickness, thicknessNm);
else
    result.latex = sprintf( ...
        ['$t = 2\\pi / \\sqrt{\\Delta Q^2 - 4 Q_c^2} = %.4g\\,\\text{\\AA}', ...
         '\\;(%.4g\\,\\text{nm}),\\;Q_c = %.4g\\,\\text{\\AA}^{-1}$'], ...
        thickness, thicknessNm, QcUsed);
end
end
