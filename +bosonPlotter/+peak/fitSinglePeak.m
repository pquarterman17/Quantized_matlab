function r = fitSinglePeak(xv, yv, xLo, xHi, pkSeed, modelName, snipBg)
%FITSINGLEPEAK  Fit one peak in [xLo, xHi] to modelName; return result struct.
%
%   Inputs
%     xv, yv     full active data (monotone xv)
%     xLo, xHi   fit window (x-range)
%     pkSeed     struct with .center .fwhm (NaN ok) used as initial guess
%     modelName  one of {'Lorentzian','Gaussian','Pseudo-Voigt',
%                        'Split Pearson VII','TCH-pV'}
%     snipBg     [] or vector aligned with xv — subtracted before fit if given
%
%   Output struct r:
%     r.success  logical
%     r.reason   char  '', or one of:
%                'too-few-points', 'window-too-narrow',
%                'center-drift', 'fwhm-too-wide',
%                'fminsearch-error'
%     r.center, r.fwhm, r.height, r.bg, r.eta, r.area, r.params, r.model
%     r.window   [xLo xHi] used for the fit (post-expansion if any)

    r = struct('success', false, 'reason', '', ...
               'center', NaN, 'fwhm', NaN, 'height', NaN, 'bg', NaN, ...
               'eta', NaN, 'area', NaN, 'params', [], 'model', modelName, ...
               'window', [xLo xHi]);

    if numel(xv) < 5
        r.reason = 'too-few-points'; return;
    end
    xSpan = diff([min(xv), max(xv)]);

    % Optional background subtraction (NaN-safe: skip at NaN positions)
    yWork = yv;
    if ~isempty(snipBg) && numel(snipBg) == numel(yv)
        ok = isfinite(snipBg);
        yWork(ok) = yv(ok) - snipBg(ok);
    end

    inWin = xv >= xLo & xv <= xHi;
    if sum(inWin) < 4
        r.reason = 'window-too-narrow'; return;
    end
    xFit = xv(inWin);  yFit = yWork(inWin);

    isPV    = strcmp(modelName, 'Pseudo-Voigt');
    isSPVII = strcmp(modelName, 'Split Pearson VII');
    isTCH   = strcmp(modelName, 'TCH-pV');
    switch modelName
        case 'Gaussian'
            modelFun = @(p,x) p(1) .* exp(-4.*log(2).*((x-p(2))./p(3)).^2) + p(4);
        case 'Pseudo-Voigt'
            modelFun = @(p,x) p(1) .* (p(5) ./ (1 + 4.*((x-p(2))./p(3)).^2) + ...
                              (1-p(5)) .* exp(-4.*log(2).*((x-p(2))./p(3)).^2)) + p(4);
        case 'Split Pearson VII'
            modelFun = @(p,x) utilities.splitPearsonVII(x, p);
        case 'TCH-pV'
            modelFun = @(p,x) utilities.tchPseudoVoigt(x(:), p(:)');
        otherwise
            modelFun = @(p,x) p(1) ./ (1 + 4.*((x - p(2))./p(3)).^2) + p(4);
    end
    opts = optimset('Display','off','MaxIter',8000,'TolX',1e-10,'TolFun',1e-14);

    % Initial guesses
    bg0  = min(yFit);
    x0_0 = pkSeed.center;
    H0   = interp1(xFit, yFit, x0_0, 'linear', max(yFit)) - bg0;
    if H0 <= 0, H0 = max(yFit) - bg0; end
    if ~isnan(pkSeed.fwhm) && pkSeed.fwhm > 0
        fw0 = pkSeed.fwhm;
    else
        dx  = (xFit(end) - xFit(1)) / max(1, numel(xFit) - 1);
        fw0 = max((xHi - xLo) * 0.3, dx * 2);
    end

    if isSPVII
        hw0 = fw0 / 2;
        p0 = [H0, x0_0, hw0, hw0, 1.5, 1.5, bg0];
    elseif isTCH
        fw_seed = fw0 / sqrt(2);
        p0 = [H0, x0_0, fw_seed, fw_seed, bg0];
    else
        p0 = [H0, x0_0, fw0, bg0];
        if isPV, p0(end+1) = 0.5; end %#ok<AGROW>
    end

    objFun = @(p) sum((modelFun(p, xFit) - yFit).^2);
    try
        pFit = fminsearch(objFun, p0, opts);
    catch
        r.reason = 'fminsearch-error'; return;
    end

    if isSPVII
        fwhmFit = abs(pFit(3)) + abs(pFit(4));
        etaFit  = NaN;
        bgFit   = pFit(7);
    elseif isTCH
        fG = abs(pFit(3));  fL = abs(pFit(4));
        f5 = fG^5 + 2.69269*fG^4*fL + 2.42843*fG^3*fL^2 ...
           + 4.47163*fG^2*fL^3 + 0.07842*fG*fL^4 + fL^5;
        fwhmFit = f5^(1/5);
        if fwhmFit > 0
            rR     = fL / fwhmFit;
            etaFit = max(0, min(1, 1.36603*rR - 0.47719*rR^2 + 0.11116*rR^3));
        else
            etaFit = NaN;
        end
        bgFit = pFit(5);
    else
        fwhmFit = abs(pFit(3));
        if isPV
            etaFit = max(0, min(1, pFit(5)));
        else
            etaFit = NaN;
        end
        bgFit = pFit(4);
    end

    if pFit(2) < xLo || pFit(2) > xHi
        r.reason = 'center-drift'; return;
    end
    if ~(fwhmFit > 0 && fwhmFit < xSpan * 0.5)
        r.reason = 'fwhm-too-wide'; return;
    end

    % Compute area
    switch modelName
        case 'Gaussian'
            fittedArea = pFit(1) * fwhmFit * sqrt(pi / log(2)) / 2;
        case 'Pseudo-Voigt'
            A_L = pi / 2;
            A_G = sqrt(pi) / (2 * sqrt(log(2)));
            fittedArea = pFit(1) * fwhmFit * (etaFit * A_L + (1-etaFit) * A_G);
        case 'Split Pearson VII'
            xDense = linspace(xLo, xHi, 500)';
            yDense = utilities.splitPearsonVII(xDense, pFit) - pFit(7);
            fittedArea = trapz(xDense, yDense);
        case 'TCH-pV'
            A_L = pi / 2;
            A_G = sqrt(pi) / (2 * sqrt(log(2)));
            fittedArea = pFit(1) * fwhmFit * (etaFit * A_L + (1-etaFit) * A_G);
        otherwise
            fittedArea = pFit(1) * fwhmFit * pi / 2;
    end

    r.success = true;
    r.center  = pFit(2);
    r.fwhm    = fwhmFit;
    r.height  = pFit(1);
    r.bg      = bgFit;
    r.eta     = etaFit;
    r.area    = fittedArea;
    r.params  = pFit;
end
