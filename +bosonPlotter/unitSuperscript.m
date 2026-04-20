function s = unitSuperscript(s)
%UNITSUPERSCRIPT  Convert ASCII / TeX-style unit exponents to Unicode super/subscripts.
%   s = bosonPlotter.unitSuperscript(s)
%
%   Recognised exponent patterns (applied to the string in order):
%     1. TeX-form  ^{...}    → Unicode (e.g. "Å^{-2}"   → "Å⁻²")
%     2. Caret     ^N        → Unicode (e.g. "m^2"      → "m²", "K^-1" → "K⁻¹")
%     3. Trailing  unit-N    → Unicode (e.g. "cm-1"     → "cm⁻¹") — only after a
%        recognised unit token to avoid mangling "10-fold" or year strings.
%
%   Recognised unit tokens for the trailing pattern (rule 3):
%       cm, mm, nm, μm, um, km, m, Å, A, K, s, Hz, Oe, T, eV, J, V, mol
%
%   Subscripts: any "_N" or "_{N}" (e.g. "H_2O" → "H₂O") becomes Unicode
%   subscript.
%
%   The transform is idempotent — calling it twice is safe (already-converted
%   superscripts pass through unchanged).
%
%   Examples:
%       unitSuperscript('cm-1')         → 'cm⁻¹'
%       unitSuperscript('m^2')          → 'm²'
%       unitSuperscript('10^{-6} Å^-2') → '10⁻⁶ Å⁻²'
%       unitSuperscript('H_2O')         → 'H₂O'

    if isempty(s), return; end
    s = char(string(s));

    % ── 1. TeX form: ^{...} ─────────────────────────────────────────────
    s = applyPattern(s, '\^\{([+\-0-9]+)\}', @(d) toSuper(d));

    % ── 2. Caret form: ^N or ^-N ────────────────────────────────────────
    s = applyPattern(s, '\^(-?\+?[0-9]+)', @(d) toSuper(d));

    % ── 3. Trailing unit-N (only after recognised unit tokens) ──────────
    unitToken = '(?<=(?:cm|mm|nm|μm|um|km|Å|Hz|Oe|eV|mol|[mAKsTVJ]))';
    s = applyPattern(s, [unitToken, '(-?[0-9]+)\>'], @(d) toSuper(d));

    % ── 4. Subscripts ───────────────────────────────────────────────────
    s = applyPattern(s, '_\{([+\-0-9]+)\}', @(d) toSub(d));
    s = applyPattern(s, '_(-?[0-9]+)',      @(d) toSub(d));
end


function s = applyPattern(s, pat, fn)
%APPLYPATTERN  Replace every regex match with fn(captureGroup1) until exhausted.
    while true
        [tokStart, tokEnd, ~, ~, tokens] = regexp(s, pat, ...
            'start', 'end', 'tokenExtents', 'match', 'tokens', 'once');
        if isempty(tokStart), break; end
        % `tokens` is a 1×N cell of capture groups — first one is what we need.
        captured = tokens{1};
        replacement = fn(captured);
        s = [s(1:tokStart-1), replacement, s(tokEnd+1:end)];
    end
end


function out = toSuper(numStr)
%TOSUPER  Convert "+/-/0-9" string to Unicode superscript characters.
    out = '';
    for k = 1:numel(numStr)
        c = numStr(k);
        switch c
            case '0', out = [out '⁰'];
            case '1', out = [out '¹'];
            case '2', out = [out '²'];
            case '3', out = [out '³'];
            case '4', out = [out '⁴'];
            case '5', out = [out '⁵'];
            case '6', out = [out '⁶'];
            case '7', out = [out '⁷'];
            case '8', out = [out '⁸'];
            case '9', out = [out '⁹'];
            case '-', out = [out '⁻'];
            case '+', out = [out '⁺'];
        end
    end
end


function out = toSub(numStr)
%TOSUB  Convert "+/-/0-9" string to Unicode subscript characters.
    out = '';
    for k = 1:numel(numStr)
        c = numStr(k);
        switch c
            case '0', out = [out '₀'];
            case '1', out = [out '₁'];
            case '2', out = [out '₂'];
            case '3', out = [out '₃'];
            case '4', out = [out '₄'];
            case '5', out = [out '₅'];
            case '6', out = [out '₆'];
            case '7', out = [out '₇'];
            case '8', out = [out '₈'];
            case '9', out = [out '₉'];
            case '-', out = [out '₋'];
            case '+', out = [out '₊'];
        end
    end
end
