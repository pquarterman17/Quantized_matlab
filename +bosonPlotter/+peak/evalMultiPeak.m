function y = evalMultiPeak(p, x, nP, isGauss)
%EVALMULTIPEAK  Evaluate a sum of nP Lorentzian or Gaussian peaks + linear bg.
%   p layout: [H1, x0_1, fw_1, H2, x0_2, fw_2, ..., HN, x0_N, fw_N, slope, intercept]
%   isGauss=true → Gaussian shape; false → Lorentzian.
    m = p(end-1); b = p(end);
    y = m*x + b;
    for k = 1:nP
        H = p((k-1)*3+1); x0 = p((k-1)*3+2); fw = abs(p((k-1)*3+3));
        if isGauss
            y = y + H * exp(-4*log(2)*((x-x0)/fw).^2);
        else
            y = y + H ./ (1 + 4*((x-x0)/fw).^2);
        end
    end
end
