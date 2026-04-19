function extract2DLineCut(appData, ui, callbacks, clickX, clickY, isHorizontal)
%EXTRACT2DLINECUT  Extract a 1D slice from the active 2D intensity map.
%
% Syntax
%   bosonPlotter.extract2DLineCut(appData, ui, callbacks, clickX, clickY, isHorizontal)
%
% Behaviour
%   isHorizontal == true  (Shift+click): row cut — fixed Omega → I vs 2Theta
%   isHorizontal == false (Ctrl+click):  col cut — fixed 2Theta → I vs Omega
%   The extracted profile is added as a new dataset in appData.datasets.
%   Honours the Q-space checkbox (ui.cbMap2DQSpace): when ticked and the
%   map has Qx/Qz grids, the cut is extracted along Q coordinates and
%   labelled with the Å⁻¹ axis name.
%
% Inputs
%   appData      - bosonPlotter.AppState handle (reads datasets /
%                  activeIdx / model; mutates datasets)
%   ui           - Struct with widget handles: cbMap2DQSpace
%   callbacks    - Struct of function handles:
%                    .buildDs(fp, data, parserName) -> dataset struct
%                    .rebuildDatasetList(keepIdx)
%                    .updateControlsForActiveDataset()
%   clickX       - X coordinate of the click (data units)
%   clickY       - Y coordinate of the click (data units)
%   isHorizontal - Logical; true for Shift+click row cut, false for
%                  Ctrl+click column cut

    if appData.activeIdx < 1 || isempty(appData.datasets), return; end
    ds = appData.datasets{appData.activeIdx};
    if ~is2DDataset(ds), return; end

    map = ds.data.metadata.parserSpecific.map2D;
    [~, fn, fext] = fileparts(ds.filepath);

    % Determine whether the axes are currently displaying Q-space coordinates
    useQSpace = ui.cbMap2DQSpace.Value && isfield(map, 'Qx');

    if isHorizontal
        if useQSpace
            % Shift+click in Q-space: find row whose mean Qz is closest to clickY
            meanQz = mean(map.Qz, 2);   % [N×1]
            [~, rowIdx] = min(abs(meanQz - clickY));
            xVec = map.Qx(rowIdx, :)';
            xColName = 'Q_x (Ang^-1)';
            cutLabel = sprintf('H-cut  Qz\x2248%.4g \x212B\x207B\xB9', meanQz(rowIdx));
        else
            [~, rowIdx] = min(abs(map.axis1 - clickY));
            xVec = map.axis2(:);
            xColName = [map.axis2Name ' (' map.axis2Unit ')'];
            cutLabel = sprintf('H-cut  %s=%.4g %s', ...
                map.axis1Name, map.axis1(rowIdx), map.axis1Unit);
        end
        yVec = map.intensity(rowIdx, :)';
    else
        if useQSpace
            % Ctrl+click in Q-space: find col whose mean Qx is closest to clickX
            meanQx = mean(map.Qx, 1);   % [1×M]
            [~, colIdx] = min(abs(meanQx - clickX));
            xVec = map.Qz(:, colIdx);
            xColName = 'Q_z (Ang^-1)';
            cutLabel = sprintf('V-cut  Qx\x2248%.4g \x212B\x207B\xB9', meanQx(colIdx));
        else
            [~, colIdx] = min(abs(map.axis2 - clickX));
            xVec = map.axis1(:);
            xColName = [map.axis1Name ' (' map.axis1Unit ')'];
            cutLabel = sprintf('V-cut  %s=%.4g %s', ...
                map.axis2Name, map.axis2(colIdx), map.axis2Unit);
        end
        yVec = map.intensity(:, colIdx);
    end

    % Minimal metadata for the line-cut
    meta.source      = ds.filepath;
    meta.importDate  = datetime('now');
    meta.parserName  = 'lineCut';
    meta.xColumnName = xColName;
    meta.xColumnUnit = '';
    meta.parserSpecific = struct('is2D', false, ...
        'originFile', ds.filepath, 'cutLabel', cutLabel);
    cutData = parser.createDataStruct(xVec, yVec, ...
        'labels',   {['I (' map.intensityUnit ')']}, ...
        'units',    {map.intensityUnit}, ...
        'metadata', meta);

    newDs             = callbacks.buildDs('[lineCut]', cutData, 'lineCut');
    newDs.displayName = cutLabel;
    newDs.legendName  = cutLabel;
    appData.datasets{end+1} = newDs;
    try
        appData.model.addDataset(newDs.data, newDs.filepath, newDs.parserName);
    catch
    end
    callbacks.rebuildDatasetList(numel(appData.datasets));
    callbacks.updateControlsForActiveDataset();
    fprintf('[BosonPlotter] Line-cut added: %s — %s\n', [fn fext], cutLabel);
end

% ════════════════════════════════════════════════════════════════════════
% Local helper (duplicated from BosonPlotter.m module-level scope)
% ════════════════════════════════════════════════════════════════════════

function tf = is2DDataset(ds)
%IS2DDATASET  True when ds holds a 2D area-detector XRDML map.
    tf = isfield(ds, 'data') && ...
         isfield(ds.data, 'metadata') && ...
         isfield(ds.data.metadata, 'parserSpecific') && ...
         isfield(ds.data.metadata.parserSpecific, 'is2D') && ...
         isequal(ds.data.metadata.parserSpecific.is2D, true);
end
