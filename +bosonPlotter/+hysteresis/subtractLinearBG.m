function [H, M] = subtractLinearBG(H, M)
%SUBTRACTLINEARBG  Fit and subtract a linear paramagnetic / diamagnetic slope.
%
%   [H, M] = bosonPlotter.hysteresis.subtractLinearBG(H, M)
%
%   Fits a line to the high-field tails (|H| > 70% of |Hmax|) and subtracts
%   the slope. Offset is preserved so the loop centre / coercivity are
%   unaffected. No-op if fewer than 4 high-field points are available.
    Hmax = max(abs(H));
    hiMask = abs(H) > 0.7 * Hmax;
    if sum(hiMask) < 4, return; end
    p = polyfit(H(hiMask), M(hiMask), 1);
    M = M - p(1) * H;
end
