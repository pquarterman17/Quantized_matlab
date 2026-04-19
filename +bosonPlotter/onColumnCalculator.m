function onColumnCalculator(appData, fig, callbacks)
%ONCOLUMNCALCULATOR  Per-dataset column math dialog.
%
% Syntax
%   bosonPlotter.onColumnCalculator(appData, fig, callbacks)
%
% Behaviour
%   Presents an `inputdlg` that lists the active dataset's columns as
%   `C1, C2, ...` identifiers and prompts for an expression plus a new
%   column name.  The expression is evaluated with
%   `bosonPlotter.safeEvalMathExpr` (no `eval`) — supported operators
%   are `+ - * / .* ./ ^ .^` and the usual elementwise math functions.
%   The result must be a vector matching the dataset length; it is
%   appended to either `ds.data.values` or `ds.corrData.values`
%   (whichever is the "live" surface for the dataset), together with
%   the supplied label and an empty unit.  On success the GUI is
%   refreshed and the action is logged to the macro.  On failure a
%   `uialert` is shown without throwing.
%
% Inputs
%   appData   - bosonPlotter.AppState handle (mutates datasets, model)
%   fig       - Main figure handle (uialert parent)
%   callbacks - Struct of function handles:
%                 .updateControlsForActiveDataset()
%                 .onPlot()
%                 .setStatus(msg)
%                 .recordAction(comment)

    if isempty(appData.datasets) || appData.activeIdx < 1
        uialert(fig, 'Load a file first.', 'No data');
        return;
    end
    ds = appData.datasets{appData.activeIdx};
    if ~isempty(ds.corrData)
        d = ds.corrData;
    else
        d = ds.data;
    end
    colInfo = cell(1, numel(d.labels));
    for ci = 1:numel(d.labels)
        colInfo{ci} = sprintf('  C%d = %s', ci, d.labels{ci});
    end
    prompt = sprintf(['Create a new column from existing columns.\n\n' ...
                      'Available columns:\n%s\n\n' ...
                      'Use C1, C2, ... to reference columns.\n' ...
                      'Examples: C1./C2,  log10(C1),  C1*1e3'], ...
                      strjoin(colInfo, '\n'));
    answer = inputdlg({prompt, 'New column name:'}, ...
        'Column Calculator', [1 60; 1 40], {'C1 ./ C2', 'Derived'});
    if isempty(answer), return; end
    expr = strtrim(answer{1});
    colName = strtrim(answer{2});
    if isempty(expr) || isempty(colName), return; end
    try
        colVars = struct();
        for ci = 1:numel(d.labels)
            colVars.(sprintf('C%d', ci)) = d.values(:, ci);
        end
        yResult = bosonPlotter.safeEvalMathExpr(expr, colVars);
        if ~isnumeric(yResult) || numel(yResult) ~= size(d.values, 1)
            error('Result must be a vector with %d elements.', size(d.values, 1));
        end
        d.values = [d.values, yResult(:)];
        d.labels{end+1} = colName;
        d.units{end+1}  = '';
        if ~isempty(ds.corrData)
            ds.corrData = d;
        else
            ds.data = d;
        end
        appData.datasets{appData.activeIdx} = ds;
        try
            appData.model.updateDataset(appData.activeIdx, ds);
        catch
        end
        callbacks.updateControlsForActiveDataset();
        callbacks.onPlot();
        callbacks.setStatus(sprintf('Added column "%s".', colName));
        callbacks.recordAction(sprintf('%% Column calculator: %s = %s', colName, expr));
    catch ME
        uialert(fig, sprintf('Expression error:\n%s', ME.message), 'Column Calculator Error');
    end
end
