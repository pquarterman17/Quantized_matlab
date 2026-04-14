function [newDs, cutLabel] = extract2DBoxIntegral(ds, bx0, by0, bx1, by1, profileAxis, fig, wgts)
%EXTRACT2DBOXINTEGRAL  Integrate a rectangular region of a 2D map into a 1D profile.
%
%   Syntax:
%     [newDs, cutLabel] = bosonPlotter.extract2DBoxIntegral( ...
%         ds, bx0, by0, bx1, by1, profileAxis, fig, wgts)
%
%   Inputs:
%     ds          - active 2D dataset struct
%     bx0, by0    - box corner in data coordinates (X=axis2, Y=axis1)
%     bx1, by1    - opposite box corner in data coordinates
%     profileAxis - 'axis1' or 'axis2'; [] triggers a dialog (requires fig)
%     fig         - figure handle (for uiconfirm / uialert dialogs)
%     wgts        - widget struct with fields:
%                     .cbMap2DQSpace   - checkbox: show in Q-space
%                     .efBoxIntW       - text editfield: box width (updated in place)
%                     .efBoxIntH       - text editfield: box height (updated in place)
%                     .buildDs         - @(fp,data,pname) function handle to BosonPlotter buildDs
%
%   Outputs:
%     newDs     - new dataset struct ([] if the operation was cancelled or failed)
%     cutLabel  - label string for the extracted profile ('' if cancelled)
%
%   Examples:
%     wgts.cbMap2DQSpace = cbMap2DQSpace;
%     wgts.efBoxIntW     = efBoxIntW;
%     wgts.efBoxIntH     = efBoxIntH;
%     wgts.buildDs       = @buildDs;
%     [newDs, lbl] = bosonPlotter.extract2DBoxIntegral( ...
%         ds, x0, y0, x1, y1, '', fig, wgts);
%     if ~isempty(newDs)
%         appData.datasets{end+1} = newDs;
%     end

    newDs    = [];
    cutLabel = '';

    map = ds.data.metadata.parserSpecific.map2D;

    xLo = min(bx0, bx1);  xHi = max(bx0, bx1);
    yLo = min(by0, by1);  yHi = max(by0, by1);

    % Auto-fill the fixed-size input fields with the drawn box dimensions
    wgts.efBoxIntW.Value = sprintf('%.6g', xHi - xLo);
    wgts.efBoxIntH.Value = sprintf('%.6g', yHi - yLo);

    useQSpace = wgts.cbMap2DQSpace.Value && isfield(map, 'Qx');

    % Find row and column masks within the box
    if useQSpace
        meanQz = mean(map.Qz, 2);  % [N×1]
        meanQx = mean(map.Qx, 1);  % [1×M]
        rowMask = meanQz >= yLo & meanQz <= yHi;
        colMask = meanQx >= xLo & meanQx <= xHi;
    else
        rowMask = map.axis1 >= yLo & map.axis1 <= yHi;
        colMask = map.axis2 >= xLo & map.axis2 <= xHi;
    end

    if ~any(rowMask) || ~any(colMask)
        msg = 'No data points fall within the selected box.';
        if isvalid(fig) && strcmp(fig.Visible, 'on')
            uialert(fig, msg, 'Empty Selection');
        else
            warning('BosonPlotter:emptyBox', '%s', msg);
        end
        return;
    end

    % Determine axis names for dialog
    if useQSpace
        name1 = 'Q_z';
        name2 = 'Q_x';
    else
        name1 = map.axis1Name;
        name2 = map.axis2Name;
    end

    % Ask user for integration direction (or use supplied profileAxis)
    if isempty(profileAxis)
        opt1 = sprintf('Profile vs %s (sum along %s)', name1, name2);
        opt2 = sprintf('Profile vs %s (sum along %s)', name2, name1);
        sel = uiconfirm(fig, ...
            'Choose integration direction:', 'Box Integration', ...
            'Options', {opt1, opt2, 'Cancel'}, ...
            'DefaultOption', 1, 'CancelOption', 3);
        if strcmp(sel, 'Cancel'), return; end
        if strcmp(sel, opt1)
            profileAxis = 'axis1';
        else
            profileAxis = 'axis2';
        end
    end

    Isub = map.intensity(rowMask, colMask);

    if strcmp(profileAxis, 'axis1')
        % Sum across columns (axis2 direction) → profile vs axis1
        yVec = sum(Isub, 2);
        if useQSpace
            xVec = mean(map.Qz(rowMask, colMask), 2);
            xColName = 'Q_z (Ang^-1)';
        else
            xVec = map.axis1(rowMask);
            xColName = [map.axis1Name ' (' map.axis1Unit ')'];
        end
        dirLabel = name2;
    else
        % Sum across rows (axis1 direction) → profile vs axis2
        yVec = sum(Isub, 1)';
        if useQSpace
            xVec = mean(map.Qx(rowMask, colMask), 1)';
            xColName = 'Q_x (Ang^-1)';
        else
            xVec = map.axis2(colMask);
            xColName = [map.axis2Name ' (' map.axis2Unit ')'];
        end
        dirLabel = name1;
    end

    cutLabel = sprintf('Box %s [%.4g–%.4g]%s[%.4g–%.4g] %s %s', ...
        char(8747), xLo, xHi, char(215), yLo, yHi, char(8594), ...
        sprintf('vs %s', strrep(dirLabel, '_', '')));

    meta.source      = ds.filepath;
    meta.importDate  = datetime('now');
    meta.parserName  = 'boxIntegral';
    meta.xColumnName = xColName;
    meta.xColumnUnit = '';
    meta.parserSpecific = struct('is2D', false, ...
        'originFile', ds.filepath, 'cutLabel', cutLabel, ...
        'boxRegion', [xLo xHi yLo yHi], 'profileAxis', profileAxis);
    intData = parser.createDataStruct(xVec, yVec, ...
        'labels',   {['I (' map.intensityUnit ')']}, ...
        'units',    {map.intensityUnit}, ...
        'metadata', meta);

    % Build a self-documenting filepath that carries the source name,
    % integration direction, and both-axis ranges. Replaces the opaque
    % '[boxIntegral]' tag so CSV exports and the dataset list clearly
    % identify the origin.
    [srcDir, srcBase, ~] = fileparts(ds.filepath);
    if isempty(srcDir), srcDir = pwd; end
    safe = @(s) regexprep(char(s), '[^a-zA-Z0-9]', '');
    fmtV = @(v) strrep(strrep(sprintf('%.4g', v), '.', 'p'), '-', 'm');
    ax1Safe = safe(name1);
    ax2Safe = safe(name2);
    if strcmp(profileAxis, 'axis1')
        alongSafe = ax2Safe;     % integrated along axis2 (columns)
    else
        alongSafe = ax1Safe;     % integrated along axis1 (rows)
    end
    newBase = sprintf('%s_boxInt_along%s_%s%s-%s_%s%s-%s', ...
        srcBase, alongSafe, ...
        ax2Safe, fmtV(xLo), fmtV(xHi), ...
        ax1Safe, fmtV(yLo), fmtV(yHi));
    newFilepath = fullfile(srcDir, [newBase '.csv']);

    newDs             = wgts.buildDs(newFilepath, intData, 'boxIntegral');
    newDs.displayName = cutLabel;
    newDs.legendName  = cutLabel;
end
