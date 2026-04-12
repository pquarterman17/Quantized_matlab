function map = computeQSpace(map)
%COMPUTEQSPACE  Lazily compute Qx/Qz reciprocal-space grids for a 2D map struct.
%
% Syntax
% ------
%   map = parser.computeQSpace(map)
%
% Inputs
% ------
%   map  (struct) 2D area-detector map struct, typically from the
%        .map2D field produced by parser.importXRDML. Required fields:
%          .axis1        — [N×1] double, omega motor positions (degrees)
%          .axis2        — [1×M] double, 2theta positions (degrees)
%          .intensity    — [N×M] double, intensity matrix
%          .wavelength_A — (1×1) double, X-ray wavelength in Angstroms.
%                          If missing, NaN, or <= 0, the function is a no-op.
%        Optional (checked to skip recomputation):
%          .Qx, .Qz     — if .Qx already exists, the function returns immediately
%
% Outputs
% -------
%   map  (struct) Input struct with the following fields added (when
%        wavelength is available and Qx was not already present):
%          .Qx     — [N×M] double, in-plane momentum transfer (Ang^-1)
%          .Qz     — [N×M] double, out-of-plane momentum transfer (Ang^-1)
%          .QxUnit — 'Ang^-1'
%          .QzUnit — 'Ang^-1'
%
%        If wavelength_A is absent/invalid or .Qx already exists, the
%        struct is returned unchanged (no-op).
%
% Notes
% -----
%   Standard coplanar geometry (symmetric diffraction):
%     theta  = 2theta / 2
%     Qx = (4pi/lambda) * sin(theta) * sin(omega - theta)
%     Qz = (4pi/lambda) * sin(theta) * cos(omega - theta)
%   where omega = axis1 (degrees), 2theta = axis2 (degrees).
%
% Examples
% --------
%   % Called automatically by importXRDML for area-detector files:
%   data = parser.importXRDML('reciprocalmap.xrdml');
%   map  = data.metadata.parserSpecific.map2D;   % .Qx / .Qz already populated
%
%   % Manual usage (e.g., after adding a wavelength to a previously loaded map):
%   map.wavelength_A = 1.5406;   % Cu Kalpha
%   map = parser.computeQSpace(map);
%   surf(map.Qx, map.Qz, log10(map.intensity + 1));
%
% See Also
% --------
%   parser.importXRDML

    if isfield(map, 'Qx')
        return;  % already computed
    end
    if ~isfield(map, 'wavelength_A') || isnan(map.wavelength_A) || map.wavelength_A <= 0
        return;  % no wavelength available
    end

    lambda    = map.wavelength_A;  % Angstroms
    [TT_rad, OM_rad] = meshgrid(deg2rad(map.axis2(:)'), deg2rad(map.axis1(:)));
    theta_rad = TT_rad / 2;
    k0        = 2 * pi / lambda;
    map.Qx    = 2 * k0 .* sin(theta_rad) .* sin(OM_rad - theta_rad);
    map.Qz    = 2 * k0 .* sin(theta_rad) .* cos(OM_rad - theta_rad);
    if ~isfield(map, 'QxUnit')
        map.QxUnit = 'Ang^-1';
        map.QzUnit = 'Ang^-1';
    end
end
