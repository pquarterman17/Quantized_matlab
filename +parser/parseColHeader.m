function [name, unit] = parseColHeader(raw)
%PARSECOLHEADER  Split a column header like "Magnetic Field (Oe)" into name + unit.
%
%   [name, unit] = parser.parseColHeader('Magnetic Field (Oe)')
%   → name = 'Magnetic Field', unit = 'Oe'
%
%   [name, unit] = parser.parseColHeader('Time Stamp')
%   → name = 'Time Stamp', unit = ''
%
%   Whitespace is trimmed from both outputs. If no parenthesised unit is
%   present the input string (trimmed) is returned as the name and unit is
%   the empty string. Used by importQDVSM, importPPMS, importLakeShore and
%   any future parser that uses the standard "Name (unit)" header style.

    unit = '';
    name = strtrim(char(raw));
    if isempty(name), return; end

    tok = regexp(name, '^(.+?)\s*\(([^)]+)\)\s*$', 'tokens', 'once');
    if ~isempty(tok)
        name = strtrim(tok{1});
        unit = strtrim(tok{2});
    end
end
