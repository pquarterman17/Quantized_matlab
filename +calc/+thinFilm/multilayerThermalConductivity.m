function result = multilayerThermalConductivity(thicknesses, kappas)
%MULTILAYERTHERMALBCONDUCTIVITY  Effective thermal conductivity of a multilayer stack.
%
%   Syntax
%   ------
%   result = calc.thinFilm.multilayerThermalConductivity(thicknesses, kappas)
%
%   Inputs
%   ------
%   thicknesses — layer thicknesses (nm), numeric vector of length N
%   kappas      — layer thermal conductivities (W/m/K), numeric vector of length N
%
%   Outputs
%   -------
%   result — struct with fields:
%     .kSeries        — effective thermal conductivity in series (W/m/K)
%     .kParallel      — effective thermal conductivity in parallel (W/m/K)
%     .totalThickness — total stack thickness (nm)
%     .nLayers        — number of layers
%     .latex          — LaTeX-formatted result string
%
%   Notes
%   -----
%   Series (heat flow perpendicular to layers):
%     kEff = sum(d) / sum(d_i / k_i)
%   Parallel (heat flow along layers):
%     kEff = sum(k_i * d_i) / sum(d_i)
%
%   Examples
%   --------
%   % Two-layer stack: 100 nm SiO2 (1.4 W/m/K) + 50 nm Si (148 W/m/K)
%   r = calc.thinFilm.multilayerThermalConductivity([100, 50], [1.4, 148]);

% ════════════════════════════════════════════════════════════════════

arguments
    thicknesses (:,1) double {mustBePositive}
    kappas      (:,1) double {mustBePositive}
end

if numel(thicknesses) ~= numel(kappas)
    error('calc:thinFilm:sizeMismatch', ...
        'thicknesses and kappas must have the same number of elements.');
end

totalThickness = sum(thicknesses);
kSeries        = totalThickness / sum(thicknesses ./ kappas);
kParallel      = sum(kappas .* thicknesses) / totalThickness;

result.kSeries        = kSeries;
result.kParallel      = kParallel;
result.totalThickness = totalThickness;
result.nLayers        = numel(thicknesses);
result.latex          = sprintf( ...
    '$k_{\\perp} = %.4g\\,\\text{W/m/K},\\;k_{\\parallel} = %.4g\\,\\text{W/m/K}$', ...
    kSeries, kParallel);
end
