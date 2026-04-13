function result = hallAnalysis(field, hallResistance, options)
%HALLANALYSIS  Single-carrier Hall effect analysis from R_xy vs H data.
%
%   Syntax:
%     result = calc.electrical.hallAnalysis(field, hallResistance)
%     result = calc.electrical.hallAnalysis(field, hallResistance, Thickness=t)
%     result = calc.electrical.hallAnalysis(field, hallResistance, Thickness=t, Sigma=sigma)
%
%   Inputs:
%     field          — magnetic field vector (T or Oe; see FieldUnit)
%     hallResistance — transverse resistance R_xy or resistivity ρ_xy (Ohm or Ohm·cm)
%
%   Options:
%     Thickness — sample thickness (cm); required for carrier density (default NaN)
%     FieldUnit — 'T' (default) or 'Oe'; Oe inputs are converted to T internally
%     Sigma     — longitudinal conductivity σ (S/cm); required for Hall mobility (default NaN)
%
%   Outputs:
%     result — struct with fields:
%       .R_H           — Hall coefficient (cm³/C); sign: positive = holes, negative = electrons
%       .carrierDensity — carrier concentration n or p (cm⁻³); NaN if Thickness not supplied
%       .carrierType   — 'electron', 'hole', or 'unknown' (when R_H ≈ 0)
%       .mobility      — Hall mobility μ_H (cm²/V·s); NaN if Sigma not supplied
%       .fitR2         — coefficient of determination R² of the linear fit to R_xy vs H
%
%   Physics:
%     Single-carrier Hall coefficient: R_H = dR_xy/dH  (slope of R_xy vs H in SI units)
%     Carrier density: n = 1 / (R_H · e · thickness)
%     Hall mobility:   μ_H = |R_H| · σ
%     Sign convention: R_H > 0 → hole carriers (p-type); R_H < 0 → electron carriers (n-type)
%
%   Notes:
%     - For accurate R_H the linear fit excludes the contribution of antisymmetrised data;
%       pass antisymmetrised (or positive-field-only) data for best results.
%     - field and hallResistance must be the same length and contain at least two points.
%
%   Example:
%     H = (-5:0.5:5)';                  % Tesla
%     Rxy = -1.2e-3 * H + 0.01 * randn(size(H));   % electron-like slope
%     r = calc.electrical.hallAnalysis(H, Rxy, Thickness=1e-3, Sigma=500);
%     disp(r.carrierType)   % 'electron'

% ════════════════════════════════════════════════════════════════════

arguments
    field          (:,1) double
    hallResistance (:,1) double
    options.Thickness (1,1) double = NaN
    options.FieldUnit (1,:) char   = 'T'
    options.Sigma     (1,1) double = NaN
end

if numel(field) ~= numel(hallResistance)
    error('hallAnalysis:sizeMismatch', ...
        'field and hallResistance must have the same number of elements.');
end
if numel(field) < 2
    error('hallAnalysis:tooFewPoints', ...
        'At least 2 data points are required for a linear fit.');
end

% ── Unit conversion ────────────────────────────────────────────────
fieldUnit = validatestring(options.FieldUnit, {'T','Oe'});
if strcmp(fieldUnit, 'Oe')
    % 1 Oe = 1e-4 T (CGS → SI)
    field = field * 1e-4;
end

% ── Linear fit: R_xy = R_H * H + offset ────────────────────────────
%   Using the normal equations directly (no Statistics Toolbox).
H  = field;
Ry = hallResistance;
n  = numel(H);
Hm = mean(H);
Rm = mean(Ry);
SXX = sum((H  - Hm).^2);
SXY = sum((H  - Hm) .* (Ry - Rm));

slope     = SXY / SXX;         % R_H in Ohm/T  (or Ohm·cm/T)
intercept = Rm - slope * Hm;

% R² of the fit
Ry_fit = slope * H + intercept;
SStot  = sum((Ry - Rm).^2);
SSres  = sum((Ry - Ry_fit).^2);
if SStot < eps
    fitR2 = 1;
else
    fitR2 = 1 - SSres / SStot;
end

% ── Hall coefficient in cm³/C ──────────────────────────────────────
%   R_H [Ohm/T] = R_H [V·s/A] ; multiply by 100 to get cm³/C
%   (1 Ohm·m/T = 1 m³/C; conversion to cm³/C: ×10^6 from m→cm,
%    but field already in T and R in Ohm, so R_H_SI = slope [Ohm/T]
%    and R_H [cm³/C] = slope × 100  when R is in Ohm and thickness in cm)
R_H_cm3perC = slope * 100;    % Ohm/T → cm³/C  (×100 because 1 Ohm·T⁻¹ = 0.01 cm³/C)

% ── Carrier type ───────────────────────────────────────────────────
if R_H_cm3perC > 0
    carrierType = 'hole';
elseif R_H_cm3perC < 0
    carrierType = 'electron';
else
    carrierType = 'unknown';
end

% ── Carrier density ────────────────────────────────────────────────
C = calc.constants();
if ~isnan(options.Thickness) && abs(R_H_cm3perC) > 0
    % n [cm⁻³] = 1 / (R_H [cm³/C] · e [C] · thickness [cm])
    %           = 1 / (R_H · e)  when R_H already in cm³/C
    %   (thickness cancels because R_H here is already the slope of R_xy vs H,
    %    which for a 3D resistivity measurement already contains thickness;
    %    for a thin sheet (2D), thickness must be provided to get n_3D)
    carrierDensity = 1 / (abs(R_H_cm3perC) * C.e * options.Thickness);
else
    carrierDensity = NaN;
end

% ── Hall mobility ──────────────────────────────────────────────────
if ~isnan(options.Sigma)
    mobility = abs(R_H_cm3perC) * options.Sigma;
else
    mobility = NaN;
end

% ── Assemble output ────────────────────────────────────────────────
result.R_H            = R_H_cm3perC;
result.carrierDensity = carrierDensity;
result.carrierType    = carrierType;
result.mobility       = mobility;
result.fitR2          = fitR2;

end
