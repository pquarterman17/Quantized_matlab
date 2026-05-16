function resampleDataset(appData, fig, cb)
%RESAMPLEDATASET  Resample active dataset to a uniform x-grid.
%
%   bosonPlotter.resampleDataset(appData, fig, cb)
%
%   Inputs:
%     appData - AppState handle
%     fig     - uifigure
%     cb      - struct with fields: buildDs, rebuildDatasetList,
%               updateControlsForActiveDataset, onPlot, recordAction

    if isempty(appData.datasets) || appData.activeIdx < 1
        uialert(fig, 'Load a file first.', 'No data'); return;
    end
    ds = appData.datasets{appData.activeIdx};
    d = guiTernary_(~isempty(ds.corrData), ds.corrData, ds.data);
    if isdatetime(d.time)
        uialert(fig, 'Cannot resample datetime x-axes.', 'Error'); return;
    end
    xVec = double(d.time);
    xLo = min(xVec); xHi = max(xVec);
    nPts = numel(xVec);
    answer = inputdlg({'X min:', 'X max:', 'Number of points:'}, ...
        'Resample Dataset', [1 40], {num2str(xLo), num2str(xHi), num2str(nPts)});
    if isempty(answer), return; end
    newXMin = str2double(answer{1}); newXMax = str2double(answer{2});
    newN    = round(str2double(answer{3}));
    if isnan(newXMin) || isnan(newXMax) || isnan(newN) || newN < 2
        uialert(fig, 'Invalid parameters.', 'Error'); return;
    end
    newX = linspace(newXMin, newXMax, newN)';
    newVals = zeros(newN, size(d.values, 2));
    for k = 1:size(d.values, 2)
        newVals(:, k) = interp1(xVec, d.values(:, k), newX, 'pchip', NaN);
    end
    resD = d;
    resD.time   = newX;
    resD.values = newVals;
    dsNew = cb.buildDs(ds.filepath, resD, 'resampled');
    [~, fn, fext] = fileparts(ds.filepath);
    dsNew.displayName = [fn fext ' (resampled)'];
    dsNew.legendName  = [fn fext ' (resampled)'];
    appData.datasets{end+1} = dsNew;
    appData.model.addDataset(dsNew.data, dsNew.filepath, dsNew.parserName);
    appData.activeIdx = numel(appData.datasets);
    cb.rebuildDatasetList(true);
    cb.updateControlsForActiveDataset();
    cb.onPlot();
    cb.recordAction(sprintf('%% Resample: %d pts [%.4g, %.4g]', newN, newXMin, newXMax));
end

function out = guiTernary_(cond, ifTrue, ifFalse)
    if cond, out = ifTrue; else, out = ifFalse; end
end
