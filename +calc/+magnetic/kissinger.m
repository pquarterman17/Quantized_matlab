function result = kissinger(heatingRates, peakTemperatures)
%KISSINGER  Activation energy from thermal analysis peak shift (Kissinger method).
%
%   Syntax
%   ------
%   result = calc.magnetic.kissinger(beta, Tp)
%
%   Inputs
%   ------
%   heatingRates     — [N×1] heating rates beta (K/min), N >= 3
%   peakTemperatures — [N×1] peak temperatures Tp (K) at each heating rate
%
%   Outputs
%   -------
%   result — struct with fields:
%     .Ea_eV      — activation energy in eV
%     .Ea_kJmol   — activation energy in kJ/mol
%     .R2         — R² of the Kissinger linear fit
%     .plotData   — struct with:
%         .x  — 1000/Tp for conventional plotting (10³/K)
%         .y  — ln(beta/Tp²) values
%         .fit — fitted line at plotData.x points
%
%   Physics
%   -------
%   The Kissinger equation is:
%     ln(beta / Tp²) = -Ea / (R * Tp) + const
%
%   where R = 8.314 J/(mol·K). A linear fit of y = ln(beta/Tp²) vs
%   x = 1/Tp gives:
%     slope = -Ea / R   =>   Ea = -slope * R
%
%   Conventionally the x axis is plotted as 1000/Tp (×10³ K⁻¹), so the
%   displayed slope equals -Ea/(R*1000) and the returned Ea is corrected.
%
%   Typical applications: DSC/DTA peak shifts, crystallisation kinetics,
%   magnetic annealing activation energies.
%
%   Examples
%   --------
%   % Known Ea = 1.5 eV
%   R = 8.314;  Ea_J = 1.5 * 1.60218e-19 * 6.02214e23;   % J/mol
%   beta = [5; 10; 20; 40];            % K/min
%   Tp   = [530; 545; 562; 580];       % K (synthetic)
%   result = calc.magnetic.kissinger(beta, Tp);
%   fprintf('Ea = %.3f eV\n', result.Ea_eV);

% ════════════════════════════════════════════════════════════════════════
arguments
    heatingRates     (:,1) double
    peakTemperatures (:,1) double
end

% ════════════════════════════════════════════════════════════════════════
% Physical constants
% ════════════════════════════════════════════════════════════════════════
R_gas   = 8.314;        % J/(mol·K)
eV_per_J = 6.24151e18;  % eV per joule (= 1/e)
NA      = 6.02214076e23;
eV2kJmol = 1.60218e-22 * NA / 1e3;  % eV -> kJ/mol conversion

% ════════════════════════════════════════════════════════════════════════
% Validate
% ════════════════════════════════════════════════════════════════════════
N = numel(heatingRates);
if N ~= numel(peakTemperatures)
    error('calc:magnetic:kissinger:sizeMismatch', ...
        'heatingRates and peakTemperatures must have the same length.');
end
if N < 3
    error('calc:magnetic:kissinger:tooFewPoints', ...
        'At least 3 data points are required for a meaningful Kissinger analysis.');
end
if any(heatingRates <= 0)
    error('calc:magnetic:kissinger:badHeatingRate', ...
        'All heating rates must be positive.');
end
if any(peakTemperatures <= 0)
    error('calc:magnetic:kissinger:badTemperature', ...
        'All peak temperatures must be positive (K).');
end

% ════════════════════════════════════════════════════════════════════════
% Kissinger plot quantities
%   x = 1/Tp           (units: K⁻¹)
%   y = ln(beta / Tp²) (units: ln(K/min / K²) = ln(min⁻¹ K⁻¹), offset)
% ════════════════════════════════════════════════════════════════════════
x = 1 ./ peakTemperatures;      % K⁻¹
y = log(heatingRates ./ (peakTemperatures.^2));

% ════════════════════════════════════════════════════════════════════════
% Linear fit: y = slope*x + intercept
%   slope = -Ea/R  =>  Ea (J/mol) = -slope * R
% ════════════════════════════════════════════════════════════════════════
Xmat = [x, ones(N, 1)];
b = Xmat \ y;
slope     = b(1);
intercept = b(2);

yFit = Xmat * b;
ssTot = sum((y - mean(y)).^2);
ssRes = sum((y - yFit).^2);
R2    = 1 - ssRes / max(ssTot, eps);

% Activation energy
Ea_Jmol  = -slope * R_gas;          % J/mol (slope is negative for valid data)
Ea_kJmol = Ea_Jmol / 1e3;           % kJ/mol
Ea_eV    = Ea_Jmol / (NA * 1.60218e-19); % eV

% ════════════════════════════════════════════════════════════════════════
% Plot data (conventional: x axis = 1000/Tp)
% ════════════════════════════════════════════════════════════════════════
x_plot  = 1000 ./ peakTemperatures;   % ×10³ K⁻¹ for display
% Fitted line at these x points (slope/1000 because x_plot = 1000*x)
yFit_plot = (slope / 1000) .* x_plot + intercept;

plotData.x   = x_plot;
plotData.y   = y;
plotData.fit = yFit_plot;

% ════════════════════════════════════════════════════════════════════════
% Output
% ════════════════════════════════════════════════════════════════════════
result.Ea_eV    = Ea_eV;
result.Ea_kJmol = Ea_kJmol;
result.R2       = R2;
result.plotData = plotData;

end
