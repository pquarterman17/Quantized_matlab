function s = abbreviateVariable(s)
%ABBREVIATEVARIABLE  Map a well-known measurement variable name to its conventional symbol.
%   s = bosonPlotter.abbreviateVariable(s)
%
%   Returns the canonical single-letter (or short) symbol when `s` is a
%   case-insensitive whole-string match for a recognised variable name.
%   Otherwise returns `s` unchanged.
%
%   The TeX axis-label interpreter (MATLAB default) automatically italicises
%   single-letter labels, so the abbreviated output renders as an italic
%   variable in figure axis labels.
%
%   Recognised names:
%       Temperature                              → T
%       Magnetic Field, Field, H, B              → H
%       Moment, Magnetic Moment, M               → M
%       Time, Time Stamp                         → t
%       Voltage                                  → V
%       Current                                  → I
%       Resistance                               → R
%       Resistivity                              → ρ
%       Conductivity                             → σ
%       Frequency                                → f
%       Wavelength                               → λ
%       Pressure                                 → P
%       Energy                                   → E
%       Intensity                                → I
%       Concentration                            → c
%       Angle, 2theta, 2θ                        → preserved (already symbolic)
%
%   Multi-word matches are exact: "Magnetic Field" matches but
%   "Applied Magnetic Field" passes through. This avoids surprising
%   substitutions inside longer descriptive labels.

    if isempty(s), return; end
    s = char(string(s));

    % Strip common surrounding whitespace
    trimmed = strtrim(s);
    key = lower(trimmed);

    map = {
        'temperature',          'T';
        'magnetic field',       'H';
        'applied field',        'H';
        'field',                'H';
        'moment',               'M';
        'magnetic moment',      'M';
        'magnetisation',        'M';
        'magnetization',        'M';
        'time',                 't';
        'time stamp',           't';
        'voltage',              'V';
        'current',              'I';
        'resistance',           'R';
        'resistivity',          'ρ';
        'conductivity',         'σ';
        'frequency',            'f';
        'wavelength',           'λ';
        'pressure',             'P';
        'energy',               'E';
        'intensity',            'I';
        'concentration',        'c';
    };

    for k = 1:size(map, 1)
        if strcmp(key, map{k,1})
            s = map{k,2};
            return;
        end
    end
end
