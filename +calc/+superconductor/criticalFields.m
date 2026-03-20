function result = criticalFields(opts)
%CRITICALFIELDS  Calculate superconducting critical field(s) at temperature T.
%
%   Syntax
%   ------
%   result = calc.superconductor.criticalFields(Material=name, T=T)
%   result = calc.superconductor.criticalFields(Hc0=Hc0, Tc=Tc, T=T)
%   result = calc.superconductor.criticalFields(Hc0=Hc0, Tc=Tc, T=T, ...
%                lambda=lam, xi=xi, kappa=kap)
%
%   Inputs
%   ------
%   Material — (optional) string material name (e.g. 'Nb').  Loads Hc0,
%              Tc, lambda0, xi0 from materialPresets.
%   Hc0      — thermodynamic critical field at T=0 (Oe); required unless
%              Material given.  For type-II materials this is the
%              thermodynamic Hc (not Hc2).
%   Tc       — critical temperature (K); required unless Material given.
%   T        — measurement temperature (K); must be < Tc.
%   lambda   — London penetration depth at T (nm); optional override.
%              If absent and the material is type-II, computed via
%              londonDepth.
%   xi       — coherence length at T (nm); optional override.
%              If absent and the material is type-II, computed via
%              coherenceLength.
%   kappa    — GL parameter (dimensionless); optional override.
%              If absent computed from lambda/xi.
%
%   Outputs
%   -------
%   result — struct with fields:
%     .Hc   — thermodynamic critical field at T (Oe)
%     .Hc1  — lower critical field (Oe); NaN for type-I
%     .Hc2  — upper critical field (Oe); NaN for type-I
%     .type — 'I' or 'II'
%     .T    — temperature (K)
%     .Tc   — critical temperature (K)
%     .latex — LaTeX-formatted result string
%
%   Formulas
%   --------
%   Thermodynamic Hc (both types):
%     Hc(T) = Hc0 * (1 - (T/Tc)^2)
%
%   Type-II lower/upper critical fields (Gaussian CGS):
%     Hc1 = (Phi0 * ln(kappa)) / (4*pi * lambda^2)
%     Hc2 = Phi0 / (2*pi * xi^2)
%   where Phi0 is converted from Wb to G*cm^2 (1 Wb = 1e8 G*cm^2).
%
%   Examples
%   --------
%   r = calc.superconductor.criticalFields(Material='Nb', T=4.2);
%   fprintf('Hc1=%.1f Oe  Hc2=%.0f Oe\n', r.Hc1, r.Hc2);
%
%   r = calc.superconductor.criticalFields(Material='Al', T=0.5);
%   fprintf('Hc=%.1f Oe (type I)\n', r.Hc);

% ════════════════════════════════════════════════════════════════════

arguments
    opts.Material (1,:) char = ''
    opts.Hc0      (1,1) double = NaN   % Oe
    opts.Tc       (1,1) double = NaN   % K
    opts.T        (1,1) double {mustBeNonnegative}
    opts.lambda   (1,1) double = NaN   % nm, at temperature T
    opts.xi       (1,1) double = NaN   % nm, at temperature T
    opts.kappa    (1,1) double = NaN
end

% ── Resolve preset parameters ────────────────────────────────────────
if ~isempty(opts.Material)
    preset = calc.superconductor.materialPresets(Material=opts.Material);
    Hc0    = nanFirst(opts.Hc0,  preset.Hc0);
    Tc     = nanFirst(opts.Tc,   preset.Tc);
    scType = preset.type;
else
    Hc0    = opts.Hc0;
    Tc     = opts.Tc;
    scType = '';   % determined later from kappa if not preset-loaded
    if isnan(Hc0) || isnan(Tc)
        error('calc:superconductor:missingParam', ...
              'Provide Hc0 and Tc, or a Material name.');
    end
end

T = opts.T;
if T >= Tc
    error('calc:superconductor:normalState', ...
          'T (%.4g K) must be below Tc (%.4g K).', T, Tc);
end

% ── Thermodynamic Hc ─────────────────────────────────────────────────
t  = T / Tc;
Hc = Hc0 * (1 - t^2);

% ── Type-II lower / upper critical fields ───────────────────────────
C    = calc.constants();
% Phi0 in CGS: 1 Wb = 1e8 G*cm^2; Gaussian CGS uses G and cm
Phi0_Gcm2 = C.Phi0 * 1e8;   % G*cm^2  (= 2.0678e-7 G*cm^2)

Hc1 = NaN;
Hc2 = NaN;

if strcmp(scType, 'II') || isnan(Hc0) || Hc0 == 0
    % Determine lambda and xi at T if not supplied
    lambda = opts.lambda;
    xi     = opts.xi;
    kappa  = opts.kappa;

    if isnan(lambda) && ~isempty(opts.Material)
        rL     = calc.superconductor.londonDepth(Material=opts.Material, T=T);
        lambda = rL.lambda;
    end
    if isnan(xi) && ~isempty(opts.Material)
        rX  = calc.superconductor.coherenceLength(Material=opts.Material, T=T);
        xi  = rX.xi;
    end

    if isnan(kappa) && ~isnan(lambda) && ~isnan(xi)
        kappa = lambda / xi;
    end

    % Need both lambda and xi (or kappa + one of them) for Hc1/Hc2
    if ~isnan(lambda) && ~isnan(xi)
        % Convert nm to cm: 1 nm = 1e-7 cm
        lam_cm = lambda * 1e-7;
        xi_cm  = xi    * 1e-7;

        if kappa > 1   % ln(kappa) is only meaningful for kappa >> 1
            Hc1 = (Phi0_Gcm2 * log(kappa)) / (4*pi * lam_cm^2);
        else
            Hc1 = Phi0_Gcm2 / (4*pi * sqrt(2) * lam_cm^2);
        end
        Hc2 = Phi0_Gcm2 / (2*pi * xi_cm^2);

        if isempty(scType)
            scType = 'II';
        end
    elseif isempty(scType)
        scType = 'II';
    end
end

if isempty(scType)
    scType = 'I';
end

% ── Assemble output ──────────────────────────────────────────────────
result.Hc   = Hc;
result.Hc1  = Hc1;
result.Hc2  = Hc2;
result.type = scType;
result.T    = T;
result.Tc   = Tc;

if strcmp(scType, 'I')
    result.latex = sprintf( ...
        '$H_c(%.4g\\,\\mathrm{K}) = %.4g\\,\\mathrm{Oe}$ (Type I)', T, Hc);
else
    if ~isnan(Hc1) && ~isnan(Hc2)
        result.latex = sprintf( ...
            '$H_{c1}=%.4g\\,\\mathrm{Oe},\\;H_c=%.4g\\,\\mathrm{Oe},\\;H_{c2}=%.4g\\,\\mathrm{Oe}$ at $%.4g\\,\\mathrm{K}$', ...
            Hc1, Hc, Hc2, T);
    else
        result.latex = sprintf( ...
            '$H_c(%.4g\\,\\mathrm{K}) = %.4g\\,\\mathrm{Oe}$ (Type II)', T, Hc);
    end
end
end

% ════════════════════════════════════════════════════════════════════

function out = nanFirst(explicit, fallback)
%NANFIRST  Return explicit value if not NaN, otherwise fallback.
    if ~isnan(explicit)
        out = explicit;
    else
        out = fallback;
    end
end
