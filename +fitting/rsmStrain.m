function result = rsmStrain(Qsub, Qfilm, options)
%RSMSTRAIN  Strain and relaxation from a substrate/film pair in an RSM.
%
%   Syntax
%     s = fitting.rsmStrain([Qx_sub, Qz_sub], [Qx_film, Qz_film])
%     s = fitting.rsmStrain(sub, film, Bulk=[Qx0_film, Qz0_film])
%
%   Inputs
%     Qsub    — [1×2] substrate peak centre in reciprocal-space [Qx, Qz] (Å⁻¹)
%     Qfilm   — [1×2] film peak centre in reciprocal-space [Qx, Qz] (Å⁻¹)
%
%   Options
%     Bulk    — [1×2] bulk (relaxed) film position [Qx, Qz] (Å⁻¹). When
%               given, enables relaxation calculation. If omitted, the
%               substrate position is used as the pseudomorphic reference
%               (R = 0 when film.Qx = sub.Qx).
%
%   Output — struct with
%     .eps_parallel    — in-plane strain ε∥ = (a_film∥ - a_sub∥) / a_sub∥
%     .eps_perp        — out-of-plane strain ε⊥ = (a_film⊥ - a_sub⊥) / a_sub⊥
%     .a_sub_parallel  — substrate in-plane lattice (Å); proportional to 1/Qx_sub
%     .a_sub_perp      — substrate out-of-plane lattice (Å); proportional to 1/Qz_sub
%     .a_film_parallel — film in-plane lattice (Å)
%     .a_film_perp     — film out-of-plane lattice (Å)
%     .relaxation      — R in [0, 1] (only finite when Bulk supplied; else NaN)
%                         R = (Qx_film - Qx_sub) / (Qx_bulk - Qx_sub)
%                         R = 0 → fully strained (pseudomorphic)
%                         R = 1 → fully relaxed
%
%   Method
%   ─────────────────────────────
%   For a reciprocal-lattice point (hkl), a* = 2π/a so Q is inversely
%   proportional to the real-space lattice parameter for a fixed Miller
%   index. The in-plane lattice a∥ scales as 1/Qx and the out-of-plane
%   lattice a⊥ scales as 1/Qz (same (hkl) used for both peaks). The
%   absolute scale drops out of the strain ratios:
%
%       ε∥ = (a_film∥ - a_sub∥) / a_sub∥ = Qx_sub/Qx_film - 1
%       ε⊥ = (a_film⊥ - a_sub⊥) / a_sub⊥ = Qz_sub/Qz_film - 1
%
%   Relaxation measures how far the film has departed from pseudomorphism
%   (Qx_film = Qx_sub) toward its bulk (relaxed) Qx:
%
%       R = (Qx_film - Qx_sub) / (Qx_bulk - Qx_sub)
%
%   The returned absolute lattices use a nominal a_sub = 2π/|Qsub|, just
%   to give a sensible scale; only the ratios are physically meaningful
%   when no (hkl) is known to the caller.
%
%   Example
%     result = fitting.rsmAnalyze(map);
%     s = fitting.rsmStrain(result.peaks(1).centre_Q, ...
%                           result.peaks(2).centre_Q);
%     fprintf('ε∥ = %+0.3f %%,  ε⊥ = %+0.3f %%\n', ...
%             100*s.eps_parallel, 100*s.eps_perp);
%
%   See also fitting.rsmAnalyze.

    arguments
        Qsub   (1,2) double {mustBeFinite}
        Qfilm  (1,2) double {mustBeFinite}
        options.Bulk (1,2) double = [NaN NaN]
    end

    Qx_sub  = Qsub(1);   Qz_sub  = Qsub(2);
    Qx_film = Qfilm(1);  Qz_film = Qfilm(2);

    if Qz_sub == 0 || Qz_film == 0
        error('fitting:rsmStrain:zeroQz', ...
            'Qz must be non-zero for both peaks (got sub=%.4g, film=%.4g).', ...
            Qz_sub, Qz_film);
    end

    % Strain via Q ratios (no Miller indices required)
    if Qx_sub == 0 || Qx_film == 0
        eps_par = NaN;       % symmetric reflection — no in-plane information
    else
        eps_par = Qx_sub / Qx_film - 1;
    end
    eps_perp = Qz_sub / Qz_film - 1;

    % Nominal absolute lattices (|Q| = 2π/a for any (hkl); consistent ratios)
    a_sub_par  = 2*pi / max(abs(Qx_sub), eps);
    a_sub_perp = 2*pi / abs(Qz_sub);
    a_film_par  = 2*pi / max(abs(Qx_film), eps);
    a_film_perp = 2*pi / abs(Qz_film);

    % Relaxation
    if all(isfinite(options.Bulk))
        Qx_bulk = options.Bulk(1);
        denom   = Qx_bulk - Qx_sub;
        if denom == 0
            R = NaN;   % bulk coincides with substrate → R undefined
        else
            R = (Qx_film - Qx_sub) / denom;
        end
    else
        R = NaN;
    end

    result.eps_parallel    = eps_par;
    result.eps_perp        = eps_perp;
    result.a_sub_parallel  = a_sub_par;
    result.a_sub_perp      = a_sub_perp;
    result.a_film_parallel = a_film_par;
    result.a_film_perp     = a_film_perp;
    result.relaxation      = R;
end
