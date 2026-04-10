function result = pcaAnalysis(X, options)
%PCAANALYSIS  Principal component analysis via SVD (no Statistics Toolbox).
%
%   result = utilities.pcaAnalysis(X)
%   result = utilities.pcaAnalysis(X, Center=true, Scale=true)
%   result = utilities.pcaAnalysis(X, NumComponents=3)
%
%   Inputs:
%       X — [n×p] data matrix, rows are observations, columns are variables.
%
%   Options:
%       Center        — subtract column means before SVD (default: true)
%       Scale         — also divide by column std-dev → correlation-based
%                       PCA (default: false → covariance-based)
%       NumComponents — truncate output to the top-k components (default: all)
%
%   Output (struct):
%       .coeff      — [p×k] principal component loadings (unit columns).
%                     Column j is the direction of PC j in variable space.
%       .score      — [n×k] observation scores in PC space
%                     (score = X_centered * coeff).
%       .latent     — [k×1] eigenvalues of the covariance matrix =
%                     variance captured by each PC (sv.^2 / (n-1)).
%       .explained  — [k×1] percent of total variance explained by each PC.
%       .cumulative — [k×1] cumulative percent explained.
%       .mu         — [1×p] column means subtracted (zeros if Center=false).
%       .sigma      — [1×p] column std-devs used (ones if Scale=false).
%       .singular   — [k×1] singular values (sqrt(latent * (n-1))).
%
%   Notes:
%       Uses `svd(Xc, 'econ')` which is numerically stable and works even
%       when n < p (more variables than observations). This is the same
%       method as MATLAB's Statistics Toolbox `pca`, but implemented with
%       built-ins only so the toolbox dependency is avoided.
%
%       Sign convention: the largest-magnitude element of each PC loading
%       is forced positive, so results are reproducible across platforms
%       (SVD sign is otherwise arbitrary).
%
%   Example:
%       load fisheriris;   % if available — else any [n×p] matrix
%       r = utilities.pcaAnalysis(meas);
%       fprintf('PC1 explains %.1f%%, PC2 %.1f%%\n', ...
%           r.explained(1), r.explained(2));
%       scatter(r.score(:,1), r.score(:,2));
%
%   See also: utilities.linRegress, utilities.descriptiveStats, svd

arguments
    X (:,:) double
    options.Center        (1,1) logical = true
    options.Scale         (1,1) logical = false
    options.NumComponents (1,1) double {mustBeNonnegative,mustBeInteger} = 0
end

if isempty(X)
    error('utilities:pcaAnalysis:emptyInput', 'X must be non-empty.');
end

[n, p] = size(X);
if n < 2
    error('utilities:pcaAnalysis:tooFewRows', ...
        'Need at least 2 observations (rows), got %d.', n);
end

% ════════════════════════════════════════════════════════════════════════
% Center and (optionally) scale
% ════════════════════════════════════════════════════════════════════════
if options.Center
    mu = mean(X, 1);
else
    mu = zeros(1, p);
end
Xc = X - mu;

if options.Scale
    sigma = std(Xc, 0, 1);
    sigma(sigma == 0) = 1;   % avoid divide-by-zero on constant columns
    Xc = Xc ./ sigma;
else
    sigma = ones(1, p);
end

% ════════════════════════════════════════════════════════════════════════
% Economy SVD:  Xc = U * S * V'     →  coeff = V,  score = U * S
% ════════════════════════════════════════════════════════════════════════
[U, S, V] = svd(Xc, 'econ');
sv = diag(S);

% Eigenvalues of the sample covariance matrix
latent = (sv.^2) / max(n - 1, 1);

totalVar = sum(latent);
if totalVar == 0
    explained = zeros(size(latent));
else
    explained = 100 * latent / totalVar;
end

score = U .* sv';   % equivalent to U * S but avoids forming the diagonal

% Deterministic sign: flip each PC so its largest-magnitude loading is +
for j = 1:size(V, 2)
    [~, idx] = max(abs(V(:, j)));
    if V(idx, j) < 0
        V(:, j)     = -V(:, j);
        score(:, j) = -score(:, j);
    end
end

% ════════════════════════════════════════════════════════════════════════
% Optional truncation
% ════════════════════════════════════════════════════════════════════════
k = numel(latent);
if options.NumComponents > 0
    k = min(options.NumComponents, k);
    V         = V(:, 1:k);
    score     = score(:, 1:k);
    latent    = latent(1:k);
    explained = explained(1:k);
    sv        = sv(1:k);
end

result.coeff      = V;
result.score      = score;
result.latent     = latent;
result.explained  = explained;
result.cumulative = cumsum(explained);
result.mu         = mu;
result.sigma      = sigma;
result.singular   = sv;

end
