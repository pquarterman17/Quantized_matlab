function datasetMath(appData, fig, callbacks)
%DATASETMATH  Open expression dialog for derived dataset creation.
%
% Syntax
%   bosonPlotter.datasetMath(appData, fig, callbacks)
%
% Behaviour
%   Prompts for an expression referencing datasets by index (D1, D2, ...).
%   Supports element-wise arithmetic, log10, diff, abs, etc., evaluated
%   via bosonPlotter.safeEvalMathExpr (no eval).  When referenced datasets
%   have different x-grids, interp1 aligns them to the first-referenced
%   dataset's x-axis.  diff() reduces length by 1; x-axis auto-trims.
%
% Inputs
%   appData   - bosonPlotter.AppState handle (mutated: datasets, activeIdx, model)
%   fig       - Main BosonPlotter figure handle
%   callbacks - Struct of function handles:
%                 .buildDs(fp, data, parserName)  -> ds struct
%                 .setStatus(msg)
%                 .rebuildDatasetList(keepActive)
%                 .updateControlsForActiveDataset()
%                 .onPlot()
%                 .logGUIError(title, msg, ME)

    if isempty(appData.datasets)
        bosonPlotter.quietAlert(fig,'Load files first.','No data'); return;
    end
    nDS = numel(appData.datasets);

    % Build dataset list for the prompt
    dsNames = cell(1, nDS);
    for dmi = 1:nDS
        [~, fn, ext] = fileparts(appData.datasets{dmi}.filepath);
        dsNames{dmi} = sprintf('  D%d = %s%s', dmi, fn, ext);
    end
    prompt = sprintf(['Enter expression using D1, D2, ... (dataset indices):\n\n' ...
                      'Available datasets:\n%s\n\n' ...
                      'Examples:  D1 - D2,  D1 / D2,  log10(D1),  diff(D1)'], ...
                      strjoin(dsNames, '\n'));

    answer = inputdlg(prompt, 'Dataset Math', [1 60], {'D1 - D2'});
    if isempty(answer), return; end
    expr = strtrim(answer{1});
    if isempty(expr), return; end

    try
        % Parse referenced dataset indices (D1, D2, ...)
        allRefs = regexp(expr, 'D(\d+)', 'tokens');
        refIdxs = unique(cellfun(@(c) str2double(c{1}), allRefs));

        if any(refIdxs < 1 | refIdxs > nDS)
            error('Dataset index out of range (1 to %d).', nDS);
        end

        % Use corrected data if available; get first referenced dataset as base
        baseIdx = refIdxs(1);
        baseDs  = appData.datasets{baseIdx};
        baseD   = guiTernary(~isempty(baseDs.corrData), baseDs.corrData, baseDs.data);
        xBase   = double(baseD.time);

        % Build variable map: D1 → y-values (first channel), interp to base x-grid
        vars = struct();
        for ri = 1:numel(refIdxs)
            di = refIdxs(ri);
            dsi = appData.datasets{di};
            d   = guiTernary(~isempty(dsi.corrData), dsi.corrData, dsi.data);
            yVec = d.values(:, 1);  % use first y-channel
            if di ~= baseIdx
                % Interpolate to base x-grid
                yVec = interp1(double(d.time), yVec, xBase, 'linear', NaN);
            end
            vars.(sprintf('D%d', di)) = yVec;
        end

        % Evaluate expression safely — no eval(); uses dispatch-based parser
        yResult = bosonPlotter.safeEvalMathExpr(expr, vars);
        if ~isnumeric(yResult)
            error('Expression did not produce a numeric vector.');
        end
        % diff() reduces length by 1. Auto-trim the x-axis by one
        % element so the result struct stays rectangular. This is
        % a common user expectation; emit a status message so the
        % behaviour is visible in the GUI.
        if numel(yResult) == numel(xBase) - 1
            xBase = xBase(1:end-1);
            callbacks.setStatus(['diff() reduces array length by 1; ' ...
                'trimmed x-axis to match (now ' ...
                sprintf('%d', numel(xBase)) ' points).']);
        elseif numel(yResult) ~= numel(xBase)
            error(['Expression returned %d elements but the base ' ...
                'dataset has %d samples. Check your formula — ' ...
                'resampling or aggregation inside the expression ' ...
                'breaks the x-axis alignment.'], ...
                numel(yResult), numel(xBase));
        end

        % Build result data struct
        resultD        = baseD;
        resultD.time   = xBase;
        resultD.values = yResult(:);
        resultD.labels = {expr};
        resultD.units  = {''};

        ds = callbacks.buildDs(baseDs.filepath, resultD, 'math');
        ds.displayName = ['[math] ' expr];
        ds.legendName  = expr;

        appData.datasets{end+1} = ds;
        appData.model.addDataset(ds.data, ds.filepath, ds.parserName);
        appData.activeIdx       = numel(appData.datasets);

        callbacks.rebuildDatasetList(true);
        callbacks.updateControlsForActiveDataset();
        callbacks.onPlot();
    catch ME
        callbacks.logGUIError('Dataset Math Error', ME.message, ME);
        bosonPlotter.quietAlert(fig, sprintf('Expression error:\n\n%s', ME.message), 'Dataset Math Error');
    end
end

% ════════════════════════════════════════════════════════════════════════
% Local helpers (duplicated from BosonPlotter.m nested function scope)
% ════════════════════════════════════════════════════════════════════════

function v = guiTernary(cond, a, b)
    if cond, v = a; else, v = b; end
end
