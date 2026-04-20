function s = smartLabel(name, unit, options)
%SMARTLABEL  Format an axis label with Greek substitution and unit super/subscripts.
%   s = bosonPlotter.smartLabel(name, unit)
%       Returns "Name (unit)" with the following transforms applied to BOTH name
%       and unit:
%         - Spelled-out Greek letter names → Unicode (theta → θ, mu → μ, etc.)
%         - "deg" / "degree" / "degrees" → °
%         - Unit suffix patterns "cm-1", "K^-1", "m^2", "Å^{-2}" → Unicode
%           superscripts (cm⁻¹, K⁻¹, m², Å⁻²)
%
%   s = bosonPlotter.smartLabel(name, unit, Abbreviate=true)
%       Additionally abbreviates well-known measurement variable names to their
%       conventional symbol when the name is an exact whole-string match
%       (case-insensitive). Examples: "Temperature" → "T", "Magnetic Field" → "H",
%       "Moment" → "M", "Resistance" → "R". Single-letter names pass through.
%
%   The TeX axis-label interpreter (MATLAB default) renders single-letter
%   variable names in italics automatically, so an abbreviated label like
%   "T (K)" naturally appears as "*T* (K)".
%
%   Inputs:
%     name        char/string  Variable name (e.g. "Temperature", "2theta", "")
%     unit        char/string  Unit string (e.g. "K", "cm-1", "10^{-6} Å^{-2}", "")
%
%   Name-value:
%     Abbreviate  logical      Apply variable-name abbreviation (default false)
%
%   Output:
%     s           char         Formatted label "Name (unit)" or "Name"

    arguments
        name
        unit
        options.Abbreviate (1,1) logical = false
    end

    name = char(string(name));
    unit = char(string(unit));

    if options.Abbreviate
        name = bosonPlotter.abbreviateVariable(name);
    end

    name = bosonPlotter.greekify(name);
    unit = bosonPlotter.greekify(unit);
    unit = bosonPlotter.unitSuperscript(unit);

    if isempty(unit)
        s = name;
    else
        s = [name, ' (', unit, ')'];
    end
end
