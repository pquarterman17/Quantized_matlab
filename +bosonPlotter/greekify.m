function s = greekify(s)
%GREEKIFY  Replace spelled-out Greek letter names with Unicode characters.
%   s = bosonPlotter.greekify(s)
%
%   Rules:
%     - Case-insensitive: "theta", "Theta", "THETA" all → "θ"
%     - Boundary-guarded: only replaces when not immediately surrounded by
%       other letters, so "formula" is safe (mu not matched) but "2theta",
%       "mu0", and "phi_1" are converted correctly.
%     - Longest names first to prevent partial matches (e.g. "epsilon"
%       before "si", "beta"/"theta"/"zeta" before "eta";
%       "degrees" before "degree" before "deg").

    if isempty(s), return; end
    s = char(string(s));

    pairs = {
        'degrees', '°';   % 7 — before "degree" so plural is caught first
        'epsilon', 'ε';   % 7
        'degree',  '°';   % 6 — before "deg"
        'lambda',  'λ';   % 6
        'omega',   'ω';   % 5
        'theta',   'θ';   % 5
        'sigma',   'σ';   % 5
        'alpha',   'α';   % 5
        'gamma',   'γ';   % 5
        'delta',   'δ';   % 5
        'kappa',   'κ';   % 5
        'beta',    'β';   % 4
        'zeta',    'ζ';   % 4
        'phi',     'φ';   % 3
        'chi',     'χ';   % 3
        'psi',     'ψ';   % 3
        'tau',     'τ';   % 3
        'rho',     'ρ';   % 3
        'deg',     '°';   % 3 — after "degree"/"degrees"
        'eta',     'η';   % 3
        'mu',      'μ';   % 2
        'nu',      'ν';   % 2
        'xi',      'ξ';   % 2
        'pi',      'π';   % 2
    };
    for k = 1:size(pairs, 1)
        pat = ['(?i)(?<![a-zA-Z])', pairs{k,1}, '(?![a-zA-Z])'];
        s   = regexprep(s, pat, pairs{k,2});
    end
end
