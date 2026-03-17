function names = listSubstrates()
%LISTSUBSTRATES  Return a cell array of all available substrate names.
%
%   Syntax:
%     names = calc.substrates.listSubstrates()
%
%   Inputs:
%     (none)
%
%   Outputs:
%     names  — 1-by-N cell array of char; each element is a valid name
%              accepted by calc.substrates.getSubstrate().
%
%   Example:
%     names = calc.substrates.listSubstrates();
%     disp(names')

% ════════════════════════════════════════════════════════════════════
% Retrieve the canonical list from the persistent table in getSubstrate
persistent cachedNames
if ~isempty(cachedNames)
    names = cachedNames;
    return
end

% ════════════════════════════════════════════════════════════════════
% Build by fetching each substrate in turn.
% The list is defined once in getSubstrate; we mirror it here so that
% listSubstrates never needs its own copy of the table.
knownNames = { ...
    'Si(100)',       'Si(111)',       'SiO2/Si',       ...
    'Al2O3(0001)',   'Al2O3(11-20)',  'MgO(100)',      ...
    'SrTiO3(100)',   'GaAs(100)',     'LaAlO3(100)',   ...
    'LSAT(100)',     'Ge(100)',       'InP(100)',       ...
    'YSZ(100)',      'MgAl2O4(100)'                    ...
};

cachedNames = knownNames;
names       = cachedNames;
end
