function result = mcmcSample(logPosterior, initialParams, options)
%MCMCSAMPLE  Affine-invariant MCMC sampler for nonlinear fit uncertainty.
%
%   TODO: scaffold only — this is a minimal random-walk Metropolis
%   implementation. The production target is an affine-invariant
%   (emcee-style) ensemble sampler so reflectivity fits with strongly
%   correlated parameters (thickness × SLD × roughness) get reasonable
%   mixing without hand-tuning step sizes. See docs/theory/fitting.md
%   "MCMC posterior sampling" section for the full plan.
%
%   Syntax
%   ------
%       result = fitting.mcmcSample(logPosterior, initialParams)
%       result = fitting.mcmcSample(logPosterior, initialParams, ...
%                   NumSteps=10000, BurnIn=1000, Thin=5, ...
%                   StepSize=0.05, Seed=42)
%
%   Inputs
%   ------
%   logPosterior   function_handle — takes a 1×P parameter vector and
%                  returns a scalar log-posterior (log-likelihood +
%                  log-prior). Return -Inf for out-of-prior parameters.
%   initialParams  1×P vector of starting-point parameter values. For
%                  multi-walker ensemble use, pass an N×P matrix where
%                  each row is one walker (TODO: not yet implemented).
%
%   Options
%   -------
%   NumSteps  (default 10000)  Number of MCMC steps.
%   BurnIn    (default 1000)   Steps to discard from the start.
%   Thin      (default 1)      Keep every Thin-th sample post burn-in.
%   StepSize  (default 0.05)   Gaussian proposal scale (fraction of |p|).
%   Seed      (default [])     RNG seed for reproducibility. Empty = no seed.
%
%   Outputs
%   -------
%   result — struct with fields:
%     .samples        — [N × P] post-burn-in, thinned parameter samples
%     .logPosterior   — [N × 1] log-posterior at each sample
%     .acceptRate     — scalar acceptance fraction (target 0.2–0.5)
%     .diagnostic     — struct with `nSteps`, `nAccepted`, `ess` (effective
%                       sample size placeholder), `rHat` (TODO: Gelman-Rubin)
%
%   Notes
%   -----
%   * This initial implementation is single-chain random-walk Metropolis
%     with Gaussian proposal. Parameter correlations are NOT handled;
%     acceptance collapses for dimensions > ~5 or when the posterior is
%     strongly ridged (common for reflectivity).
%   * Replace with affine-invariant ensemble (Goodman & Weare 2010)
%     before declaring the feature complete.
%   * No convergence diagnostics yet (no R-hat, no autocorrelation).
%
%   Example
%   -------
%   % Fit a 1D Gaussian: p = [mu, sigma], data ~ N(0, 1)
%   x   = randn(100, 1);
%   lp  = @(p) -sum((x - p(1)).^2) / (2*p(2)^2) - ...
%              100 * log(p(2)) - 0.5 * p(1)^2 / 10^2;   % loose prior
%   r   = fitting.mcmcSample(lp, [0.5, 0.8], NumSteps=5000, BurnIn=500);
%   fprintf('mu    = %.3f ± %.3f\n', mean(r.samples(:,1)), std(r.samples(:,1)));
%   fprintf('sigma = %.3f ± %.3f\n', mean(r.samples(:,2)), std(r.samples(:,2)));
%
%   References
%   ----------
%   Goodman, J. & Weare, J., "Ensemble samplers with affine invariance",
%     Commun. Appl. Math. Comput. Sci. 5, 65 (2010).
%   Foreman-Mackey, D. et al., "emcee: the MCMC Hammer",
%     PASP 125, 306 (2013). DOI: 10.1086/670067
%
%   See also fitting.curveFit, plotting.cornerPlot

% ════════════════════════════════════════════════════════════════════════
%  Arguments
% ════════════════════════════════════════════════════════════════════════
arguments
    logPosterior             function_handle
    initialParams            (1,:) double {mustBeNonempty}
    options.NumSteps  (1,1)  double  {mustBeInteger, mustBePositive} = 10000
    options.BurnIn    (1,1)  double  {mustBeInteger, mustBeNonnegative} = 1000
    options.Thin      (1,1)  double  {mustBeInteger, mustBePositive} = 1
    options.StepSize  (1,1)  double  {mustBePositive} = 0.05
    options.Seed             double  = []
end

if ~isempty(options.Seed)
    rng(options.Seed);
end

P = numel(initialParams);
N = options.NumSteps;

chain    = zeros(N, P);
logPost  = zeros(N, 1);
chain(1, :) = initialParams(:)';
logPost(1)  = logPosterior(initialParams(:)');

% Proposal scale. Uniform StepSize in every dimension (users can tune
% per-dimension step sizes by passing a vector when the ensemble
% sampler lands). Using a fraction-of-|p| rule would collapse when
% any initial param is near zero.
propScale = options.StepSize * ones(1, P);

nAccepted = 0;
for k = 2:N
    prop = chain(k - 1, :) + randn(1, P) .* propScale;
    lpProp = logPosterior(prop);
    logRatio = lpProp - logPost(k - 1);
    if log(rand()) < logRatio
        chain(k, :) = prop;
        logPost(k)  = lpProp;
        nAccepted   = nAccepted + 1;
    else
        chain(k, :) = chain(k - 1, :);
        logPost(k)  = logPost(k - 1);
    end
end

% Burn-in + thinning
keepIdx  = (options.BurnIn + 1):options.Thin:N;
samples  = chain(keepIdx, :);
lpKept   = logPost(keepIdx);

% ── Diagnostics ───────────────────────────────────────────────────────
nKept = numel(keepIdx);
% Effective sample size via integrated autocorrelation time (Sokal 1997).
% All P parameters are processed in a single batched FFT pass rather than
% calling xcorr() in a per-parameter loop.  For each column the normalised
% autocorrelation is the inverse FFT of |FFT(z)|^2 / nKept^2, where z is
% the mean-centred chain.  This is numerically equivalent to xcorr(z,'normalized')
% but avoids repeated FFT setup and MATLAB function-call overhead.
essPerDim = zeros(1, P);
nfft  = 2^nextpow2(2 * nKept - 1);   % zero-pad to avoid circular wrap
Z     = samples - mean(samples, 1);   % [nKept × P] mean-centred

% Columns that are all-zero get ESS = nKept immediately.
zeroMask = all(Z == 0, 1);
essPerDim(zeroMask) = nKept;

if any(~zeroMask)
    Zactive = Z(:, ~zeroMask);
    F       = fft(Zactive, nfft, 1);          % FFT along rows (lags)
    acFull  = real(ifft(F .* conj(F), [], 1));% [nfft × Pactive] power
    % Normalise each column by its zero-lag value (= variance * nKept)
    acFull  = acFull ./ acFull(1, :);
    % Keep only the positive-lag half [lags 1 … nKept-1]
    acPos   = acFull(2:nKept, :);             % [nKept-1 × Pactive]
    % Integrated autocorrelation: tau = 1 + 2 * sum of positive ac values
    % above the 0.05 threshold (matching the original per-parameter logic).
    tauVec  = 1 + 2 * sum(acPos .* (acPos > 0.05), 1);
    essPerDim(~zeroMask) = nKept ./ max(tauVec, 1);
end

result.samples       = samples;
result.logPosterior  = lpKept;
result.acceptRate    = nAccepted / (N - 1);
result.diagnostic    = struct( ...
    'nSteps',     N, ...
    'nAccepted',  nAccepted, ...
    'ess',        essPerDim, ...
    'rHat',       NaN, ...               % TODO: Gelman-Rubin across chains
    'sampler',    'random-walk-metropolis (TODO: upgrade to affine-invariant)');
end
