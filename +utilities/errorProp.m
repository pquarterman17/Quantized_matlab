function result = errorProp(func, values, errors, Options)
%ERRORPROP  Propagate uncertainties through an arbitrary function.
%
%   Syntax:
%       result = utilities.errorProp(func, values, errors)
%       result = utilities.errorProp(func, values, errors, Method="montecarlo")
%       result = utilities.errorProp(func, values, errors, Correlated=C)
%
%   Inputs:
%       func   — function handle f(x1, x2, ..., xN) → scalar or vector
%       values — [1×N] cell or numeric array of input values
%       errors — [1×N] cell or numeric array of uncertainties (std dev,
%                same shape as corresponding values entry)
%
%   Options:
%       Method     — "linear" (default) | "montecarlo"
%       NSamples   — Monte Carlo sample count (default 10000)
%       Correlated — [N×N] correlation matrix (default eye(N))
%       Confidence — confidence level for MC intervals (default 0.95)
%
%   Outputs:
%       result — struct with fields:
%           .value     — f(values{:}) evaluated at the input means
%           .error     — propagated uncertainty (std dev)
%           .relError  — relative uncertainty (error ./ |value|)
%           .formula   — string describing propagation (linear method only)
%           .ci        — [lo, hi] confidence interval (MC method only)
%           .partials  — [1×N] partial derivatives (linear method only)
%
%   Examples:
%       % Propagate through f = a*b
%       r = utilities.errorProp(@(a,b) a.*b, {3.0, 4.0}, {0.1, 0.2});
%       fprintf('Result: %.3f +/- %.3f\n', r.value, r.error);
%
%       % Monte Carlo with correlated inputs
%       C = [1, 0.5; 0.5, 1];
%       r = utilities.errorProp(@(a,b) a+b, {1,1}, {0.1,0.1}, ...
%           Method="montecarlo", Correlated=C);
%
%   See also utilities.errorAdd, utilities.errorMul, utilities.errorDiv,
%            utilities.errorFunc

arguments
    func     (1,1) function_handle
    values
    errors
    Options.Method     (1,1) string  {mustBeMember(Options.Method, ["linear","montecarlo"])} = "linear"
    Options.NSamples   (1,1) double  {mustBePositive, mustBeInteger} = 10000
    Options.Correlated double = []
    Options.Confidence (1,1) double = 0.95
end

% ════════════════════════════════════════════════════════════════════════
% Normalise inputs to cell arrays
% ════════════════════════════════════════════════════════════════════════

if isnumeric(values)
    values = num2cell(values);
end
if isnumeric(errors)
    errors = num2cell(errors);
end

N = numel(values);
if numel(errors) ~= N
    error('utilities:errorProp:sizeMismatch', ...
        'values and errors must have the same number of elements.');
end

% Validate correlation matrix
if isempty(Options.Correlated)
    corrMat = eye(N);
else
    corrMat = Options.Correlated;
    if ~isequal(size(corrMat), [N, N])
        error('utilities:errorProp:badCorrelation', ...
            'Correlated must be [%d×%d], got [%d×%d].', ...
            N, N, size(corrMat,1), size(corrMat,2));
    end
end

% Evaluate function at nominal values
nomValue = func(values{:});

% ════════════════════════════════════════════════════════════════════════
% Dispatch by method
% ════════════════════════════════════════════════════════════════════════

switch Options.Method
    case "linear"
        result = propagateLinear(func, values, errors, corrMat, nomValue, N);
    case "montecarlo"
        result = propagateMC(func, values, errors, corrMat, nomValue, N, ...
            Options.NSamples, Options.Confidence);
end

end % errorProp


% ════════════════════════════════════════════════════════════════════════
% Linear (first-order Taylor) propagation
% ════════════════════════════════════════════════════════════════════════

function result = propagateLinear(func, values, errors, corrMat, nomValue, N)

% Compute partial derivatives via central differences
partials = cell(1, N);
for i = 1:N
    xi    = values{i};
    sigma = errors{i};

    % Step size: relative if possible, absolute fallback
    h = max(abs(xi) * 1e-7, 1e-10);

    % Perturbed argument lists
    valFwd = values;
    valBwd = values;
    valFwd{i} = xi + h;
    valBwd{i} = xi - h;

    fFwd = func(valFwd{:});
    fBwd = func(valBwd{:});

    partials{i} = (fFwd - fBwd) ./ (2 .* h);
end

% Variance via full covariance: sigma_f^2 = sum_ij dfi * dfj * cov_ij
% cov_ij = corr_ij * sigma_i * sigma_j
varF = zeros(size(nomValue));
for i = 1:N
    for j = 1:N
        covij = corrMat(i,j) .* errors{i} .* errors{j};
        varF  = varF + partials{i} .* partials{j} .* covij;
    end
end

propError = sqrt(max(varF, 0));

% Relative error (guard against zero value)
relErr = propError ./ max(abs(nomValue), eps);

% Build readable formula string (for scalar case)
parts = cell(1, N);
for i = 1:N
    if isscalar(partials{i})
        parts{i} = sprintf('(df/dx%d=%.4g)^2*(%.4g)^2', ...
            i, partials{i}, errors{i});
    else
        parts{i} = sprintf('(df/dx%d)*^2*(sigma%d)^2 [vector]', i, i);
    end
end
formula = ['sigma_f^2 = ', strjoin(parts, ' + ')];

% Flatten partials for output
partialsOut = cell2mat(cellfun(@(p) p(:)', partials, 'UniformOutput', false));

result.value    = nomValue;
result.error    = propError;
result.relError = relErr;
result.formula  = formula;
result.ci       = [];
result.partials = partialsOut;

end


% ════════════════════════════════════════════════════════════════════════
% Monte Carlo propagation
% ════════════════════════════════════════════════════════════════════════

function result = propagateMC(func, values, errors, corrMat, nomValue, N, nSamples, confidence)

rng(42);  % reproducible results

% Build covariance matrix from correlations and std devs
% Only supported for scalar inputs in full MC mode
allScalar = true;
for i = 1:N
    if ~isscalar(values{i})
        allScalar = false;
        break;
    end
end

if ~allScalar
    error('utilities:errorProp:mcVectorInput', ...
        'Monte Carlo method requires scalar inputs. Use Method="linear" for vector inputs.');
end

sigmas = cellfun(@double, errors);
means  = cellfun(@double, values);

% Covariance = diag(sigma) * corrMat * diag(sigma)
covMat = corrMat .* (sigmas(:) * sigmas(:)');

% Cholesky decomposition for correlated sampling
% Add small jitter for numerical stability
covMat = (covMat + covMat') / 2;
[L, flag] = chol(covMat, 'lower');
if flag ~= 0
    % Fall back to diagonal (uncorrelated) if not positive definite
    warning('utilities:errorProp:cholFailed', ...
        'Covariance matrix not positive definite; using diagonal approximation.');
    L = diag(sigmas(:));
end

% Draw samples: [N × nSamples]
Z       = randn(N, nSamples);
samples = bsxfun(@plus, means(:), L * Z);  % [N × nSamples]

% Evaluate function on all samples
fSamples = zeros(1, nSamples);
argCell  = cell(1, N);
for s = 1:nSamples
    for i = 1:N
        argCell{i} = samples(i, s);
    end
    fSamples(s) = func(argCell{:});
end

% Statistics
mcMean  = mean(fSamples);
mcStd   = std(fSamples);
relErr  = mcStd / max(abs(mcMean), eps);

alpha   = 1 - confidence;
loCI    = prctile(fSamples, 100 * alpha/2);
hiCI    = prctile(fSamples, 100 * (1 - alpha/2));

result.value    = nomValue;
result.error    = mcStd;
result.relError = relErr;
result.formula  = sprintf('Monte Carlo (N=%d, conf=%.0f%%)', nSamples, confidence*100);
result.ci       = [loCI, hiCI];
result.partials = [];

end
