function presets = reflSLDPresets()
%REFLSLDPRESETS  Material SLD lookup table for reflectivity modeling.
%
%   presets = fitting.reflSLDPresets()
%
%   Returns a struct array of common materials with their scattering
%   length densities for X-ray and neutron reflectometry.
%
%   Fields per entry:
%       .name     — material name
%       .formula  — chemical formula
%       .sldX     — X-ray SLD (Å⁻², for Cu Kα at ~8 keV)
%       .sldN     — neutron SLD (Å⁻², coherent)
%       .sldImag  — absorption SLD (Å⁻², imaginary part; 0 if negligible)
%       .density  — mass density (g/cm³)
%
%   Example:
%       p = fitting.reflSLDPresets();
%       si = p(strcmp({p.name}, 'Silicon'));
%       fprintf('Si SLD (neutron): %.4e Å⁻²\n', si.sldN);

% Helper to build one entry
    function m = mat(name, formula, sldX, sldN, sldImag, density)
        m.name    = name;
        m.formula = formula;
        m.sldX    = sldX;
        m.sldN    = sldN;
        m.sldImag = sldImag;
        m.density = density;
    end

presets = [ ...
    % ── Substrates ─────────────────────────────────────────────────
    mat('Silicon',         'Si',     20.07e-6,  2.073e-6,  0,       2.33)
    mat('Silicon Oxide',   'SiO2',   18.88e-6,  3.470e-6,  0,       2.20)
    mat('Sapphire',        'Al2O3',  24.51e-6,  5.726e-6,  0,       3.97)
    mat('Glass (borosilicate)','BK7',16.93e-6,  3.960e-6,  0,       2.51)
    mat('Quartz',          'SiO2',   18.88e-6,  4.180e-6,  0,       2.65)

    % ── Metals ─────────────────────────────────────────────────────
    mat('Gold',            'Au',     124.5e-6,  4.460e-6,  0.442e-6, 19.32)
    mat('Silver',          'Ag',      74.4e-6,  3.470e-6,  0,        10.50)
    mat('Platinum',        'Pt',     115.5e-6,  6.350e-6,  0.228e-6, 21.45)
    mat('Copper',          'Cu',      64.3e-6,  6.530e-6,  0.087e-6, 8.96)
    mat('Aluminum',        'Al',      22.0e-6,  2.078e-6,  0,        2.70)
    mat('Titanium',        'Ti',      30.8e-6, -1.950e-6,  0,        4.51)
    mat('Chromium',        'Cr',      54.8e-6,  3.027e-6,  0,        7.19)
    mat('Tantalum',        'Ta',      83.8e-6,  3.830e-6,  0,       16.69)
    mat('Palladium',       'Pd',      80.2e-6,  4.010e-6,  0,       12.02)

    % ── Magnetic metals ────────────────────────────────────────────
    mat('Iron',            'Fe',      59.4e-6,  8.024e-6,  0,        7.87)
    mat('Cobalt',          'Co',      58.9e-6,  2.261e-6,  0,        8.90)
    mat('Nickel',          'Ni',      64.0e-6,  9.408e-6,  0,        8.91)
    mat('Permalloy',       'Ni80Fe20',63.1e-6,  9.120e-6,  0,        8.72)

    % ── Oxides ─────────────────────────────────────────────────────
    mat('Magnetite',       'Fe3O4',   42.3e-6,  6.950e-6,  0,        5.17)
    mat('Alumina',         'Al2O3',   24.5e-6,  5.726e-6,  0,        3.97)
    mat('Titanium Oxide',  'TiO2',    31.0e-6,  2.632e-6,  0,        4.23)
    mat('Hafnium Oxide',   'HfO2',    47.0e-6,  5.160e-6,  0,        9.68)

    % ── Solvents / ambient ─────────────────────────────────────────
    mat('Air / Vacuum',    '',         0,        0,         0,        0)
    mat('Water (H2O)',     'H2O',      9.43e-6, -0.560e-6,  0,       1.00)
    mat('Heavy Water (D2O)','D2O',     9.43e-6,  6.335e-6,  0,       1.11)

    % ── Polymers ───────────────────────────────────────────────────
    mat('Polystyrene',     'PS',      9.60e-6,  1.412e-6,  0,       1.05)
    mat('PMMA',            'PMMA',   10.93e-6,  1.065e-6,  0,       1.18)
    mat('Polyethylene',    'PE',      8.61e-6, -0.280e-6,  0,       0.92)

    % ── Nitrides ───────────────────────────────────────────────────
    mat('Silicon Nitride', 'Si3N4',  22.15e-6,  3.270e-6,  0,       3.17)
    mat('Titanium Nitride','TiN',    33.20e-6, -0.480e-6,  0,       5.22)
];

end
