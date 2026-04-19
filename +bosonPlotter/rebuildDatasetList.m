function rebuildDatasetList(appData, ui, keepActiveIdx)
%REBUILDDATASETLIST  Sync lbDatasets Items/ItemsData to appData.datasets.
%
% Syntax
%   bosonPlotter.rebuildDatasetList(appData, ui, keepActiveIdx)
%
% Behaviour
%   Rebuilds the dataset listbox display from appData.datasets.  Each
%   row gets a coloured bullet, a slot number, a parser-type badge
%   (e.g. [XRD]/[MAG]/[NR]), the dataset's legend/display name, and a
%   ✎ glyph if notes exist.  Applies the case-insensitive substring
%   search filter from appData.searchFilter, but always keeps the
%   active dataset visible so it remains selectable.  Colour swatches
%   are applied via uistyle so each row renders in its own plot colour.
%
% Inputs
%   appData       - bosonPlotter.AppState handle (reads datasets /
%                   searchFilter / activeIdx; may mutate activeIdx)
%   ui            - Struct with widget handles: lbDatasets, btnRemoveDS,
%                   btnMerge
%   keepActiveIdx - Logical/scalar; if true, keep the currently active
%                   dataset selected and visible even when filtered out

    lbDatasets  = ui.lbDatasets;
    btnRemoveDS = ui.btnRemoveDS;
    btnMerge    = ui.btnMerge;

    N = numel(appData.datasets);
    if N == 0
        lbDatasets.Items     = {'(no files loaded — click  Add File(s)...  to begin)'};
        lbDatasets.ItemsData = {0};
        lbDatasets.Value     = {0};
        appData.activeIdx    = 0;
        % Disable dataset-dependent buttons when no data loaded
        btnRemoveDS.Enable  = 'off';
        btnMerge.Enable     = 'off';
        return;
    else
        % Re-enable dataset buttons when data is available
        btnRemoveDS.Enable  = 'on';
        btnMerge.Enable     = 'on';
    end

    % Build full display strings for all datasets
    allItems    = cell(1, N);
    allIdxData  = num2cell(1:N);
    dsColors    = zeros(N, 3);  % resolved plot colors for swatch styling
    defaultCols = plotting.lineColors(N);
    for i = 1:N
        dsI = appData.datasets{i};
        badgeStr = getParserBadge(dsI.parserName);
        if isfield(dsI,'legendName') && ~isempty(dsI.legendName)
            displayStr = dsI.legendName;
        elseif isfield(dsI,'displayName') && ~isempty(dsI.displayName)
            displayStr = dsI.displayName;
        else
            [~, fn, fext] = fileparts(dsI.filepath);
            displayStr = [fn, fext];
        end
        noteTag = '';
        if isfield(dsI, 'notes') && ~isempty(dsI.notes)
            noteTag = [' ' char(9998)];  % ✎ pencil
        end
        if isfield(dsI,'color') && ~isempty(dsI.color)
            dsColors(i,:) = dsI.color;
        else
            dsColors(i,:) = defaultCols(i,:);
        end
        allItems{i} = sprintf('%s [%d]  %s  %s%s', char(9679), i, badgeStr, displayStr, noteTag);
    end

    % Apply search filter (always keep active dataset visible)
    filt = strtrim(appData.searchFilter);
    if isempty(filt)
        visIdx = 1:N;
    else
        filtLC = lower(filt);
        visIdx = find(cellfun(@(s) contains(lower(s), filtLC), allItems));
        % Always include active dataset so it stays selectable
        if keepActiveIdx && appData.activeIdx >= 1 && appData.activeIdx <= N
            if ~ismember(appData.activeIdx, visIdx)
                visIdx = sort([visIdx, appData.activeIdx]);
            end
        end
    end

    if isempty(visIdx)
        lbDatasets.Items     = {'(no matches)'};
        lbDatasets.ItemsData = {0};
        lbDatasets.Value     = {0};
        return;
    end

    lbDatasets.Items     = allItems(visIdx);
    lbDatasets.ItemsData = allIdxData(visIdx);

    if keepActiveIdx && appData.activeIdx >= 1 && appData.activeIdx <= N && ...
       ismember(appData.activeIdx, visIdx)
        lbDatasets.Value = {appData.activeIdx};
    else
        appData.activeIdx = visIdx(1);
        lbDatasets.Value  = {visIdx(1)};
    end

    % Apply color swatches via uistyle per visible item
    removeStyle(lbDatasets);
    for si = 1:numel(visIdx)
        s = uistyle('FontColor', dsColors(visIdx(si),:));
        addStyle(lbDatasets, s, 'item', si);
    end
end

% ════════════════════════════════════════════════════════════════════════
% Local helper (duplicated from BosonPlotter.m module-level scope)
% ════════════════════════════════════════════════════════════════════════

function badge = getParserBadge(parserName)
%GETPARSERBADGE  Return a short parser type tag (e.g. [XRD], [VSM], [CSV]).
    switch parserName
        case {'importRigaku_raw', 'importXRDML', 'importBruker'}
            badge = '[XRD]';
        case {'importQDVSM', 'importPPMS', 'importMPMS', 'importLakeShore'}
            badge = '[MAG]';  % Magnetometry
        case {'importNCNRDat', 'importNCNRRefl', 'importNCNRPNR'}
            badge = '[NR]';   % Neutron Reflectometry
        case 'importSIMS'
            badge = '[SIMS]';
        case {'importExcel', 'importCSV'}
            badge = '[DAT]';  % Generic data
        case 'lineCut'
            badge = '[CUT]';  % 1D line-cut extracted from a 2D map
        case 'boxIntegral'
            badge = '[BOX]';  % Box-integrated profile from a 2D map
        case 'arcIntegral'
            badge = '[ARC]';  % Arc-integrated I(|Q|) from a 2D RSM
        otherwise
            badge = '';
    end
end
