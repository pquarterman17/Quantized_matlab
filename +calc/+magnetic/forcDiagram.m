function result = forcDiagram(Ha, Hb, M, options)
%FORCDIAGRAM  Compute First-Order Reversal Curve (FORC) distribution.
%
%   Syntax
%   ------
%   result = calc.magnetic.forcDiagram(Ha, Hb, M)
%   result = calc.magnetic.forcDiagram(Ha, Hb, M, SmoothingFactor=4)
%   result = calc.magnetic.forcDiagram(Ha, Hb, M, GridPoints=150)
%
%   Inputs
%   ------
%   Ha — [P×1] reversal field vector (Oe or T), one value per FORC curve
%   Hb — [P×Q] measurement field grid, or [P×Q] matrix where row p
%        contains the measurement fields for FORC curve p
%   M  — [P×Q] magnetization data matrix (same size as Hb)
%
%   Options
%   -------
%   SmoothingFactor — integer SF >= 1 controlling the local polynomial
%                     smoothing window (window = 2*SF+1 points).
%                     Larger SF = smoother distribution. Default: 3
%   GridPoints      — number of grid points along each axis for the
%                     output (Hc, Hu) distribution. Default: 100
%
%   Outputs
%   -------
%   result — struct with fields:
%     .Hc            — [1×G] coercivity axis vector (Hc = (Hb - Ha)/2)
%     .Hu            — [1×G] interaction field axis vector (Hu = (Ha+Hb)/2)
%     .rho           — [G×G] FORC distribution matrix rho(Hu, Hc)
%     .contourLevels — [1×10] suggested contour levels (5th–95th percentile)
%
%   Physics
%   -------
%   The FORC distribution is defined as:
%     rho(Ha, Hb) = -0.5 * d²M / (dHa * dHb)
%
%   Physical coordinate transform:
%     Hc = (Hb - Ha) / 2   (coercivity coordinate, >= 0 for Hb > Ha)
%     Hu = (Ha + Hb) / 2   (interaction (bias) field coordinate)
%
%   The mixed partial derivative is estimated locally using a 2-D
%   polynomial fit of degree 2 over a (2*SF+1)-point neighbourhood
%   following the Pike (2003) method.
%
%   References
%   ----------
%   Pike, C.R. (2003). First-order reversal-curve diagrams and reversible
%     magnetization. Phys. Rev. B, 68, 104424.
%   Roberts, A.P. et al. (2014). A critical appraisal of the FORC diagram.
%     J. Geophys. Res. Solid Earth, 119, 6strictly562-6587.
%
%   Examples
%   --------
%   % Synthetic single-domain particle: delta peak at (Hc=500, Hu=0) Oe
%   Hc0 = 500;  n = 30;
%   Ha = linspace(-1000, -100, n)';
%   Q = 200;
%   Hb = repmat(linspace(-1000, 1000, Q), n, 1);
%   M  = zeros(n, Q);
%   for k = 1:n
%       M(k,:) = tanh((Hb(k,:) - sign(Hb(k,:))*Hc0) / 50);
%   end
%   result = calc.magnetic.forcDiagram(Ha, Hb, M, SmoothingFactor=2);

% ════════════════════════════════════════════════════════════════════════
arguments
    Ha (:,1)   double
    Hb (:,:)   double
    M  (:,:)   double
    options.SmoothingFactor (1,1) double {mustBePositive, mustBeInteger} = 3
    options.GridPoints      (1,1) double {mustBePositive, mustBeInteger} = 100
end

% ════════════════════════════════════════════════════════════════════════
% Validate sizes
% ════════════════════════════════════════════════════════════════════════
[P, Q] = size(M);
if numel(Ha) ~= P
    error('calc:magnetic:forcDiagram:sizeMismatch', ...
        'Ha must have %d elements (one per FORC curve).', P);
end
if ~isequal(size(Hb), [P, Q])
    error('calc:magnetic:forcDiagram:sizeMismatch', ...
        'Hb and M must have the same size [%d x %d].', P, Q);
end
if P < 4 || Q < 4
    error('calc:magnetic:forcDiagram:tooFewPoints', ...
        'Need at least 4 FORC curves with at least 4 measurement points each.');
end

SF = options.SmoothingFactor;

% ════════════════════════════════════════════════════════════════════════
% Compute FORC distribution on the raw (Ha, Hb) grid
% Using local 2nd-order polynomial fit (Pike method)
%
%   Local model at point (i,j):
%     m(a, b) = c1 + c2*a + c3*b + c4*a*b + c5*a² + c6*b²
%   The mixed partial is: d²m/(da*db) = c4
%   rho = -0.5 * c4
% ════════════════════════════════════════════════════════════════════════
% Build raw Ha, Hb coordinate arrays (same size as M)
HaMat = repmat(Ha, 1, Q);   % [P × Q]

% Pre-allocate raw distribution (NaN outside valid windows)
rhoRaw = nan(P, Q);
HaRaw  = HaMat;
HbRaw  = Hb;

win = SF;   % half-window in each direction

for i = 1:P
    for j = 1:Q
        % Window indices
        ia = max(1, i - win) : min(P, i + win);
        jb = max(1, j - win) : min(Q, j + win);

        % Only compute where Hb >= Ha (physical FORC region)
        % Use the centre point's Ha as threshold
        haCentre = Ha(i);

        ha_loc = HaMat(ia, jb);
        hb_loc = Hb(ia, jb);
        m_loc  = M(ia, jb);

        % Restrict to Hb >= Ha (physical region only)
        valid = hb_loc(:) >= haCentre;
        ha_v  = ha_loc(valid);
        hb_v  = hb_loc(valid);
        m_v   = m_loc(valid);

        nv = numel(ha_v);
        if nv < 6
            % Not enough points for 6-parameter fit; skip
            continue;
        end

        % Design matrix for 2nd-order polynomial in (ha, hb)
        % columns: [1, ha, hb, ha*hb, ha^2, hb^2]
        X_loc = [ones(nv,1), ha_v, hb_v, ha_v.*hb_v, ha_v.^2, hb_v.^2];

        % Least-squares fit — suppress rank-deficiency warnings for edge windows
        warnState = warning('off', 'MATLAB:rankDeficientMatrix');
        warnState2 = warning('off', 'MATLAB:singularMatrix');
        c = X_loc \ m_v;
        warning(warnState);
        warning(warnState2);

        if ~all(isfinite(c))
            continue;
        end

        % Mixed partial = c(4), rho = -0.5 * c(4)
        rhoRaw(i,j) = -0.5 * c(4);
    end
end

% ════════════════════════════════════════════════════════════════════════
% Transform to (Hc, Hu) coordinates and grid
% ════════════════════════════════════════════════════════════════════════
% Hc = (Hb - Ha)/2 >= 0 (physical region)
% Hu = (Ha + Hb)/2

HcRaw_all = (HbRaw - HaRaw) / 2;
HuRaw_all = (HaRaw + HbRaw) / 2;

% Collect valid (physical, Hb >= Ha) points with finite rho
physMask = HcRaw_all >= 0 & isfinite(rhoRaw);
Hc_pts   = HcRaw_all(physMask);
Hu_pts   = HuRaw_all(physMask);
rho_pts  = rhoRaw(physMask);

if numel(Hc_pts) < 4
    error('calc:magnetic:forcDiagram:tooFewValidPoints', ...
        'Insufficient valid FORC points after smoothing. Check input data.');
end

% Output grid
G    = options.GridPoints;
HcVec = linspace(0, max(Hc_pts), G);
HuVec = linspace(min(Hu_pts), max(Hu_pts), G);
[HcGrid, HuGrid] = meshgrid(HcVec, HuVec);

% Scatter interpolation to regular (Hc, Hu) grid
rhoGrid = griddata(Hc_pts, Hu_pts, rho_pts, HcGrid, HuGrid, 'linear');
rhoGrid(~isfinite(rhoGrid)) = 0;

% ════════════════════════════════════════════════════════════════════════
% Contour levels: 5th–95th percentile of positive rho values
% ════════════════════════════════════════════════════════════════════════
posRho = rhoGrid(rhoGrid > 0);
if numel(posRho) >= 10
    pct = linspace(5, 95, 10);
    contourLevels = prctile_local(posRho, pct);
else
    contourLevels = linspace(0, max(rhoGrid(:)), 10);
end

% ════════════════════════════════════════════════════════════════════════
% Output
% ════════════════════════════════════════════════════════════════════════
result.Hc            = HcVec;
result.Hu            = HuVec;
result.rho           = rhoGrid;
result.contourLevels = contourLevels;

end

% ════════════════════════════════════════════════════════════════════════
% Local: percentile (no Statistics Toolbox)
% ════════════════════════════════════════════════════════════════════════
function p = prctile_local(x, pct)
%PRCTILE_LOCAL  Percentiles of x at levels pct (0-100), no toolbox needed.
    x   = sort(x(:));
    n   = numel(x);
    idx = max(1, min(n, round(pct / 100 * n)));
    p   = x(idx);
end
