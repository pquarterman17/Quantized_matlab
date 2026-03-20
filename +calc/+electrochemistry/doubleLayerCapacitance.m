function result = doubleLayerCapacitance(epsilon, d, A, opts)
%DOUBLELAYERCAPACITANCE  Compute double-layer capacitance using a parallel-plate model.
%
%   Syntax
%   ------
%   result = calc.electrochemistry.doubleLayerCapacitance(epsilon, d, A)
%   result = calc.electrochemistry.doubleLayerCapacitance(epsilon, d, A, Name=Value)
%
%   Inputs
%   ------
%   epsilon — relative permittivity of the dielectric / Helmholtz layer
%             (dimensionless)
%   d       — layer thickness (nm)
%   A       — electrode area (cm^2)
%
%   Outputs
%   -------
%   result — struct with fields:
%     .C      — capacitance (F)
%     .CuF    — capacitance (µF)
%     .CpF    — capacitance (pF)
%     .Cspec  — specific capacitance per unit area (F/cm^2)
%     .latex  — LaTeX-formatted result string
%
%   Notes
%   -----
%   Uses the parallel-plate formula C = eps0 * epsilon * A_m2 / d_m, where
%   d is converted from nm to m and A from cm^2 to m^2 internally.
%   eps0 is taken from calc.constants().
%
%   Examples
%   --------
%   r = calc.electrochemistry.doubleLayerCapacitance(80, 0.3, 1.0);
%   % Water-like solvent, ~3 Å Helmholtz layer, 1 cm^2 electrode

% ════════════════════════════════════════════════════════════════════

arguments
    epsilon (1,1) double {mustBePositive}
    d       (1,1) double {mustBePositive}   % nm
    A       (1,1) double {mustBePositive}   % cm^2
end

C_const = calc.constants();

dM  = d * 1e-9;           % nm → m
Am2 = A * 1e-4;           % cm^2 → m^2

Cap    = C_const.eps0 * epsilon * Am2 / dM;   % F
CuF    = Cap * 1e6;                            % µF
CpF    = Cap * 1e12;                           % pF
Cspec  = Cap / A;                              % F/cm^2

result.C     = Cap;
result.CuF   = CuF;
result.CpF   = CpF;
result.Cspec = Cspec;
result.latex = sprintf('$C = %.4g\\,\\mu\\text{F}$', CuF);
end
