function map = computeQSpace(map)
%COMPUTEQSPACE  Lazily compute Qx/Qz grids for a 2D map struct.
%   map = parser.computeQSpace(map) checks whether the map has a stored
%   wavelength (map.wavelength_A) but no Qx/Qz grids yet, and computes them.
%   If Qx already exists, this is a no-op.
%
%   Standard coplanar geometry:
%     Qx = (4pi/lambda) * sin(theta) * sin(omega - theta)
%     Qz = (4pi/lambda) * sin(theta) * cos(omega - theta)
%   where theta = 2theta/2, omega = motor position (axis1).

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
