function sendToOrigin(appData, fig, guiState)
%SENDTOORIGIN  Send active dataset to OriginPro via COM; fall back to clipboard.
%
%   bosonPlotter.sendToOrigin(appData, fig, guiState)
%
%   Inputs:
%     appData  - AppState handle
%     fig      - uifigure
%     guiState - struct with fields: xLabel, yLabel, logX, logY

    if isempty(appData.datasets) || appData.activeIdx < 1
        uialert(fig, 'Load a file first.', 'No data');
        return;
    end
    ds  = appData.datasets{appData.activeIdx};
    src = guiTernary_(~isempty(ds.corrData), ds.corrData, ds.data);
    src = bosonPlotter.applyDisplayUnits(src, ds, appData);
    [~, fn, ~] = fileparts(ds.filepath);

    axLabels = struct();
    if ~isempty(guiState.xLabel)
        axLabels.x = guiState.xLabel;
    end
    if ~isempty(guiState.yLabel)
        axLabels.y = guiState.yLabel;
    end

    ok = utilities.toOrigin(src, ...
        'SheetName',  fn, ...
        'BookName',   'ThinFilmToolkit', ...
        'AxisLabels', axLabels, ...
        'LogY',       guiState.logY, ...
        'LogX',       guiState.logX);

    if ok
        uialert(fig, sprintf('Data sent to OriginPro.\nWorksheet: %s', fn), ...
            'Origin Export');
    else
        clipStr = bosonPlotter.buildClipboardString(appData, appData.activeIdx);
        clipboard('copy', clipStr);
        uialert(fig, ...
            ['Origin not available — data copied to clipboard instead.' newline ...
             'Paste into Origin with Edit > Paste.'], ...
            'Origin not found');
    end
end

function out = guiTernary_(cond, ifTrue, ifFalse)
    if cond, out = ifTrue; else, out = ifFalse; end
end
