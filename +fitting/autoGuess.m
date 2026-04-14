function p0 = autoGuess(modelName, xData, yData)
%AUTOGUESS  Heuristic initial parameter estimation from data shape.
%
%   p0 = fitting.autoGuess(modelName, xData, yData)
%
%   Estimates reasonable starting parameters for curve fitting based on
%   data characteristics: range, slope, peak positions, decay constants.
%
%   Inputs:
%       modelName — string matching a name in fitting.models()
%       xData     — [N×1] independent variable
%       yData     — [N×1] dependent variable
%
%   Output:
%       p0 — [1×M] initial parameter vector
%
%   If the model is not recognized, returns the default p0 from the model
%   library unchanged.
%
%   Peak-shape width conventions
%   ─────────────────────────────
%   Each peak model stores a physically distinct width parameter p0(3).
%   The seeding heuristic converts the data-estimated FWHM to the correct
%   parameter for each model, matching the functional forms in fitting.models():
%
%     Gaussian:      y = A * exp( -(x-mu)^2 / (2*sigma^2) )
%                    FWHM = 2*sqrt(2*ln2) * sigma  ≈  2.3548 * sigma
%                    => seed:  sigma = FWHM / 2.3548
%
%     Lorentzian:    y = A / (1 + ((x-x0)/gamma)^2)
%                    FWHM = 2 * gamma   (gamma is the HWHM)
%                    => seed:  gamma = FWHM / 2
%
%     Pseudo-Voigt:  y = eta * L(x,w) + (1-eta) * G(x,w)
%                    where both sub-functions share the single width w,
%                    defined as the HWHM of the Lorentzian component.
%                    The composite FWHM equals 2*w (exactly for eta=1,
%                    approximately for eta in (0,1)).
%                    => seed:  w = FWHM / 2
%
%   Using sigma (Gaussian convention) for all three models would seed
%   Lorentzian and pseudo-Voigt fits with widths roughly 18% too narrow
%   (2.3548/2 - 1), which can prevent convergence or bias the result.
%
%   Example
%   ─────────────────────────────
%     x  = linspace(-5, 5, 200)';
%     y  = 3 ./ (1 + (x./0.8).^2) + 0.05*randn(200,1);   % Lorentzian, gamma=0.8
%     p0 = fitting.autoGuess('Lorentzian', x, y);
%     % p0 ≈ [3, 0, 0.8]  (amplitude, center, gamma)
%
%   Reference
%   ─────────────────────────────
%   Thompson, P., Cox, D.E. & Hastings, J.B., "Rietveld refinement of
%   Debye-Scherrer synchrotron X-ray data from Al2O3," J. Appl. Cryst.
%   20 (1987) 79-83.  (pseudo-Voigt FWHM parameterization)

arguments
    modelName (1,1) string
    xData     (:,1) double
    yData     (:,1) double
end

% Get default p0 from model library
catalog = fitting.models();
idx = find(strcmp({catalog.name}, modelName), 1);
if isempty(idx)
    error('fitting:autoGuess:unknownModel', 'Model "%s" not found.', modelName);
end
p0 = catalog(idx).p0;

% Data characteristics
xRange = max(xData) - min(xData);
yRange = max(yData) - min(yData);
yMean  = mean(yData);
xMean  = mean(xData);
N = numel(xData);

switch modelName
    % ── Linear / Polynomial ────────────────────────────────────────
    case 'Linear'
        p0(1) = (yData(end) - yData(1)) / max(xRange, eps);
        p0(2) = yData(1) - p0(1)*xData(1);

    case {'Quadratic', 'Cubic', 'Poly 4'}
        % Use linear fit as starting point
        p0(end-1) = (yData(end) - yData(1)) / max(xRange, eps);
        p0(end) = yMean;

    % ── Decay ──────────────────────────────────────────────────────
    case 'Exponential Decay'
        p0(1) = yRange;                                % amplitude
        p0(2) = xRange / 3;                            % time constant
        p0(3) = min(yData);                             % offset
        % Refine τ: find x where y drops to 1/e of amplitude
        yNorm = (yData - min(yData)) / max(yRange, eps);
        eIdx = find(yNorm <= exp(-1), 1);
        if ~isempty(eIdx)
            p0(2) = abs(xData(eIdx) - xData(1));
        end

    case 'Stretched Exponential'
        p0(1) = yRange;
        p0(2) = xRange / 3;
        p0(3) = 0.7;                                   % β (stretch exponent)
        p0(4) = min(yData);

    case 'Bi-exponential Decay'
        p0(1) = yRange * 0.6;
        p0(2) = xRange / 5;
        p0(3) = yRange * 0.4;
        p0(4) = xRange / 1.5;
        p0(5) = min(yData);

    % ── Growth ─────────────────────────────────────────────────────
    case 'Exponential Growth'
        p0(1) = yData(1);
        p0(2) = xRange / 3;
        p0(3) = min(yData);

    case 'Saturation Growth'
        p0(1) = yRange;
        p0(2) = xRange / 3;
        p0(3) = min(yData);

    % ── Peak shapes ────────────────────────────────────────────────
    case {'Gaussian', 'Lorentzian', 'Pseudo-Voigt'}
        [~, pkI] = max(yData);
        p0(1) = yData(pkI);                            % amplitude
        p0(2) = xData(pkI);                            % center
        % Estimate FWHM from half-max crossings
        hm = yData >= yData(pkI)/2;
        hmIdx = find(hm);
        if numel(hmIdx) >= 2
            fwhm = xData(hmIdx(end)) - xData(hmIdx(1));
        else
            % Fallback: roughly 10% of x-range is a FWHM, not a sigma
            fwhm = xRange / 10;
        end
        % The width parameter the solver sees depends on the model:
        %   Gaussian A*exp(-((x-x0)/σ)²/2): σ  = FWHM / 2.355
        %   Lorentzian A/(1+((x-x0)/γ)²):   γ  = FWHM / 2
        %   Pseudo-Voigt (standard form):   w  = FWHM / 2
        % Using σ for all three systematically seeds Lorentzian / pV
        % fits with widths ~18% too small, biasing convergence.
        switch modelName
            case 'Gaussian'
                p0(3) = fwhm / 2.355;
            otherwise
                p0(3) = fwhm / 2;
        end
        if strcmp(modelName, 'Pseudo-Voigt')
            p0(4) = 0.5;                               % mixing parameter
        end

    % ── Power ──────────────────────────────────────────────────────
    case {'Power Law', 'Allometric'}
        % Log-log linear regression for A·x^n
        posIdx = xData > 0 & yData > 0;
        if sum(posIdx) > 2
            logX = log(xData(posIdx));
            logY = log(yData(posIdx));
            n = (N*sum(logX.*logY) - sum(logX)*sum(logY)) / ...
                max(N*sum(logX.^2) - sum(logX)^2, eps);
            A = exp(mean(logY) - n*mean(logX));
            p0(1) = A;
            p0(2) = n;
        end
        if strcmp(modelName, 'Power Law')
            p0(3) = 0;
        end

    % ── Sigmoid ────────────────────────────────────────────────────
    case {'Logistic', 'Tanh'}
        p0(1) = yRange;
        % Midpoint: where y crosses mean
        crossIdx = find(diff(sign(yData - yMean)), 1);
        if ~isempty(crossIdx)
            p0(3) = xData(crossIdx);
        else
            p0(3) = xMean;
        end
        % Steepness from max |dy/dx|
        if N > 2
            dy = diff(yData) ./ diff(xData);
            [~, steepIdx] = max(abs(dy));
            p0(2) = abs(dy(steepIdx)) * 4 / max(yRange, eps);
        else
            p0(2) = 4 / max(xRange, eps);
        end
        p0(4) = min(yData);

    % ── Magnetic ───────────────────────────────────────────────────
    case 'Langevin'
        p0(1) = max(abs(yData));                        % saturation
        % B from initial slope: dM/dH|_{H=0} = A/(3B)
        if N > 2
            slopeNear0 = abs(yData(2) - yData(1)) / max(abs(xData(2) - xData(1)), eps);
            p0(2) = p0(1) / max(3*slopeNear0, eps);
        end

    case 'Curie-Weiss'
        % χ = C/(T - θ):  C ≈ mean(y*(x-θ)), θ from 1/y extrapolation
        if all(yData > 0)
            invY = 1 ./ yData;
            slope = (invY(end) - invY(1)) / max(xRange, eps);
            p0(2) = xData(1) - invY(1)/max(slope, eps);     % θ
            p0(1) = mean(yData .* (xData - p0(2)));          % C
        end

    case 'Bloch T^3/2'
        p0(1) = max(yData);                             % M₀
        p0(2) = (1 - min(yData)/max(yData)) / max(xData(end), eps)^1.5;

    % ── Thermal ────────────────────────────────────────────────────
    case 'Arrhenius'
        p0(1) = max(yData);
        % From ln(y) = ln(A) - Ea/(kB*T)
        posIdx = yData > 0 & xData > 0;
        if sum(posIdx) > 2
            invX = 1 ./ xData(posIdx);
            lnY = log(yData(posIdx));
            slope = (lnY(end) - lnY(1)) / (invX(end) - invX(1));
            p0(2) = abs(slope);
        end

    case 'Langmuir'
        p0(1) = max(yData);
        % K is x where y = A/2
        halfMax = max(yData) / 2;
        kIdx = find(yData >= halfMax, 1);
        if ~isempty(kIdx)
            p0(2) = abs(xData(kIdx));
        end

    % ── Other ──────────────────────────────────────────────────────
    case 'Logarithmic'
        posIdx = xData > 0;
        if sum(posIdx) > 1
            logX = log(xData(posIdx));
            p0(1) = yRange / max(range(logX), eps);
            p0(2) = yMean - p0(1)*mean(logX);
        end

    case 'Square Root'
        posIdx = xData >= 0;
        if sum(posIdx) > 1
            sqrtX = sqrt(xData(posIdx));
            p0(1) = yRange / max(range(sqrtX), eps);
            p0(2) = yMean - p0(1)*mean(sqrtX);
        end

    % ── New physics models ────────────────────────────────────────
    case 'Brillouin'
        p0(1) = max(abs(yData));          % Ms
        p0(2) = 0.5;                      % J (start with spin-1/2)
        p0(3) = 2;                        % g-factor
        p0(4) = 300;                      % T (room temperature default)

    case 'Stoner-Wohlfarth'
        p0(1) = max(abs(yData));          % Ms
        % Hc from zero-crossing
        signChange = find(diff(sign(yData)), 1);
        if ~isempty(signChange)
            p0(2) = abs(xData(signChange));  % Hc
        else
            p0(2) = xRange / 4;
        end
        p0(3) = xRange / 2;              % Hk (anisotropy field)

    case 'VFT'
        p0(1) = min(yData(yData > 0));    % tau_0 (smallest positive y)
        p0(2) = 0.05;                     % Ea_eV (typical energy barrier)
        p0(3) = 0;                        % T_0 (start at Arrhenius limit)

    case 'Debye'
        % C(T) = gamma*T + n*C_Debye(T, theta_D)
        % At low T: C ≈ gamma*T → gamma from slope
        lowIdx = xData < xData(end) * 0.1;
        if sum(lowIdx) > 1
            p0(1) = mean(yData(lowIdx) ./ max(xData(lowIdx), eps));  % gamma
        else
            p0(1) = 0;
        end
        p0(2) = max(xData) * 2;          % theta_D (Debye temp > measurement range)
        p0(3) = 1;                        % n (atoms per formula unit)

    case 'Einstein'
        p0(1) = 0;                        % gamma
        p0(2) = max(xData) * 0.5;        % theta_E (Einstein temp)
        p0(3) = 1;                        % n

    case 'Debye+Einstein'
        lowIdx = xData < xData(end) * 0.1;
        if sum(lowIdx) > 1
            p0(1) = mean(yData(lowIdx) ./ max(xData(lowIdx), eps));
        else
            p0(1) = 0;
        end
        p0(2) = max(xData) * 2;          % theta_D
        p0(3) = max(xData) * 0.5;        % theta_E
        p0(4) = 0.5;                     % fD (Debye fraction)
        p0(5) = 1;                        % n
end

end
