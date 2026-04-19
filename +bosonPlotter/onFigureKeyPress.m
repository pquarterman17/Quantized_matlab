function onFigureKeyPress(appData, widgets, callbacks, e)
%ONFIGUREKEYPRES  Handle keyboard shortcuts for the main figure.
%
% Syntax
%   bosonPlotter.onFigureKeyPress(appData, widgets, callbacks, e)
%
% Shortcuts
%   Delete          — remove selected dataset(s)
%   Ctrl+S          — save session
%   Ctrl+Z          — undo last operation
%   Ctrl+Y / Ctrl+Shift+Z — redo last undone operation
%   Ctrl+E          — export CSV
%   Ctrl+C          — copy plot to clipboard
%   Ctrl+M          — unmask all
%   Ctrl+L          — focus dataset list
%   Ctrl+Shift+Y    — focus Y channel selector
%   Left/Right      — switch active dataset
%   Space           — toggle dataset visibility
%   Ctrl+Up         — move dataset up
%   Ctrl+Down       — move dataset down
%   Alt+Up/Down     — cycle SI prefix on Y (Alt+Shift = X)
%   F5              — refresh state (flush caches, re-sync widgets, redraw)
%
% Inputs
%   appData   - bosonPlotter.AppState handle (reads activeIdx /
%               datasets; mutates axisPrefixX / axisPrefixY)
%   widgets   - Struct with handles: .lbY, .lbDatasets
%   callbacks - Struct of function handles:
%                 .refreshState()
%                 .onRemoveDataset([],[])
%                 .onSaveSession([],[])
%                 .onUndo([],[])    - appData.undoCb.onUndo
%                 .onRedo([],[])    - appData.undoCb.onRedo
%                 .onUnmaskAll([],[])
%                 .onSaveCSV([],[])
%                 .onCopyToClipboard([],[])
%                 .onToggleDatasetVisibility([],[])
%                 .onMoveDatasetUp([],[])
%                 .onMoveDatasetDown([],[])
%                 .rebuildDatasetList(tf)
%                 .updateControlsForActiveDataset()
%                 .onPlot()
%                 .setStatus(msg)
%   e         - KeyPressedData event struct (Key, Modifier)

    hasMod   = ~isempty(e.Modifier);
    hasCtrl  = hasMod && any(strcmp(e.Modifier, 'control'));
    hasShift = hasMod && any(strcmp(e.Modifier, 'shift'));
    hasAlt   = hasMod && any(strcmp(e.Modifier, 'alt'));

    switch e.Key
        case 'f5'
            callbacks.refreshState();
            return;
        case 'delete'
            if ~isempty(widgets.lbDatasets.Value) && ~isempty(appData.datasets)
                callbacks.onRemoveDataset([], []);
            end

        case 's'
            if hasCtrl, callbacks.onSaveSession([], []); end

        case 'z'
            if hasCtrl && hasShift
                callbacks.onRedo([], []);  % Ctrl+Shift+Z = redo
            elseif hasCtrl
                callbacks.onUndo([], []);  % Ctrl+Z = undo
            end

        case 'y'
            if hasCtrl && hasShift
                focus(widgets.lbY);      % Ctrl+Shift+Y → Y channel selector
            elseif hasCtrl
                callbacks.onRedo([], []);  % Ctrl+Y = redo
            end

        case 'm'
            if hasCtrl, callbacks.onUnmaskAll([], []); end

        case 'e'
            if hasCtrl, callbacks.onSaveCSV([], []); end

        case 'c'
            if hasCtrl, callbacks.onCopyToClipboard([], []); end

        case 'l'
            if hasCtrl, focus(widgets.lbDatasets); end  % Ctrl+L → dataset list

        case 'leftarrow'
            if ~hasCtrl && appData.activeIdx > 1
                appData.activeIdx = appData.activeIdx - 1;
                callbacks.rebuildDatasetList(true);
                callbacks.updateControlsForActiveDataset();
                callbacks.onPlot();
            end

        case 'rightarrow'
            if ~hasCtrl && appData.activeIdx < numel(appData.datasets)
                appData.activeIdx = appData.activeIdx + 1;
                callbacks.rebuildDatasetList(true);
                callbacks.updateControlsForActiveDataset();
                callbacks.onPlot();
            end

        case 'space'
            if ~isempty(appData.datasets) && appData.activeIdx > 0
                callbacks.onToggleDatasetVisibility([], []);
            end

        case 'uparrow'
            if hasAlt
                % Alt+Up = cycle Y prefix toward larger units; +Shift = X
                isX = hasShift;
                if isX, curSym = appData.axisPrefixX.symbol;
                else,   curSym = appData.axisPrefixY.symbol;
                end
                ci = find(strcmp(appData.prefixSymbols, curSym), 1);
                if isempty(ci), ci = 1; end
                ni = max(1, ci - 1);
                pf = struct('symbol', appData.prefixSymbols{ni}, 'factor', appData.prefixFactors(ni));
                if isX, appData.axisPrefixX = pf; else, appData.axisPrefixY = pf; end
                callbacks.onPlot();
                callbacks.setStatus(sprintf('%s prefix: %s', guiTernary(isX,'X','Y'), appData.prefixNames{ni}));
            elseif hasCtrl
                callbacks.onMoveDatasetUp([], []);
            end

        case 'downarrow'
            if hasAlt
                % Alt+Down = cycle Y prefix toward smaller units; +Shift = X
                isX = hasShift;
                if isX, curSym = appData.axisPrefixX.symbol;
                else,   curSym = appData.axisPrefixY.symbol;
                end
                ci = find(strcmp(appData.prefixSymbols, curSym), 1);
                if isempty(ci), ci = 1; end
                ni = min(numel(appData.prefixSymbols), ci + 1);
                pf = struct('symbol', appData.prefixSymbols{ni}, 'factor', appData.prefixFactors(ni));
                if isX, appData.axisPrefixX = pf; else, appData.axisPrefixY = pf; end
                callbacks.onPlot();
                callbacks.setStatus(sprintf('%s prefix: %s', guiTernary(isX,'X','Y'), appData.prefixNames{ni}));
            elseif hasCtrl
                callbacks.onMoveDatasetDown([], []);
            end
    end
end

% ════════════════════════════════════════════════════════════════════════
% Local helper (duplicated from BosonPlotter.m module-level scope)
% ════════════════════════════════════════════════════════════════════════

function v = guiTernary(cond, a, b)
    if cond, v = a; else, v = b; end
end
