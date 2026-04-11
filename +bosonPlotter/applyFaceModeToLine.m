function applyFaceModeToLine(h, faceMode)
%APPLYFACEMODETOLINE  Set MarkerFaceColor mode on a Line / ErrorBar.
%
%   bosonPlotter.applyFaceModeToLine(h, 'none')   % outline (default)
%   bosonPlotter.applyFaceModeToLine(h, 'auto')   % filled, matches line
%
%   'none' leaves markers as outlines (MATLAB default).
%   'auto' fills the marker with the same colour as the line edge —
%   useful for publication plots where filled markers read better
%   against busy backgrounds.
%
%   Unknown / empty faceMode values are silently ignored.

    if ~isvalid(h), return; end
    try
        if ~isprop(h, 'MarkerFaceColor'), return; end
    catch
        return;
    end

    switch lower(char(faceMode))
        case 'none'
            try set(h, 'MarkerFaceColor', 'none'); catch, end
        case 'auto'
            % 'auto' mirrors the line colour.  Strip any alpha channel —
            % face colour uses RGB only, MATLAB rejects [R G B A] on
            % MarkerFaceColor.
            try
                c = get(h, 'Color');
                if isnumeric(c) && numel(c) >= 3
                    set(h, 'MarkerFaceColor', c(1:3));
                end
            catch
            end
        otherwise
            % Unknown — leave alone
    end
end
