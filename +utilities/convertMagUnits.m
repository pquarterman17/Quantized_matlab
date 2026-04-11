function [xOut, yOut, xUnitOut, yUnitOut, warnMsg] = convertMagUnits(xIn, yIn, options)
%CONVERTMAGUNITS  Convert magnetometry field and moment arrays between units.
%
%   [xOut, yOut, xU, yU] = utilities.convertMagUnits(x, y, ...
%       'FromField',   'Oe', 'ToField',  'T', ...
%       'FromMoment',  'emu', 'ToMoment', 'A·m²')
%
%   [xOut, yOut, xU, yU, warn] = utilities.convertMagUnits(x, y, ...
%       'ToMoment', 'emu/g', 'SampleMass', 0.0125)
%
%   Returns NEW arrays — the input xIn / yIn are never mutated, matching
%   the "raw data must be preserved" rule in CLAUDE.md.  Returns label
%   strings (xUnitOut, yUnitOut) suitable for plot axis labels.  If a
%   requested conversion needs sample mass / volume but those weren't
%   provided, the function silently returns the INPUT unchanged and
%   populates warnMsg with a human-readable reason — the caller can
%   surface it via uialert without aborting the render.
%
%   INPUT x is assumed to be magnetic FIELD in FromField units.
%   INPUT y is assumed to be magnetic MOMENT in FromMoment units.
%
%   SUPPORTED FIELD UNITS:  Oe, T, mT, A/m
%   SUPPORTED MOMENT UNITS: emu, A·m², emu/g, emu/cm³, kA/m
%
%   CONVERSION FACTORS (exact or to machine precision):
%       Oe → T        : ÷ 1e4          (1 T  = 1e4 Oe)
%       Oe → mT       : ÷ 10           (1 mT = 10 Oe)
%       Oe → A/m      : × 1e3/(4·pi)   (1 Oe ≈ 79.5775 A/m)
%       emu → A·m²    : × 1e-3         (1 emu = 1e-3 A·m² = 1e-3 J/T)
%       emu → emu/g   : ÷ SampleMass (g) — requires mass > 0
%       emu → emu/cm³ : ÷ SampleVolume (cm³) — requires volume > 0
%       emu → kA/m    : × 1e-3 / (SampleVolume × 1e-6) / 1e3
%                     = × 1 / SampleVolume_cm3 (because 1 emu/cm³ = 1 kA/m)
%
%   NAME-VALUE OPTIONS:
%       FromField     — source field unit (default: 'Oe')
%       ToField       — target field unit (default: 'Oe' — no-op)
%       FromMoment    — source moment unit (default: 'emu')
%       ToMoment      — target moment unit (default: 'emu' — no-op)
%       SampleMass    — sample mass in GRAMS (default: 0)
%       SampleVolume  — sample volume in CM^3 (default: 0)
%
%   OUTPUTS:
%       xOut      — converted x array (same shape as xIn)
%       yOut      — converted y array (same shape as yIn)
%       xUnitOut  — resolved x unit string (after conversion)
%       yUnitOut  — resolved y unit string (after conversion)
%       warnMsg   — empty on success; reason string when a conversion was
%                   skipped (e.g. missing SampleMass for emu/g)
%
%   EXAMPLES:
%       % Oe → T: 50,000 Oe = 5 T
%       x = [-5e4 -1e4 0 1e4 5e4];
%       [xo, ~] = utilities.convertMagUnits(x, x, ...
%           'FromField', 'Oe', 'ToField', 'T');
%       % xo == [-5 -1 0 1 5]
%
%       % emu → emu/g with mass 12.5 mg
%       [~, yo] = utilities.convertMagUnits([], [0.01 0.02], ...
%           'ToMoment', 'emu/g', 'SampleMass', 0.0125);
%       % yo == [0.8 1.6]
%
%       % Missing mass → no-op with warning
%       [~, yo, ~, yu, w] = utilities.convertMagUnits([], [0.01], ...
%           'ToMoment', 'emu/g', 'SampleMass', 0);
%       % yo == [0.01], yu == 'emu', w contains the reason

    arguments
        xIn                          double
        yIn                          double
        options.FromField    (1,:)   char = 'Oe'
        options.ToField      (1,:)   char = 'Oe'
        options.FromMoment   (1,:)   char = 'emu'
        options.ToMoment     (1,:)   char = 'emu'
        options.SampleMass   (1,1)   double = 0    % grams
        options.SampleVolume (1,1)   double = 0    % cm^3
    end

    xOut     = xIn;
    yOut     = yIn;
    xUnitOut = options.ToField;
    yUnitOut = options.ToMoment;
    warnMsg  = '';

    % ── Field conversion (x-axis) ───────────────────────────────────
    [xFactor, xOk, xReason] = fieldFactor(options.FromField, options.ToField);
    if ~xOk
        warnMsg = appendWarn(warnMsg, xReason);
        xUnitOut = options.FromField;   % revert label to reflect actual data
    elseif ~isempty(xIn)
        xOut = xIn .* xFactor;
    end

    % ── Moment conversion (y-axis) ──────────────────────────────────
    [yFactor, yOk, yReason] = momentFactor(options.FromMoment, options.ToMoment, ...
                                           options.SampleMass, options.SampleVolume);
    if ~yOk
        warnMsg = appendWarn(warnMsg, yReason);
        yUnitOut = options.FromMoment;  % revert label to reflect actual data
    elseif ~isempty(yIn)
        yOut = yIn .* yFactor;
    end
end


% ════════════════════════════════════════════════════════════════════════
%  Local helpers
% ════════════════════════════════════════════════════════════════════════

function [factor, ok, reason] = fieldFactor(fromU, toU)
%FIELDFACTOR  Multiplier to convert fromU → toU for magnetic field.
    ok = true;
    reason = '';
    factor = 1;

    if strcmp(fromU, toU), return; end

    % Convert fromU → Oe (pivot), then Oe → toU
    [toOe, okFrom] = toOeFactor(fromU);
    if ~okFrom
        ok = false;
        reason = sprintf('Unknown source field unit "%s"', fromU);
        return;
    end

    [fromOe, okTo] = fromOeFactor(toU);
    if ~okTo
        ok = false;
        reason = sprintf('Unknown target field unit "%s"', toU);
        return;
    end

    factor = toOe * fromOe;
end


function [f, ok] = toOeFactor(u)
%TOOEFACTOR  Multiplier to convert u → Oe.
    ok = true;
    switch u
        case 'Oe',  f = 1;
        case 'T',   f = 1e4;           % 1 T = 1e4 Oe
        case 'mT',  f = 10;            % 1 mT = 10 Oe
        case 'A/m', f = 4*pi / 1e3;    % 1 A/m = 4π/1000 Oe ≈ 0.01257 Oe
        otherwise,  f = 1; ok = false;
    end
end


function [f, ok] = fromOeFactor(u)
%FROMOEFACTOR  Multiplier to convert Oe → u.
    ok = true;
    switch u
        case 'Oe',  f = 1;
        case 'T',   f = 1e-4;          % 1 Oe = 1e-4 T
        case 'mT',  f = 0.1;           % 1 Oe = 0.1 mT
        case 'A/m', f = 1e3 / (4*pi);  % 1 Oe ≈ 79.5775 A/m
        otherwise,  f = 1; ok = false;
    end
end


function [factor, ok, reason] = momentFactor(fromU, toU, mass_g, vol_cm3)
%MOMENTFACTOR  Multiplier to convert fromU → toU for magnetic moment.
%   Some conversions require sample mass or volume; if the required
%   value is zero, returns ok=false and a reason string — caller is
%   expected to warn the user and leave the data unchanged.
    ok = true;
    reason = '';
    factor = 1;

    if strcmp(fromU, toU), return; end

    % Only support conversions FROM emu for now (matches the dropdown
    % Items list).  A future "from A·m² to emu" path would reuse the
    % same structure with a sign flip.
    if ~strcmp(fromU, 'emu')
        ok = false;
        reason = sprintf('Moment conversions from "%s" are not yet supported (only from "emu")', fromU);
        return;
    end

    switch toU
        case 'emu'
            factor = 1;
        case 'A·m²'
            factor = 1e-3;              % 1 emu = 1e-3 A·m²
        case 'emu/g'
            if mass_g <= 0
                ok = false;
                reason = sprintf(['Cannot convert moment to emu/g: sample mass is 0. ' ...
                                  'Enter the sample mass (grams) in the Corrections panel.']);
                return;
            end
            factor = 1 / mass_g;
        case 'emu/cm³'
            if vol_cm3 <= 0
                ok = false;
                reason = sprintf(['Cannot convert moment to emu/cm%c: sample volume is 0. ' ...
                                  'Enter sample width × height × thickness in the Corrections panel.'], ...
                                 char(179));
                return;
            end
            factor = 1 / vol_cm3;
        case 'kA/m'
            % 1 emu = 1e-3 A·m²; 1 emu/cm³ = 1e-3 A·m² / 1e-6 m³ = 1e3 A/m = 1 kA/m
            % So emu / vol_cm³ = kA/m directly.
            if vol_cm3 <= 0
                ok = false;
                reason = sprintf(['Cannot convert moment to kA/m: sample volume is 0. ' ...
                                  'Enter sample width × height × thickness in the Corrections panel.']);
                return;
            end
            factor = 1 / vol_cm3;
        otherwise
            ok = false;
            reason = sprintf('Unknown target moment unit "%s"', toU);
    end
end


function s = appendWarn(s, msg)
%APPENDWARN  Concatenate warning messages with newline separators.
    if isempty(msg), return; end
    if isempty(s)
        s = msg;
    else
        s = sprintf('%s\n%s', s, msg);
    end
end
