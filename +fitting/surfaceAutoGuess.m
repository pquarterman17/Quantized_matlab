function p0 = surfaceAutoGuess(modelName, xData, yData, zData)
%SURFACEAUTOGUESS  Heuristic initial parameter estimation for 2D surface models.
%
%   Syntax
%     p0 = fitting.surfaceAutoGuess(modelName, xData, yData, zData)
%
%   Inputs
%     modelName — string matching a name in fitting.surfaceModels()
%     xData     — [N×1] x coordinate vector
%     yData     — [N×1] y coordinate vector
%     zData     — [N×1] z values
%
%   Output
%     p0 — [1×P] initial parameter row vector
%
%   If the model is not recognized or heuristics fail, falls back to
%   generic data-range estimates.

arguments
    modelName (1,1) string
    xData     (:,1) double
    yData     (:,1) double
    zData     (:,1) double
end

% ════════════════════════════════════════════════════════════════════════
% Validate model exists
% ════════════════════════════════════════════════════════════════════════
catalog = fitting.surfaceModels();
idx = find(strcmp({catalog.name}, modelName), 1);
if isempty(idx)
    error('fitting:surfaceAutoGuess:unknownModel', 'Model "%s" not found.', modelName);
end
nP = catalog(idx).nParams;

% ════════════════════════════════════════════════════════════════════════
% Data characteristics
% ════════════════════════════════════════════════════════════════════════
xMn = min(xData); xMx = max(xData); xRange = max(xMx - xMn, eps);
yMn = min(yData); yMx = max(yData); yRange = max(yMx - yMn, eps);
zMn = min(zData); zMx = max(zData); zRange = max(zMx - zMn, eps);
zMean = mean(zData);
N = numel(zData);

switch modelName

    % ── Plane ─────────────────────────────────────────────────────────
    case 'Plane'
        % Least-squares via normal equations: [x y 1] \ z
        A = [xData, yData, ones(N,1)];
        coeffs = A \ zData;
        p0 = coeffs(:)';
        if numel(p0) ~= nP; p0 = [0 0 zMean]; end

    % ── Paraboloid ────────────────────────────────────────────────────
    case 'Paraboloid'
        % Vandermonde matrix for z = a·x² + b·y² + c·xy + d·x + e·y + f
        A = [xData.^2, yData.^2, xData.*yData, xData, yData, ones(N,1)];
        try
            coeffs = A \ zData;
            p0 = coeffs(:)';
        catch
            p0 = [0 0 0 0 0 zMean];
        end
        if numel(p0) ~= nP; p0 = [0 0 0 0 0 zMean]; end

    % ── 2D Gaussian ───────────────────────────────────────────────────
    case '2D Gaussian'
        [zPk, pkI] = max(zData);
        amplitude  = zPk - zMn;
        x0 = xData(pkI);
        y0 = yData(pkI);
        % Weighted centroid for center refinement
        wts = max(zData - zMn, 0);
        wSum = max(sum(wts), eps);
        x0  = sum(wts .* xData) / wSum;
        y0  = sum(wts .* yData) / wSum;
        sx  = xRange / 4;
        sy  = yRange / 4;
        z0  = zMn;
        p0  = [amplitude, x0, sx, y0, sy, z0];

    % ── 2D Lorentzian ─────────────────────────────────────────────────
    case '2D Lorentzian'
        [zPk, pkI] = max(zData);
        amplitude  = zPk - zMn;
        wts = max(zData - zMn, 0);
        wSum = max(sum(wts), eps);
        x0  = sum(wts .* xData) / wSum;
        y0  = sum(wts .* yData) / wSum;
        wx  = xRange / 4;
        wy  = yRange / 4;
        z0  = zMn;
        p0  = [amplitude, x0, wx, y0, wy, z0];

    % ── 2D Pseudo-Voigt ───────────────────────────────────────────────
    case '2D Pseudo-Voigt'
        [zPk, ~] = max(zData);
        amplitude = zPk - zMn;
        wts = max(zData - zMn, 0);
        wSum = max(sum(wts), eps);
        x0  = sum(wts .* xData) / wSum;
        y0  = sum(wts .* yData) / wSum;
        wx  = xRange / 4;
        wy  = yRange / 4;
        z0  = zMn;
        eta = 0.5;
        p0  = [amplitude, x0, wx, y0, wy, z0, eta];

    % ── Polynomial 2D ─────────────────────────────────────────────────
    case 'Polynomial 2D'
        % Same as Paraboloid but different parameter ordering
        A = [ones(N,1), xData, yData, xData.^2, xData.*yData, yData.^2];
        try
            coeffs = A \ zData;
            p0 = coeffs(:)';
        catch
            p0 = [zMean 0 0 0 0 0];
        end
        if numel(p0) ~= nP; p0 = [zMean 0 0 0 0 0]; end

    % ── Exponential Decay 2D ──────────────────────────────────────────
    case 'Exponential Decay 2D'
        amplitude = zRange;
        tx = xRange / 3;
        ty = yRange / 3;
        z0 = zMn;
        p0 = [amplitude, tx, ty, z0];

    % ── Unknown — generic fallback ────────────────────────────────────
    otherwise
        p0 = ones(1, nP);
        if nP >= 1; p0(1) = zRange; end     % amplitude-like
        if nP >= 2; p0(2) = (xMn + xMx)/2; end  % x-center
        if nP >= 3; p0(3) = xRange/4; end        % x-width
        if nP >= 4; p0(4) = (yMn + yMx)/2; end  % y-center
        if nP >= 5; p0(5) = yRange/4; end        % y-width
        if nP >= 6; p0(6) = zMn; end             % offset
end

end
