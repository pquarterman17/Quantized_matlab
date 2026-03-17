function materials = materialPresets()
%MATERIALPRESETS  Return a struct of common semiconductor material parameters.
%
%   Syntax
%   ------
%   materials = calc.semiconductor.materialPresets()
%
%   Outputs
%   -------
%   materials — struct where each field is a material with sub-fields:
%     .Eg    — bandgap (eV) at 300 K
%     .eps_r — relative permittivity
%     .me    — electron effective mass (in units of m_e)
%     .mh    — hole effective mass (in units of m_e)
%     .name  — full material name
%
%   Example
%   -------
%   m = calc.semiconductor.materialPresets();
%   disp(m.GaAs.Eg)   % 1.42 eV

% ════════════════════════════════════════════════════════════════════

materials.Si    = struct('Eg', 1.12,  'eps_r', 11.7, 'me', 1.08,  'mh', 0.81,  'name', 'Silicon');
materials.Ge    = struct('Eg', 0.66,  'eps_r', 16.0, 'me', 0.55,  'mh', 0.37,  'name', 'Germanium');
materials.GaAs  = struct('Eg', 1.42,  'eps_r', 12.9, 'me', 0.067, 'mh', 0.45,  'name', 'Gallium Arsenide');
materials.InP   = struct('Eg', 1.35,  'eps_r', 12.5, 'me', 0.08,  'mh', 0.6,   'name', 'Indium Phosphide');
materials.GaN   = struct('Eg', 3.4,   'eps_r', 8.9,  'me', 0.2,   'mh', 1.4,   'name', 'Gallium Nitride');
materials.SiC   = struct('Eg', 3.26,  'eps_r', 9.7,  'me', 0.37,  'mh', 1.0,   'name', '4H-SiC');
materials.SiO2  = struct('Eg', 9.0,   'eps_r', 3.9,  'me', 0.5,   'mh', NaN,   'name', 'Silicon Dioxide');
materials.Al2O3 = struct('Eg', 8.8,   'eps_r', 9.0,  'me', 0.4,   'mh', NaN,   'name', 'Sapphire');

end
