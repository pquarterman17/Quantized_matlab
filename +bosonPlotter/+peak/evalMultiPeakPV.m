function y = evalMultiPeakPV(p, x, nP)
%EVALMULTIPEAKPV  Evaluate a sum of nP Pseudo-Voigt peaks + linear bg.
%   p layout: [H, x0, fw, eta] per peak, then [slope, intercept] at the end.
%   eta in [0,1] is the Lorentzian fraction.
    m = p(end-1); b = p(end);
    y = m*x + b;
    for k = 1:nP
        H   = p((k-1)*4+1);
        x0  = p((k-1)*4+2);
        fw  = abs(p((k-1)*4+3));
        eta = max(0, min(1, p((k-1)*4+4)));
        L   = H ./ (1 + 4*((x-x0)/fw).^2);
        G   = H .* exp(-4*log(2)*((x-x0)/fw).^2);
        y   = y + eta*L + (1-eta)*G;
    end
end
