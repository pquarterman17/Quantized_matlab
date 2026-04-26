function fwhm = estimateLocalFWHM(xv, yv, xCenter, xSpan)
%ESTIMATELOCALFWHM  Walk left+right from xCenter to find half-max points.
%   Returns NaN if either side cannot bracket half-max within ~5% of x-span.
%   xv must be monotone-increasing.
    fwhm = NaN;
    if numel(xv) < 5, return; end
    [~, ic] = min(abs(xv - xCenter));
    if ic <= 1 || ic >= numel(xv), return; end

    yPeak = yv(ic);
    % Local baseline: min y in ±5% of x-span around the click.
    bandHW = max(xSpan * 0.05, 5 * (xv(min(end,ic+1)) - xv(max(1,ic-1))) / 2);
    bandMask = xv >= (xCenter - bandHW) & xv <= (xCenter + bandHW);
    if ~any(bandMask), return; end
    yBase = min(yv(bandMask));
    halfMax = yBase + 0.5 * (yPeak - yBase);
    if ~isfinite(halfMax) || halfMax >= yPeak, return; end

    % Walk left until y dips below halfMax.
    iL = ic;
    while iL > 1 && yv(iL) >= halfMax
        iL = iL - 1;
    end
    if iL == 1 && yv(iL) >= halfMax, return; end
    xL = interpHalfMax(xv(iL), xv(iL+1), yv(iL), yv(iL+1), halfMax);

    % Walk right until y dips below halfMax.
    iR = ic;
    while iR < numel(xv) && yv(iR) >= halfMax
        iR = iR + 1;
    end
    if iR == numel(xv) && yv(iR) >= halfMax, return; end
    xR = interpHalfMax(xv(iR-1), xv(iR), yv(iR-1), yv(iR), halfMax);

    fwhm = xR - xL;
    % Sanity: reject implausibly wide estimates (> 20% of x-span).
    if fwhm <= 0 || fwhm > xSpan * 0.20
        fwhm = NaN;
    end
end

function x = interpHalfMax(x1, x2, y1, y2, yT)
    if y1 == y2
        x = (x1 + x2) / 2;
    else
        x = x1 + (yT - y1) * (x2 - x1) / (y2 - y1);
    end
end
