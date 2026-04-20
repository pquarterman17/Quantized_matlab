function applyAxisPrefix(targetAx, whichAxis, prefixInfo)
%APPLYAXISPREFIX  Rescale plotted data and axis label by an SI prefix.
%
% Syntax
%   bosonPlotter.applyAxisPrefix(targetAx, whichAxis, prefixInfo)
%
% Behaviour
%   Scales `XData` / `YData` (and errorbar deltas) on every child of
%   `targetAx` by `prefixInfo.factor`, then rewrites the axis label so
%   the unit string reflects the new prefix.  If the unit string already
%   carries an SI prefix (e.g. `(um)`), the existing prefix is stripped
%   before the new one is prepended — `'um' + nano → 'nm'`, not `'num'`.
%
%   Call is a no-op when `prefixInfo.factor == 1`.
%
% Inputs
%   targetAx    - Axes handle
%   whichAxis   - char: 'x' or 'y'
%   prefixInfo  - struct with
%                   .symbol  char — SI prefix (e.g. 'k', 'm', 'u')
%                   .factor  double — multiplicative scale (e.g. 1e-3)

    if prefixInfo.factor == 1
        return;  % no scaling needed
    end
    fac = prefixInfo.factor;
    sym = prefixInfo.symbol;

    % Rescale data on all line/errorbar children
    children = findall(targetAx, '-property', [upper(whichAxis) 'Data']);
    for ci = 1:numel(children)
        ch = children(ci);
        switch whichAxis
            case 'x'
                ch.XData = ch.XData * fac;
            case 'y'
                ch.YData = ch.YData * fac;
                % Also scale error bar deltas if present
                if isprop(ch, 'YNegativeDelta') && ~isempty(ch.YNegativeDelta)
                    ch.YNegativeDelta = ch.YNegativeDelta * abs(fac);
                    ch.YPositiveDelta = ch.YPositiveDelta * abs(fac);
                end
        end
    end

    % Reset axis limits to auto so they fit the rescaled data
    switch whichAxis
        case 'x', targetAx.XLimMode = 'auto';
        case 'y', targetAx.YLimMode = 'auto';
    end

    % Update axis label: strip any existing SI prefix from the unit
    % and replace with the new one.
    % e.g. "Depth (um)" + nano → "Depth (nm)"  (not "Depth (num)")
    switch whichAxis
        case 'x', lbl = targetAx.XLabel.String;
        case 'y', lbl = targetAx.YLabel.String;
    end
    if ~isempty(lbl)
        tok = regexp(lbl, '^(.*)\(([^)]+)\)(.*)', 'tokens', 'once');
        if ~isempty(tok)
            unitStr  = tok{2};
            baseUnit = localStripSIPrefix(unitStr);
            newUnit  = [sym baseUnit];
            newLbl   = [tok{1} '(' newUnit ')' tok{3}];
        else
            % No parenthesised unit found — append prefix notation
            newLbl = sprintf('%s  [%s%s]', lbl, sym, char(215));
        end
        switch whichAxis
            case 'x', xlabel(targetAx, newLbl);
            case 'y', ylabel(targetAx, newLbl);
        end
    end
end

% ═════════════════════════════════════════════════════════════════════════
%  File-local helpers
% ═════════════════════════════════════════════════════════════════════════

function baseUnit = localStripSIPrefix(unitStr)
%LOCALSTRIPSIPREFIX  Remove a leading SI prefix from a unit string.
%   'um' → 'm', 'nm' → 'm', 'kOe' → 'Oe', 'mV' → 'V', 'MeV' → 'eV'
%   Handles µ (char 956), and common multi-char units (emu, eV, Ang).
    mu = char(956);  % µ
    % Ordered longest-first to avoid partial matches (e.g. 'meV' vs 'm'+'eV')
    knownPrefixes = {'G','M','k','m',mu,'u','n','p','f','a'};
    unitStr = strtrim(unitStr);
    if isempty(unitStr)
        baseUnit = unitStr;
        return;
    end
    for kp = 1:numel(knownPrefixes)
        pfx = knownPrefixes{kp};
        if startsWith(unitStr, pfx) && numel(unitStr) > numel(pfx)
            candidate = unitStr(numel(pfx)+1 : end);
            % Reject if stripping creates a non-unit (e.g. stripping 'k' from 'kg')
            % Accept if the remainder starts with an uppercase letter or known unit
            if localIsKnownBaseUnit(candidate)
                baseUnit = candidate;
                return;
            end
        end
    end
    % No prefix found — return as-is
    baseUnit = unitStr;
end

function tf = localIsKnownBaseUnit(s)
%LOCALISKNOWNBASEUNIT  Check if a string looks like a valid base unit.
    known = {'m','V','A','Oe','T','eV','emu','Hz','s','K','Pa', ...
             'Ang','W','J','N','bar','counts','cps','mol','g','B', ...
             char(197), 'rad', 'deg', 'arb'};  % Å = char(197)
    for ki = 1:numel(known)
        if strcmp(s, known{ki})
            tf = true;
            return;
        end
    end
    if ~isempty(s) && s(1) >= 'A' && s(1) <= 'Z'
        tf = true;
        return;
    end
    if contains(s, '/') || contains(s, '^') || contains(s, char(183))
        tf = true;
        return;
    end
    tf = false;
end
