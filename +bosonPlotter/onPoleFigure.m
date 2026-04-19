function onPoleFigure(appData, fig, callbacks)
%ONPOLEFIGURE  Polar plot of intensity vs scan angle at a chosen 2θ.
%
% Syntax
%   bosonPlotter.onPoleFigure(appData, fig, callbacks)
%
% Behaviour
%   For 2D area-detector datasets: extracts a single 2θ column from the
%   `parserSpecific.map2D` intensity matrix and plots it in polar
%   coordinates (omega or chi on the angular axis, intensity on the
%   radial axis).  The default 2θ is the column with the highest total
%   intensity; the user can override via `inputdlg`.  The plot opens in
%   a new `figure` window — it is deliberately *not* drawn into the
%   main BosonPlotter axes, so users can keep comparing to other views.
%
% Inputs
%   appData   - bosonPlotter.AppState handle (reads datasets / activeIdx)
%   fig       - Main figure handle (uialert parent)
%   callbacks - Struct of function handles:
%                 .is2DDataset(ds) -> logical

    if isempty(appData.datasets) || appData.activeIdx < 1, return; end
    ds = appData.datasets{appData.activeIdx};
    if ~callbacks.is2DDataset(ds)
        uialert(fig, 'Active dataset is not a 2D area-detector scan.', 'Pole Figure');
        return;
    end

    map = ds.data.metadata.parserSpecific.map2D;
    I   = map.intensity;   % [N × M]
    x2  = map.axis2(:)';   % 2Theta [1×M]
    x1  = map.axis1(:);    % Omega/Chi [N×1]

    [~, peakCol] = max(sum(I, 1));
    answer = inputdlg( ...
        sprintf('Enter 2%s position to extract (range: %.2f to %.2f):', ...
                char(952), x2(1), x2(end)), ...
        'Pole Figure', [1 50], {sprintf('%.3f', x2(peakCol))});
    if isempty(answer), return; end
    target2th = str2double(answer{1});
    if isnan(target2th), return; end

    [~, col] = min(abs(x2 - target2th));
    intensitySlice = I(:, col);

    poleFig = figure('Name', sprintf('Pole Figure — 2%s = %.3f%s', ...
        char(952), x2(col), char(176)), ...
        'NumberTitle', 'off');
    pax = polaraxes(poleFig);

    thetaRad = deg2rad(x1);
    polarplot(pax, thetaRad, intensitySlice, '-', 'LineWidth', 1.5);
    title(pax, sprintf('Intensity at 2%s = %.3f%s', char(952), x2(col), char(176)));
    pax.ThetaZeroLocation = 'top';
    pax.ThetaDir = 'clockwise';

    figure(poleFig);
end
