function result = williamsonHall(twoTheta, fwhm, options)
%WILLIAMSONHALL  Separate crystallite size and microstrain from XRD peak widths.
%
%   Syntax
%   ------
%   result = calc.crystal.williamsonHall(twoTheta, fwhm)
%   result = calc.crystal.williamsonHall(twoTheta, fwhm, Wavelength_A=1.5406)
%   result = calc.crystal.williamsonHall(twoTheta, fwhm, KFactor=0.9)
%   result = calc.crystal.williamsonHall(twoTheta, fwhm, InstrumentalBroadening=0.05)
%
%   Inputs
%   ------
%   twoTheta - peak positions in degrees 2-theta (column vector)
%   fwhm     - FWHM of each peak in degrees 2-theta (column vector, same length)
%
%   Optional Name-Value Inputs
%   --------------------------
%   Wavelength_A          - X-ray wavelength in Angstroms (default: 1.5406, Cu Ka)
%   KFactor               - Scherrer constant K (default: 0.9, spherical grains)
%   InstrumentalBroadening - Instrument contribution to FWHM in degrees 2-theta to
%                            subtract in quadrature (default: 0, no correction)
%
%   Outputs
%   -------
%   result - struct with fields:
%     .grainSize_nm    - crystallite size D in nanometres
%     .microstrain     - dimensionless microstrain epsilon (r.m.s.)
%     .R2              - R-squared of the Williamson-Hall linear fit
%     .plotData.x      - 4*sin(theta) values for plotting
%     .plotData.y      - beta*cos(theta) values for plotting
%     .plotData.fitLine - [slope intercept] of the fitted line
%
%   Notes
%   -----
%   Williamson-Hall equation (uniform strain model):
%
%       beta*cos(theta) = K*lambda/D  +  4*epsilon*sin(theta)
%
%   where beta is the peak breadth (FWHM) in radians corrected for
%   instrumental broadening, K is the Scherrer constant, lambda is the
%   X-ray wavelength, D is the crystallite size, and epsilon is the
%   microstrain.
%
%   A linear regression of beta*cos(theta) vs 4*sin(theta) yields:
%     Slope     = epsilon  (microstrain)
%     Intercept = K*lambda/D  ->  D = K*lambda/intercept
%
%   Instrumental broadening is corrected in quadrature:
%     beta_true = sqrt(beta_meas^2 - beta_inst^2)
%
%   At least 2 peaks are required for the linear fit.
%
%   Examples
%   --------
%   % Three peaks from an Fe3O4 thin film (Cu Ka, 1.5406 Angstrom)
%   twoTheta = [30.1, 43.2, 57.0]';
%   fwhm     = [0.25, 0.28, 0.32]';
%   r = calc.crystal.williamsonHall(twoTheta, fwhm);
%   fprintf('D = %.1f nm, eps = %.4f\n', r.grainSize_nm, r.microstrain);

arguments
    twoTheta (:,1) double
    fwhm     (:,1) double
    options.Wavelength_A           (1,1) double {mustBePositive}    = 1.5406
    options.KFactor                (1,1) double {mustBePositive}    = 0.9
    options.InstrumentalBroadening (1,1) double {mustBeNonnegative} = 0
end

% --- Validate inputs ---

n = numel(twoTheta);
assert(n == numel(fwhm), ...
    'calc:crystal:williamsonHall:lengthMismatch', ...
    'twoTheta and fwhm must have the same number of elements (got %d vs %d).', ...
    n, numel(fwhm));
assert(n >= 2, ...
    'calc:crystal:williamsonHall:tooFewPeaks', ...
    'At least 2 peaks are required for the Williamson-Hall fit (got %d).', n);
assert(all(twoTheta > 0 & twoTheta < 180), ...
    'calc:crystal:williamsonHall:invalidTwoTheta', ...
    'All 2-theta values must be in the range (0, 180) degrees.');
assert(all(fwhm > 0), ...
    'calc:crystal:williamsonHall:nonPositiveFWHM', ...
    'All FWHM values must be positive.');

% --- Convert to radians ---

theta    = (twoTheta / 2) * (pi / 180);   % theta in radians
betaMeas = fwhm * (pi / 180);             % measured beta in radians

% --- Instrumental broadening correction (quadrature subtraction) ---

betaInst = options.InstrumentalBroadening * (pi / 180);
if betaInst > 0
    betaSq = betaMeas.^2 - betaInst^2;
    if any(betaSq <= 0)
        warning('calc:crystal:williamsonHall:broadenedByInstrument', ...
            'Some FWHM values are smaller than the instrumental broadening - clamping to 1e-16.');
        betaSq = max(betaSq, 1e-16);
    end
    beta = sqrt(betaSq);
else
    beta = betaMeas;
end

% --- Williamson-Hall variables: x = 4*sin(theta), y = beta*cos(theta) ---

x = 4 * sin(theta);
y = beta .* cos(theta);

% --- Linear regression: y = slope*x + intercept  (least squares) ---

Xmat   = [x, ones(n, 1)];   % design matrix [N x 2]
coeffs = Xmat \ y;           % [slope; intercept]

slope     = coeffs(1);   % microstrain epsilon
intercept = coeffs(2);   % K*lambda/D

% --- Derived quantities ---

% Crystallite size in Angstroms, converted to nm
if intercept <= 0
    warning('calc:crystal:williamsonHall:negativeIntercept', ...
        'Negative or zero intercept (%.4g) - grain size is undefined. Check that peaks belong to the same phase.', ...
        intercept);
    grainSize_nm = NaN;
else
    grainSize_A  = (options.KFactor * options.Wavelength_A) / intercept;
    grainSize_nm = grainSize_A / 10;
end

microstrain = slope;   % dimensionless epsilon

% --- R-squared of the fit ---

yFit  = Xmat * coeffs;
ssRes = sum((y - yFit).^2);
ssTot = sum((y - mean(y)).^2);
if ssTot < eps
    R2 = 1;   % perfect constant prediction (degenerate case)
else
    R2 = 1 - ssRes / ssTot;
end

% --- Pack result ---

result.grainSize_nm     = grainSize_nm;
result.microstrain      = microstrain;
result.R2               = R2;
result.plotData.x       = x;
result.plotData.y       = y;
result.plotData.fitLine = [slope, intercept];

end
