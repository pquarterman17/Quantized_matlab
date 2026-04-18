function cb = undoCallbacks(ctx)
%UNDOCALLBACKS  Return callback struct for undo/redo toolbar buttons.
%   ctx fields: appData, btnUndo, btnRedo, setStatus, onPlot.
%
%   Returned struct exposes:
%     cb.onUndo(src, evt)             — pop topmost undo entry and re-render
%     cb.onRedo(src, evt)             — re-apply next redo entry and re-render
%     cb.updateUndoButtons()          — sync button Enable/Tooltip to UndoManager state

    appData   = ctx.appData;
    btnUndo   = ctx.btnUndo;
    btnRedo   = ctx.btnRedo;
    setStatus = ctx.setStatus;
    onPlot    = ctx.onPlot;

    cb.onUndo             = @onUndo;
    cb.onRedo             = @onRedo;
    cb.updateUndoButtons  = @updateUndoButtons;

    function onUndo(~,~)
        entry = appData.undoMgr.undo();
        if isempty(entry)
            setStatus('Nothing to undo.');
            return;
        end
        setStatus(['Undid: ' entry.label]);
        updateUndoButtons();
        onPlot([],[]);
    end

    function onRedo(~,~)
        entry = appData.undoMgr.redo();
        if isempty(entry)
            setStatus('Nothing to redo.');
            return;
        end
        setStatus(['Redid: ' entry.label]);
        updateUndoButtons();
        onPlot([],[]);
    end

    function updateUndoButtons()
        if appData.undoMgr.canUndo()
            btnUndo.Enable = 'on';
        else
            btnUndo.Enable = 'off';
        end
        if appData.undoMgr.canRedo()
            btnRedo.Enable = 'on';
        else
            btnRedo.Enable = 'off';
        end
        btnUndo.Tooltip = [appData.undoMgr.undoLabel() '  [Ctrl+Z]'];
        btnRedo.Tooltip = [appData.undoMgr.redoLabel() '  [Ctrl+Y]'];
    end
end
