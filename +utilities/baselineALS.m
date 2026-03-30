function [baseline, params] = baselineALS(y, options)
%BASELINEALS  Asymmetric Least Squares baseline estimation.
%
%   [baseline, params] = utilities.baselineALS(y)
%   [baseline, params] = utilities.baselineALS(y, 'Lambda', 1e7, 'P', 0.001)
%
%   Estimates a smooth baseline beneath a signal using the Asymmetric
%   Least Squares (ALS) algorithm of Eilers & Boelens (2005).  The method
%   penalises roughness (via a second-difference penalty weighted by
%   Lambda) while asymmetrically weighting residuals: points above the
%   current estimate are down-weighted (weight = P), while points below
%   receive weight (1 - P).  This causes the baseline to preferentially
%   track the lower envelope of the signal.
%
%   The linear system solved at each iteration is:
%       (W + Lambda * D'*D) * z = W * y
%   where D is the second-difference matrix, W = diag(w), and the weights
%   are updated iteratively until convergence.
%
%   This is the gold standard for background subtraction in XRD, Raman
%   spectroscopy, and EELS data.
%
%   Inputs:
%       y — [N×1] numeric signal vector
%
%   Name-Value Options:
%       Lambda  — smoothness penalty (default 1e6). Larger = smoother.
%       P       — asymmetry parameter, 0 < p < 1 (default 0.01).
%                 Smaller = stronger asymmetry (baseline sinks lower).
%       MaxIter — maximum iterations (default 20)
%       Tol     — convergence tolerance on max weight change (default 1e-6)
%
%   Outputs:
%       baseline — [N×1] estimated baseline
%       params   — struct with fields:
%                   .lambda    — smoothness penalty used
%                   .p         — asymmetry parameter used
%                   .nIter     — number of iterations performed
%                   .converged — true if converged before MaxIter
%
%   Examples:
%       % Subtract baseline from a Raman spectrum
%       bl = utilities.baselineALS(spectrum, 'Lambda', 1e5, 'P', 0.01);
%       corrected = spectrum - bl;
%
%   References:
%       P.H.C. Eilers & H.F.M. Boelens, "Baseline Estimation by Weighted
%       Smoothing" (2005), Leiden University Medical Centre report.
%
%   See also utilities.estimateBackground, utilities.smoothData

% ════════════════════════════════════════════════════════════════════════
%  Input validation
% ════════════════════════════════════════════════════════════════════════
    arguments
        y        (:,1) double
        options.Lambda  (1,1) double {mustBePositive}              = 1e6
        options.P       (1,1) double {mustBeGreaterThan(options.P,0), ...
                                      mustBeLessThan(options.P,1)} = 0.01
        options.MaxIter (1,1) double {mustBePositive, mustBeInteger} = 20
        options.Tol     (1,1) double {mustBePositive}              = 1e-6
    end

    N = numel(y);

% ════════════════════════════════════════════════════════════════════════
%  Trivial cases
% ════════════════════════════════════════════════════════════════════════
    if N < 3
        baseline = y;
        params = struct('lambda', options.Lambda, 'p', options.P, ...
                        'nIter', 0, 'converged', true);
        return;
    end

% ════════════════════════════════════════════════════════════════════════
%  Build sparse second-difference matrix D  [size (N-2) × N]
% ════════════════════════════════════════════════════════════════════════
    m = N - 2;
    e = ones(m, 1);
    % D has [1  -2  1] on each row, shifted by one column
    D = spdiags([e  -2*e  e], [0 1 2], m, N);

    % Precompute D'*D (banded, N×N, bandwidth 4)
    DtD = D' * D;

% ════════════════════════════════════════════════════════════════════════
%  Iterative reweighted solve
% ════════════════════════════════════════════════════════════════════════
    lam = options.Lambda;
    p   = options.P;

    % Initial weights: uniform
    w = ones(N, 1);

    z = y;  % initial baseline estimate
    converged = false;

    for iter = 1:options.MaxIter
        % Build weighted system and solve
        W = spdiags(w, 0, N, N);
        C = W + lam * DtD;

        % Use Cholesky factorization for symmetric positive definite system
        % C is SPD because W has positive diagonal and DtD is positive semi-definite
        try
            R = chol(C);         % C = R'*R
            z = R \ (R' \ (w .* y));
        catch
            % Fallback to direct solve if Cholesky fails (shouldn't happen)
            z = C \ (w .* y);
        end

        % Update asymmetric weights
        wNew = p * (y > z) + (1 - p) * (y <= z);

        % Convergence check
        if max(abs(wNew - w)) < options.Tol
            converged = true;
            w = wNew;
            break;
        end
        w = wNew;
    end

% ════════════════════════════════════════════════════════════════════════
%  Output
% ════════════════════════════════════════════════════════════════════════
    baseline = z;

    params = struct('lambda', lam, 'p', p, ...
                    'nIter', iter, 'converged', converged);
end
