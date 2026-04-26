function bg = alignSnipBackground(ds, xv)
%ALIGNSNIPBACKGROUND  Interpolate ds.snipBackground onto xv. Returns [] if absent.
    bg = [];
    if ~isfield(ds, 'snipBackground') || isempty(ds.snipBackground), return; end
    sb = ds.snipBackground;
    if ~isfield(sb, 'x') || ~isfield(sb, 'bg') || isempty(sb.x) || isempty(sb.bg)
        return;
    end
    try
        bg = interp1(double(sb.x), double(sb.bg), xv, 'linear', NaN);
        if all(isnan(bg)), bg = []; end
    catch
        bg = [];
    end
end
