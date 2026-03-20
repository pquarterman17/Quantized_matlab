function result = butlerVolmer(j0, eta, opts)
%BUTLERVOLMER  Compute electrode current density via the Butler-Volmer equation.
%
%   Syntax
%   ------
%   result = calc.electrochemistry.butlerVolmer(j0, eta)
%   result = calc.electrochemistry.butlerVolmer(j0, eta, alpha=alpha, T=T)
%
%   Inputs
%   ------
%   j0    — exchange current density (A/cm^2)
%   eta   — overpotential (V); positive = anodic
%   alpha — transfer coefficient (dimensionless, 0 < alpha < 1); default = 0.5
%   T     — temperature (K); default = 298.15
%
%   Outputs
%   -------
%   result — struct with fields:
%     .j         — total current density (A/cm^2)
%     .jAnodic   — anodic partial current density (A/cm^2)
%     .jCathodic — cathodic partial current density (A/cm^2)
%     .jTafel    — Tafel approximation j ≈ j0*exp(alpha*F*eta/(R*T)) (A/cm^2)
%                  (valid when |eta| >> R*T/F, i.e. large anodic overpotentials)
%     .latex     — LaTeX-formatted result string
%
%   Examples
%   --------
%   r = calc.electrochemistry.butlerVolmer(1e-6, 0.1);
%   r = calc.electrochemistry.butlerVolmer(1e-6, 0.2, alpha=0.4, T=333);

% ════════════════════════════════════════════════════════════════════

arguments
    j0    (1,1) double {mustBePositive}
    eta   (1,1) double
    opts.alpha (1,1) double {mustBeGreaterThan(opts.alpha, 0), mustBeLessThan(opts.alpha, 1)} = 0.5
    opts.T     (1,1) double {mustBePositive}                                                  = 298.15
end

C = calc.constants();

alpha = opts.alpha;
T     = opts.T;

fOverRT = C.F / (C.R * T);

jAnodic   =  j0 * exp( alpha       * fOverRT * eta);
jCathodic = -j0 * exp(-(1 - alpha) * fOverRT * eta);
j         = jAnodic + jCathodic;
jTafel    =  j0 * exp( alpha       * fOverRT * eta);

result.j         = j;
result.jAnodic   = jAnodic;
result.jCathodic = jCathodic;
result.jTafel    = jTafel;
result.latex     = sprintf('$j = %.4g\\,\\text{A/cm}^2$', j);
end
