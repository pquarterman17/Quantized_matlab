function onConvertUnits(appData, fig, callbacks)
%ONCONVERTUNITS  Convert axis / column units for the active dataset.
%
% Syntax
%   bosonPlotter.onConvertUnits(appData, fig, callbacks)
%
% Behaviour
%   Prompts the user for a `From unit` / `To unit` pair via `inputdlg`,
%   then walks the active dataset's columns and converts every column
%   whose unit matches `fromUnit` using `utilities.convertUnits`.
%   Also converts the x-axis (`time` field) when `metadata.xUnit`
%   matches.  On success, replaces `ds.data`, clears `ds.corrData` (so
%   corrections are re-computed against the new units), replots, and
%   records the action to the macro log.  Failures are reported via
%   `uialert` / `logGUIError` without throwing.
%
% Inputs
%   appData   - bosonPlotter.AppState handle (mutates datasets, activeIdx)
%   fig       - Main figure handle (uialert parent)
%   callbacks - Struct of function handles:
%                 .onPlot()        - re-render after conversion
%                 .setStatus(msg)  - status-bar setter
%                 .logGUIError(title, msg, ME)
%                 .recordAction(comment)

    if isempty(appData.datasets) || appData.activeIdx < 1
        uialert(fig, 'Load a dataset first.', 'Convert Units');
        return;
    end
    answer = inputdlg({ ...
        'From unit (e.g. Oe, T, emu, K):', ...
        'To unit (e.g. T, Oe, A*m2, C):'}, ...
        'Convert Units', [1 40; 1 40], {'Oe', 'T'});
    if isempty(answer), return; end
    fromUnit = strtrim(answer{1});
    toUnit   = strtrim(answer{2});
    ds = appData.datasets{appData.activeIdx};
    d = ds.data;
    % Convert all matching columns
    converted = false;
    for ci = 1:numel(d.units)
        if strcmpi(d.units{ci}, fromUnit)
            try
                [d.values(:, ci), newUnit] = utilities.convertUnits( ...
                    d.values(:, ci), fromUnit, toUnit);
                d.units{ci} = newUnit;
                converted = true;
            catch ME
                uialert(fig, sprintf('Conversion failed for %s:\n%s', ...
                    d.labels{ci}, ME.message), 'Error');
                return;
            end
        end
    end
    % Also convert time/x if its unit matches
    if isfield(d.metadata, 'xUnit') && strcmpi(d.metadata.xUnit, fromUnit)
        try
            [d.time, newUnit] = utilities.convertUnits(d.time, fromUnit, toUnit);
            d.metadata.xUnit = newUnit;
            converted = true;
        catch ME
            callbacks.logGUIError('X-axis unit conversion', ME.message, ME);
        end
    end
    if converted
        ds.data = d;
        ds.corrData = [];  % reset corrections since base data changed
        appData.datasets{appData.activeIdx} = ds;
        callbacks.onPlot();
        callbacks.setStatus(sprintf('Converted %s to %s', fromUnit, toUnit));
    else
        uialert(fig, sprintf('No columns with unit "%s" found.', fromUnit), 'Convert Units');
    end
    callbacks.recordAction(sprintf('%% Convert units: %s -> %s', fromUnit, toUnit));
end
