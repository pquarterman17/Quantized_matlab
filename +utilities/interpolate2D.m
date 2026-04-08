function result = interpolate2D(x, y, z, xq, yq, Options)
%INTERPOLATE2D  Interpolate scattered or gridded 2-D data at query points.
%
%   Syntax:
%       result = utilities.interpolate2D(x, y, z, xq, yq)
%       result = utilities.interpolate2D(x, y, z, xq, yq, Method="natural")
%       result = utilities.interpolate2D(x, y, z, xq, yq, Method="thinplate")
%       result = utilities.interpolate2D(x, y, z, xq, yq, Method="idw", IDWPower=3)
%
%   Inputs:
%       x, y  — coordinate arrays.  Either:
%                 [N×1] scattered point vectors, or
%                 [Ny×Nx] matrices from meshgrid (gridded input).
%       z     — data values, same size as x and y.
%       xq    — query x-coordinates (vector or meshgrid matrix).
%       yq    — query y-coordinates, same size as xq.
%
%   Options:
%       Method        — "linear"    — piecewise-linear triangulation
%                       "natural"   — natural-neighbour C1 interpolation (default)
%                       "nearest"   — nearest-neighbour
%                       "cubic"     — same as "natural" (C1 cubic for scattered data)
%                       "thinplate" — thin-plate spline (from scratch)
%                       "idw"       — inverse-distance weighting (from scratch)
%       IDWPower      — power p for IDW kernel (default 2)
%       Extrapolation — "none"    → NaN outside convex hull (default)
%                       "nearest" → clamp to nearest boundary value
%                       "linear"  → linear extrapolation (scatteredInterpolant)
%       Smoothing     — lambda for thin-plate spline regularisation (default 0,
%                       i.e. exact interpolation through data)
%
%   Output:
%       result — struct with fields:
%           .zq     — interpolated values, same size as xq
%           .method — method string used
%           .stats  — struct: .nPoints (number of data points),
%                             .rmse (leave-one-out RMSE, only for thinplate/idw)
%
%   Examples:
%       % Scattered data
%       rng(0); x = rand(50,1)*4; y = rand(50,1)*4; z = sin(x).*cos(y);
%       [Xq,Yq] = meshgrid(linspace(0,4,40));
%       r = utilities.interpolate2D(x, y, z, Xq, Yq);
%       surf(Xq, Yq, r.zq);
%
%       % Thin-plate spline with mild smoothing
%       r = utilities.interpolate2D(x, y, z, Xq, Yq, Method="thinplate", Smoothing=1e-3);
%
%   See also utilities.regrid2D, scatteredInterpolant

arguments
    x   (:,:) double
    y   (:,:) double
    z   (:,:) double
    xq  (:,:) double
    yq  (:,:) double
    Options.Method (1,1) string {mustBeMember(Options.Method, ...
        ["linear","natural","nearest","cubic","thinplate","idw"])} = "natural"
    Options.IDWPower   (1,1) double {mustBePositive} = 2
    Options.Extrapolation (1,1) string {mustBeMember(Options.Extrapolation, ...
        ["none","nearest","linear"])} = "none"
    Options.Smoothing  (1,1) double {mustBeNonnegative} = 0
end

% ════════════════════════════════════════════════════════════════════════
% Flatten inputs to column vectors (handles both scattered and gridded)
% ════════════════════════════════════════════════════════════════════════
xv = x(:);
yv = y(:);
zv = z(:);

if numel(xv) ~= numel(yv) || numel(xv) ~= numel(zv)
    error('utilities:interpolate2D:sizeMismatch', ...
        'x, y, and z must have the same number of elements.');
end
if numel(xv) < 3
    error('utilities:interpolate2D:tooFew', ...
        'At least 3 data points are required for 2-D interpolation.');
end

% Remove duplicate (x,y) positions — keep first occurrence
[~, ia] = unique([xv, yv], 'rows', 'stable');
if numel(ia) < numel(xv)
    xv = xv(ia);
    yv = yv(ia);
    zv = zv(ia);
end

querySize = size(xq);
xqv = xq(:);
yqv = yq(:);

method = Options.Method;

% ════════════════════════════════════════════════════════════════════════
% Dispatch to interpolation engine
% ════════════════════════════════════════════════════════════════════════
switch method
    case {"linear", "natural", "nearest", "cubic"}
        zqv = interpScattered(xv, yv, zv, xqv, yqv, method, Options.Extrapolation);

    case "thinplate"
        zqv = interpThinPlate(xv, yv, zv, xqv, yqv, Options.Smoothing, Options.Extrapolation);

    case "idw"
        zqv = interpIDW(xv, yv, zv, xqv, yqv, Options.IDWPower);
        % IDW is defined everywhere; apply hull mask if Extrapolation="none"
        if strcmp(Options.Extrapolation, "none")
            zqv = applyHullMask(xv, yv, xqv, yqv, zqv);
        end
end

% ════════════════════════════════════════════════════════════════════════
% Assemble result struct
% ════════════════════════════════════════════════════════════════════════
stats.nPoints = numel(xv);
stats.rmse    = NaN;   % leave-one-out not computed by default (expensive)

result.zq     = reshape(zqv, querySize);
result.method = method;
result.stats  = stats;

end % interpolate2D


% ════════════════════════════════════════════════════════════════════════
% LOCAL HELPER: scatteredInterpolant wrapper
% ════════════════════════════════════════════════════════════════════════
function zqv = interpScattered(xv, yv, zv, xqv, yqv, method, extrapolation)
    % Map "cubic" → "natural" (scatteredInterpolant has no 'cubic' option;
    % 'natural' gives C1-continuous interpolation via natural neighbours)
    siMethod = char(method);
    if strcmp(siMethod, 'cubic')
        siMethod = 'natural';
    end

    % Map extrapolation option
    switch char(extrapolation)
        case 'none'
            siExtrap = 'none';   % returns NaN outside hull
        case 'nearest'
            siExtrap = 'nearest';
        case 'linear'
            siExtrap = 'linear';
        otherwise
            siExtrap = 'none';
    end

    % Detect collinear / degenerate input up front. scatteredInterpolant
    % cannot triangulate collinear points and returns NaN/empty regardless
    % of extrapolation mode.
    if isCollinear(xv, yv)
        if strcmp(siMethod, 'nearest') || strcmp(siExtrap, 'nearest')
            zqv = nearestFallback(xv, yv, zv, xqv, yqv);
        else
            zqv = nan(size(xqv));
        end
        return;
    end

    F    = scatteredInterpolant(xv, yv, zv, siMethod, siExtrap);
    zqv  = F(xqv, yqv);
    if numel(zqv) ~= numel(xqv)
        if strcmp(siMethod, 'nearest') || strcmp(siExtrap, 'nearest')
            zqv = nearestFallback(xv, yv, zv, xqv, yqv);
        else
            zqv = nan(size(xqv));
        end
    end
end

function tf = isCollinear(xv, yv)
%ISCOLLINEAR  True if all (xv,yv) points lie on a single line.
    if numel(xv) < 3
        tf = true;
        return;
    end
    A = [xv(:) - xv(1), yv(:) - yv(1)];
    tf = rank(A, max(size(A)) * eps(norm(A,'fro'))) < 2;
end

function zqv = nearestFallback(xv, yv, zv, xqv, yqv)
%NEARESTFALLBACK  Brute-force nearest-neighbour lookup (for degenerate inputs).
    nq = numel(xqv);
    zqv = nan(nq, 1);
    for k = 1:nq
        d2 = (xv - xqv(k)).^2 + (yv - yqv(k)).^2;
        [~, idx] = min(d2);
        zqv(k) = zv(idx);
    end
end


% ════════════════════════════════════════════════════════════════════════
% LOCAL HELPER: thin-plate spline (from scratch)
% ════════════════════════════════════════════════════════════════════════
function zqv = interpThinPlate(xv, yv, zv, xqv, yqv, lambda, extrapolation)
% Solves the thin-plate spline system:
%   [K + lambda*I   P ] [w]   [z]
%   [P'             0 ] [a] = [0]
%
% where K_ij = phi(r_ij), phi(r) = r^2 * log(r)  (r>0, 0 for r=0),
%       P = [1  x  y] (trend polynomial, N×3),
%       w = N weights, a = 3 polynomial coefficients.
%
% Evaluation:  f(xq,yq) = sum_i w_i * phi(||(xq,yq)-(xi,yi)||) + a1 + a2*xq + a3*yq

    n  = numel(xv);

    % Build K matrix
    dx = xv - xv';   % N×N
    dy = yv - yv';
    r2 = dx.^2 + dy.^2;
    r  = sqrt(r2);
    % phi(r) = r^2 * log(r); phi(0) = 0
    phi = zeros(n, n);
    mask = r > 0;
    phi(mask) = r2(mask) .* log(r(mask));

    % Build trend matrix P (N×3)
    P = [ones(n,1), xv, yv];

    % Assemble block system  [(K+lambda*I)  P; P'  0]
    A = [phi + lambda * eye(n),  P;
         P',                     zeros(3, 3)];
    rhs = [zv; zeros(3, 1)];

    % Solve
    coeff = A \ rhs;
    w = coeff(1:n);
    a = coeff(n+1:n+3);   % [a0, a1, a2]

    % Evaluate at query points
    nq   = numel(xqv);
    zqv  = zeros(nq, 1);
    for qi = 1:nq
        dx_q = xqv(qi) - xv;
        dy_q = yqv(qi) - yv;
        r2_q = dx_q.^2 + dy_q.^2;
        r_q  = sqrt(r2_q);
        phi_q = zeros(n, 1);
        mk = r_q > 0;
        phi_q(mk) = r2_q(mk) .* log(r_q(mk));
        zqv(qi) = w' * phi_q + a(1) + a(2)*xqv(qi) + a(3)*yqv(qi);
    end

    % Apply NaN mask outside hull if requested
    if strcmp(extrapolation, "none")
        zqv = applyHullMask(xv, yv, xqv, yqv, zqv);
    end
end


% ════════════════════════════════════════════════════════════════════════
% LOCAL HELPER: inverse-distance weighting
% ════════════════════════════════════════════════════════════════════════
function zqv = interpIDW(xv, yv, zv, xqv, yqv, p)
% Shepard's method: f(xq) = sum_i [z_i / d_i^p] / sum_i [1 / d_i^p]
% Coincident points (d=0) return z_i exactly.

    nq   = numel(xqv);
    zqv  = zeros(nq, 1);

    for qi = 1:nq
        dx = xqv(qi) - xv;
        dy = yqv(qi) - yv;
        d  = sqrt(dx.^2 + dy.^2);

        % Exact hit
        exactIdx = find(d == 0, 1);
        if ~isempty(exactIdx)
            zqv(qi) = zv(exactIdx);
            continue;
        end

        w = 1 ./ (d .^ p);
        zqv(qi) = sum(w .* zv) / sum(w);
    end
end


% ════════════════════════════════════════════════════════════════════════
% LOCAL HELPER: NaN mask outside convex hull
% ════════════════════════════════════════════════════════════════════════
function zqv = applyHullMask(xv, yv, xqv, yqv, zqv)
% Sets zqv to NaN for query points outside the convex hull of (xv,yv).
% Uses delaunay triangulation — built-in, no toolbox required.
    if numel(xv) < 3
        return;   % cannot form a hull
    end
    try
        dt = delaunayTriangulation(xv, yv);
        tid = pointLocation(dt, xqv, yqv);
        outside = isnan(tid);
        zqv(outside) = NaN;
    catch
        % If triangulation fails (collinear points, etc.) leave values as-is
    end
end
