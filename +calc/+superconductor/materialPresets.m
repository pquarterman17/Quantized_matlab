function presets = materialPresets(opts)
%MATERIALPRESETS  Return a struct of superconductor material properties.
%
%   Syntax
%   ------
%   presets = calc.superconductor.materialPresets()
%   presets = calc.superconductor.materialPresets(Material=name)
%
%   Inputs
%   ------
%   Material — (optional) string name of a single material to retrieve.
%              One of: 'Nb', 'NbN', 'YBCO', 'MgB2', 'Al', 'Pb', 'In', 'Sn'.
%              If omitted, all materials are returned as a scalar struct
%              whose field names are the material names.
%
%   Outputs
%   -------
%   presets — struct (or sub-struct for a single material) with fields:
%     .Tc      — critical temperature (K)
%     .lambda0 — London penetration depth at T=0 (nm)
%     .xi0     — BCS coherence length at T=0 (nm)
%     .Hc0     — thermodynamic critical field at T=0 (Oe)
%     .Delta0  — superconducting gap energy at T=0 (meV)
%     .type    — 'I' or 'II'
%
%   Reference values from: Tinkham, "Introduction to Superconductivity"
%   (2nd ed.), and Orlando & Delin, "Foundations of Applied
%   Superconductivity". NbN/YBCO upper critical fields from thin-film
%   literature.
%
%   Examples
%   --------
%   all = calc.superconductor.materialPresets();
%   nb  = calc.superconductor.materialPresets(Material='Nb');
%   fprintf('Nb Tc = %.2f K\n', nb.Tc);

% ════════════════════════════════════════════════════════════════════

arguments
    opts.Material (1,:) char = ''
end

persistent cachedPresets

if isempty(cachedPresets)
    p = struct();

    % Niobium — canonical type-II elemental superconductor
    p.Nb.Tc      = 9.25;
    p.Nb.lambda0 = 39;
    p.Nb.xi0     = 38;
    p.Nb.Hc0     = 1980;
    p.Nb.Delta0  = 1.55;
    p.Nb.type    = 'II';

    % Niobium nitride — hard type-II, common for superconducting resonators
    p.NbN.Tc      = 16.0;
    p.NbN.lambda0 = 200;
    p.NbN.xi0     = 5;
    p.NbN.Hc0     = 80000;   % approximate Hc2 (type II; Hc1 is ~100 Oe)
    p.NbN.Delta0  = 2.6;
    p.NbN.type    = 'II';

    % YBa2Cu3O7 — high-Tc cuprate
    p.YBCO.Tc      = 92;
    p.YBCO.lambda0 = 150;
    p.YBCO.xi0     = 1.5;
    p.YBCO.Hc0     = 0;      % Hc not well-defined for extreme type-II; set 0
    p.YBCO.Delta0  = 20;
    p.YBCO.type    = 'II';

    % Magnesium diboride
    p.MgB2.Tc      = 39;
    p.MgB2.lambda0 = 140;
    p.MgB2.xi0     = 5;
    p.MgB2.Hc0     = 0;      % Hc not well-defined; set 0
    p.MgB2.Delta0  = 7.1;
    p.MgB2.type    = 'II';

    % Aluminum — classic type-I, used in superconducting qubits
    p.Al.Tc      = 1.18;
    p.Al.lambda0 = 16;
    p.Al.xi0     = 1600;
    p.Al.Hc0     = 105;
    p.Al.Delta0  = 0.172;
    p.Al.type    = 'I';

    % Lead
    p.Pb.Tc      = 7.19;
    p.Pb.lambda0 = 37;
    p.Pb.xi0     = 83;
    p.Pb.Hc0     = 803;
    p.Pb.Delta0  = 1.33;
    p.Pb.type    = 'I';

    % Indium
    p.In.Tc      = 3.41;
    p.In.lambda0 = 24;
    p.In.xi0     = 440;
    p.In.Hc0     = 282;
    p.In.Delta0  = 0.541;
    p.In.type    = 'I';

    % Tin
    p.Sn.Tc      = 3.72;
    p.Sn.lambda0 = 34;
    p.Sn.xi0     = 230;
    p.Sn.Hc0     = 305;
    p.Sn.Delta0  = 0.592;
    p.Sn.type    = 'I';

    cachedPresets = p;
end

if isempty(opts.Material)
    presets = cachedPresets;
else
    validNames = fieldnames(cachedPresets);
    idx = strcmpi(opts.Material, validNames);
    if ~any(idx)
        error('calc:superconductor:unknownMaterial', ...
              'Unknown material ''%s''. Valid options: %s.', ...
              opts.Material, strjoin(validNames, ', '));
    end
    presets = cachedPresets.(validNames{idx});
end
end
