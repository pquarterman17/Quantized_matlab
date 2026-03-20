function result = nernstPotential(E0, n, Q, opts)
%NERNSTPOTENTIAL  Compute equilibrium electrode potential via the Nernst equation.
%
%   Syntax
%   ------
%   result = calc.electrochemistry.nernstPotential(E0, n, Q)
%   result = calc.electrochemistry.nernstPotential(E0, n, Q, T=T)
%
%   Inputs
%   ------
%   E0  — standard electrode potential (V)
%   n   — number of electrons transferred (positive integer)
%   Q   — reaction quotient (dimensionless; use activities or concentration ratios)
%   T   — temperature (K); default = 298.15
%
%   Outputs
%   -------
%   result — struct with fields:
%     .E      — equilibrium potential (V)
%     .E0     — standard potential as supplied (V)
%     .n      — number of electrons
%     .Q      — reaction quotient
%     .T      — temperature (K)
%     .latex  — LaTeX-formatted result string
%
%   Examples
%   --------
%   r = calc.electrochemistry.nernstPotential(1.23, 2, 1e-4);
%   r = calc.electrochemistry.nernstPotential(0.34, 2, 0.01, T=310);

% ════════════════════════════════════════════════════════════════════

arguments
    E0   (1,1) double
    n    (1,1) double {mustBePositive}
    Q    (1,1) double {mustBePositive}
    opts.T (1,1) double {mustBePositive} = 298.15
end

C = calc.constants();

T = opts.T;
E = E0 - (C.R * T) / (n * C.F) * log(Q);

result.E     = E;
result.E0    = E0;
result.n     = n;
result.Q     = Q;
result.T     = T;
result.latex = sprintf('$E = %.4g\\,\\text{V}$', E);
end
