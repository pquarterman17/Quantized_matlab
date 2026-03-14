function xrdConvertGUI()
% ════════════════════════════════════════════════════════════════════════
% Standalone GUI for batch XRD file conversion.
% ════════════════════════════════════════════════════════════════════════
%
% Syntax:
%   xrdConvertGUI()
%
% Description:
%   Opens a uifigure window for batch conversion of XRD files (XRDML, Rigaku, Bruker)
%   to CSV or Origin ASCII format. User selects one or more folders, chooses output
%   options, selects files, and converts. Files from multiple folder locations can be
%   added incrementally. Progress is logged to a text area.
%
% ════════════════════════════════════════════════════════════════════════

% Create main figure
fig = uifigure('Name', 'XRD Batch Converter', 'Position', [100 100 600 720]);
fig.CloseRequestFcn = @onFigureClose;

% Main grid layout  (12 rows: added row 2 for Add Folder / Remove Selected)
mainGL = uigridlayout(fig);
mainGL.RowHeight = {30, 28, '1x', 28, 28, 28, 28, 28, 24, 36, '1x', 22};
mainGL.ColumnWidth = {'1x', '1x', 80};
mainGL.Padding = [8 8 8 8];
mainGL.RowSpacing = 6;
mainGL.ColumnSpacing = 6;

% ════════════════════════════════════════════════════════════════════════
% ROW 1: Set folder (replace list) + path display
% ════════════════════════════════════════════════════════════════════════

btnBrowse = uibutton(mainGL, 'push', 'Text', 'Set Folder...', ...
    'ButtonPushedFcn', @onBrowseFolder, ...
    'Tooltip', 'Replace file list with XRD files from a folder');
btnBrowse.Layout.Row = 1;
btnBrowse.Layout.Column = 1;

efFolderPath = uieditfield(mainGL, 'text', 'Editable', 'off');
efFolderPath.Layout.Row = 1;
efFolderPath.Layout.Column = [2 3];

% ════════════════════════════════════════════════════════════════════════
% ROW 2: Add folder / Remove selected
% ════════════════════════════════════════════════════════════════════════

btnAddFolder = uibutton(mainGL, 'push', 'Text', '+ Add Folder...', ...
    'ButtonPushedFcn', @onAddFolder, ...
    'Tooltip', 'Append XRD files from another folder to the current list');
btnAddFolder.Layout.Row = 2;
btnAddFolder.Layout.Column = 1;

btnRemoveSelected = uibutton(mainGL, 'push', 'Text', 'Remove Selected', ...
    'ButtonPushedFcn', @onRemoveSelected, ...
    'Tooltip', 'Remove highlighted files from the list');
btnRemoveSelected.Layout.Row = 2;
btnRemoveSelected.Layout.Column = 2;

btnClearList = uibutton(mainGL, 'push', 'Text', 'Clear', ...
    'ButtonPushedFcn', @onClearList, ...
    'Tooltip', 'Clear all files from the list');
btnClearList.Layout.Row = 2;
btnClearList.Layout.Column = 3;

% ════════════════════════════════════════════════════════════════════════
% ROW 3: File listbox (multi-select)
% ════════════════════════════════════════════════════════════════════════

lbFiles = uilistbox(mainGL, 'Multiselect', 'on');
lbFiles.Layout.Row = 3;
lbFiles.Layout.Column = [1 3];

% ════════════════════════════════════════════════════════════════════════
% ROW 4: Select All / Deselect All / file count
% ════════════════════════════════════════════════════════════════════════

btnSelectAll = uibutton(mainGL, 'push', 'Text', 'Select All', ...
    'ButtonPushedFcn', @onSelectAll);
btnSelectAll.Layout.Row = 4;
btnSelectAll.Layout.Column = 1;

btnDeselectAll = uibutton(mainGL, 'push', 'Text', 'Deselect All', ...
    'ButtonPushedFcn', @onDeselectAll);
btnDeselectAll.Layout.Row = 4;
btnDeselectAll.Layout.Column = 2;

lblFileCount = uilabel(mainGL, 'Text', 'Ready');
lblFileCount.Layout.Row = 4;
lblFileCount.Layout.Column = 3;
lblFileCount.HorizontalAlignment = 'right';

% ════════════════════════════════════════════════════════════════════════
% ROW 5: Format dropdown
% ════════════════════════════════════════════════════════════════════════

lblFormat = uilabel(mainGL, 'Text', 'Format:');
lblFormat.Layout.Row = 5;
lblFormat.Layout.Column = 1;

ddFormat = uidropdown(mainGL, ...
    'Items', {'Standard CSV', 'Origin ASCII', 'Send to Origin'}, ...
    'Value', 'Standard CSV', ...
    'ValueChangedFcn', @onFormatChanged);
ddFormat.Layout.Row = 5;
ddFormat.Layout.Column = [2 3];

% ════════════════════════════════════════════════════════════════════════
% ROW 6: Intensity dropdown
% ════════════════════════════════════════════════════════════════════════

lblIntensity = uilabel(mainGL, 'Text', 'Intensity:');
lblIntensity.Layout.Row = 6;
lblIntensity.Layout.Column = 1;

ddIntensity = uidropdown(mainGL, ...
    'Items', {'Both (cps + counts)', 'CPS only', 'Counts only'}, ...
    'Value', 'Both (cps + counts)');
ddIntensity.Layout.Row = 6;
ddIntensity.Layout.Column = [2 3];

% ════════════════════════════════════════════════════════════════════════
% ROW 7: Output location dropdown
% ════════════════════════════════════════════════════════════════════════

lblOutput = uilabel(mainGL, 'Text', 'Output:');
lblOutput.Layout.Row = 7;
lblOutput.Layout.Column = 1;

ddOutputLoc = uidropdown(mainGL, ...
    'Items', {'Same folder as source', 'Custom folder...'}, ...
    'Value', 'Same folder as source', ...
    'ValueChangedFcn', @onOutputLocChanged);
ddOutputLoc.Layout.Row = 7;
ddOutputLoc.Layout.Column = [2 3];

% ════════════════════════════════════════════════════════════════════════
% ROW 8: Output path editfield + browse (visible when custom selected)
% ════════════════════════════════════════════════════════════════════════

efOutputDir = uieditfield(mainGL, 'text', 'Editable', 'off');
efOutputDir.Layout.Row = 8;
efOutputDir.Layout.Column = [1 2];
efOutputDir.Visible = 'off';

btnBrowseOutput = uibutton(mainGL, 'push', 'Text', '...', ...
    'ButtonPushedFcn', @onBrowseOutputDir);
btnBrowseOutput.Layout.Row = 8;
btnBrowseOutput.Layout.Column = 3;
btnBrowseOutput.Visible = 'off';

% ════════════════════════════════════════════════════════════════════════
% ROW 9: Metadata checkbox
% ════════════════════════════════════════════════════════════════════════

cbMetadata = uicheckbox(mainGL, 'Text', 'Include metadata header', 'Value', true);
cbMetadata.Layout.Row = 9;
cbMetadata.Layout.Column = [1 3];

% ════════════════════════════════════════════════════════════════════════
% ROW 10: Convert button
% ════════════════════════════════════════════════════════════════════════

btnConvert = uibutton(mainGL, 'push', 'Text', 'Convert', ...
    'ButtonPushedFcn', @onConvert, ...
    'BackgroundColor', [0.2 0.6 0.2]);
btnConvert.Layout.Row = 10;
btnConvert.Layout.Column = [1 3];
btnConvert.FontSize = 13;
btnConvert.FontWeight = 'bold';
btnConvert.Enable = 'off'; % Disabled until files selected

% ════════════════════════════════════════════════════════════════════════
% ROW 11: Log textarea
% ════════════════════════════════════════════════════════════════════════

taLog = uitextarea(mainGL, 'Editable', 'off', 'FontName', 'Courier');
taLog.Layout.Row = 11;
taLog.Layout.Column = [1 3];
taLog.Visible = 'off'; % Hidden until conversion starts

% ════════════════════════════════════════════════════════════════════════
% ROW 12: Status label
% ════════════════════════════════════════════════════════════════════════

lblStatus = uilabel(mainGL, 'Text', 'Ready', 'FontSize', 11);
lblStatus.Layout.Row = 12;
lblStatus.Layout.Column = [1 3];
lblStatus.HorizontalAlignment = 'left';

% ════════════════════════════════════════════════════════════════════════
% App data storage
% ════════════════════════════════════════════════════════════════════════

appData = struct();
appData.folderPaths = {};   % all source folder paths (for multi-folder tracking)
appData.filePaths  = {};    % parallel to listbox Items
appData.fileTypes  = {};
appData.converting = false;

% Store all handles for easy access in callbacks
handles = struct();
handles.fig              = fig;
handles.btnBrowse        = btnBrowse;
handles.btnAddFolder     = btnAddFolder;
handles.btnRemoveSelected = btnRemoveSelected;
handles.btnClearList     = btnClearList;
handles.efFolderPath     = efFolderPath;
handles.lbFiles          = lbFiles;
handles.btnSelectAll     = btnSelectAll;
handles.btnDeselectAll   = btnDeselectAll;
handles.lblFileCount     = lblFileCount;
handles.ddFormat         = ddFormat;
handles.ddIntensity      = ddIntensity;
handles.ddOutputLoc      = ddOutputLoc;
handles.efOutputDir      = efOutputDir;
handles.btnBrowseOutput  = btnBrowseOutput;
handles.cbMetadata       = cbMetadata;
handles.btnConvert       = btnConvert;
handles.taLog            = taLog;
handles.lblStatus        = lblStatus;

fig.UserData = struct('appData', appData, 'handles', handles);

% ════════════════════════════════════════════════════════════════════════
% CALLBACK: Set folder (replace entire list)
% ════════════════════════════════════════════════════════════════════════

    function onBrowseFolder(~, ~)
        folderPath = uigetdir(pwd, 'Select a folder containing XRD files');
        if isequal(folderPath, 0), return; end

        % Replace list with XRD files from this folder
        scanFolderAndReplace(folderPath);
    end

% ════════════════════════════════════════════════════════════════════════
% CALLBACK: Add folder (append to existing list)
% ════════════════════════════════════════════════════════════════════════

    function onAddFolder(~, ~)
        state = fig.UserData;
        startDir = pwd;
        if ~isempty(state.appData.folderPaths)
            startDir = state.appData.folderPaths{end};
        end

        folderPath = uigetdir(startDir, 'Add a folder of XRD files');
        if isequal(folderPath, 0), return; end

        % Append XRD files from this folder, skipping duplicates
        appendFolderToList(folderPath);
    end

% ════════════════════════════════════════════════════════════════════════
% CALLBACK: Remove selected items from list
% ════════════════════════════════════════════════════════════════════════

    function onRemoveSelected(~, ~)
        selectedItems = handles.lbFiles.Value;
        if isempty(selectedItems), return; end

        state = fig.UserData;
        allItems     = handles.lbFiles.Items;
        allPaths     = state.appData.filePaths;
        allTypes     = state.appData.fileTypes;

        % Build keep mask: true for items NOT in the selected set
        keepMask = true(1, numel(allItems));
        for j = 1:numel(selectedItems)
            idx = find(strcmp(allItems, selectedItems{j}), 1);
            if ~isempty(idx)
                keepMask(idx) = false;
            end
        end

        newItems = allItems(keepMask);
        newPaths = allPaths(keepMask);
        newTypes = allTypes(keepMask);

        % Commit to state and UI in one place
        rebuildFileList(state, newItems, newPaths, newTypes);
    end

% ════════════════════════════════════════════════════════════════════════
% CALLBACK: Clear entire file list
% ════════════════════════════════════════════════════════════════════════

    function onClearList(~, ~)
        state = fig.UserData;
        rebuildFileList(state, {}, {}, {});
        handles.efFolderPath.Value = '';
        handles.lblStatus.Text = 'Ready';
    end

% ════════════════════════════════════════════════════════════════════════
% HELPER: Scan a folder and REPLACE the current list
% ════════════════════════════════════════════════════════════════════════

    function scanFolderAndReplace(folderPath)
        state = fig.UserData;
        [newItems, newPaths, newTypes] = scanFolderForXRD(folderPath);

        % Reset folder tracking to just this one folder
        state.appData.folderPaths = {folderPath};

        rebuildFileList(state, newItems, newPaths, newTypes);

        % Update folder path display
        handles.efFolderPath.Value = folderPath;
        handles.taLog.Visible = 'off';
        handles.lblStatus.Text = sprintf('Ready to convert (%d files)', numel(newItems));
    end

% ════════════════════════════════════════════════════════════════════════
% HELPER: Scan a folder and APPEND to the current list (deduplicates)
% ════════════════════════════════════════════════════════════════════════

    function appendFolderToList(folderPath)
        state = fig.UserData;
        [newItems, newPaths, newTypes] = scanFolderForXRD(folderPath);

        if isempty(newItems)
            uialert(fig, sprintf('No XRD files found in:\n%s', folderPath), 'No Files Found');
            return;
        end

        % Deduplicate against existing paths
        existingPaths = state.appData.filePaths;
        addMask = true(1, numel(newPaths));
        for k = 1:numel(newPaths)
            if any(strcmp(existingPaths, newPaths{k}))
                addMask(k) = false;
            end
        end

        nDupes = sum(~addMask);
        nAdded = sum(addMask);

        mergedItems = [handles.lbFiles.Items, newItems(addMask)];
        mergedPaths = [state.appData.filePaths,  newPaths(addMask)];
        mergedTypes = [state.appData.fileTypes,   newTypes(addMask)];

        % Track this folder
        if ~any(strcmp(state.appData.folderPaths, folderPath))
            state.appData.folderPaths{end+1} = folderPath;
        end

        rebuildFileList(state, mergedItems, mergedPaths, mergedTypes);

        % Update folder path display
        nFolders = numel(state.appData.folderPaths);
        if nFolders == 1
            handles.efFolderPath.Value = folderPath;
        else
            handles.efFolderPath.Value = sprintf('Multiple folders (%d)', nFolders);
        end

        % Status feedback
        if nDupes > 0
            handles.lblStatus.Text = sprintf('Added %d file(s), skipped %d duplicate(s) — %d total', ...
                nAdded, nDupes, numel(mergedItems));
        else
            handles.lblStatus.Text = sprintf('Added %d file(s) — %d total', nAdded, numel(mergedItems));
        end
    end

% ════════════════════════════════════════════════════════════════════════
% HELPER: Scan one folder and return XRD file info (no state mutation)
% ════════════════════════════════════════════════════════════════════════

    function [listItems, filePaths, fileTypes] = scanFolderForXRD(folderPath)
        allFiles  = dir(folderPath);
        listItems = {};
        filePaths = {};
        fileTypes = {};

        for i = 1:numel(allFiles)
            f = allFiles(i);
            if f.isdir, continue; end

            [~, ~, ext] = fileparts(f.name);
            ext = lower(ext);

            fileType = '';
            isXRD    = false;

            if strcmp(ext, '.xrdml')
                fileType = 'xrdml';
                isXRD    = true;
            elseif strcmp(ext, '.brml')
                fileType = 'bruker';
                isXRD    = true;
            elseif strcmp(ext, '.raw')
                fullPath = fullfile(f.folder, f.name);
                try
                    fid = fopen(fullPath, 'r');
                    if fid >= 0
                        header = fread(fid, 7, '*char')';
                        fclose(fid);
                        if startsWith(header, 'FI')
                            fileType = 'rigaku'; isXRD = true;
                        elseif startsWith(header, 'RAW1.01')
                            fileType = 'bruker'; isXRD = true;
                        end
                    end
                catch
                end
            end

            if isXRD
                fullPath = fullfile(f.folder, f.name);
                filePaths{end+1} = fullPath; %#ok<AGROW>
                fileTypes{end+1} = fileType; %#ok<AGROW>

                switch fileType
                    case 'xrdml',  badge = '[XRDML]';
                    case 'rigaku', badge = '[Rigaku]';
                    case 'bruker', badge = '[Bruker]';
                    otherwise,     badge = '[???]';
                end
                listItems{end+1} = sprintf('%s %s', badge, f.name); %#ok<AGROW>
            end
        end
    end

% ════════════════════════════════════════════════════════════════════════
% HELPER: Apply a new file list to both state and listbox atomically
% ════════════════════════════════════════════════════════════════════════

    function rebuildFileList(state, newItems, newPaths, newTypes)
        state.appData.filePaths = newPaths;
        state.appData.fileTypes = newTypes;
        fig.UserData = state;

        if isempty(newItems)
            handles.lbFiles.Items = {};
            handles.lbFiles.Value = {};
            handles.lblFileCount.Text = '0 files';
            handles.btnConvert.Enable = 'off';
        else
            handles.lbFiles.Items = newItems;
            handles.lbFiles.Value = newItems;   % select all by default
            handles.lblFileCount.Text = sprintf('%d files', numel(newItems));
            updateConvertButtonState();
        end
    end

% ════════════════════════════════════════════════════════════════════════
% CALLBACK: Select All
% ════════════════════════════════════════════════════════════════════════

    function onSelectAll(~, ~)
        handles.lbFiles.Value = handles.lbFiles.Items;
        updateConvertButtonState();
    end

% ════════════════════════════════════════════════════════════════════════
% CALLBACK: Deselect All
% ════════════════════════════════════════════════════════════════════════

    function onDeselectAll(~, ~)
        handles.lbFiles.Value = {};
        updateConvertButtonState();
    end

% ════════════════════════════════════════════════════════════════════════
% CALLBACK: Format changed
% ════════════════════════════════════════════════════════════════════════

    function onFormatChanged(~, ~)
        isCOM = strcmp(handles.ddFormat.Value, 'Send to Origin');

        if isCOM
            handles.ddOutputLoc.Enable   = 'off';
            handles.efOutputDir.Enable   = 'off';
            handles.btnBrowseOutput.Enable = 'off';
            handles.cbMetadata.Enable    = 'off';
        else
            handles.ddOutputLoc.Enable   = 'on';
            handles.efOutputDir.Enable   = 'on';
            handles.btnBrowseOutput.Enable = 'on';
            handles.cbMetadata.Enable    = 'on';
            isCustom = strcmp(handles.ddOutputLoc.Value, 'Custom folder...');
            handles.efOutputDir.Visible     = onoff(isCustom);
            handles.btnBrowseOutput.Visible = onoff(isCustom);
        end
    end

% ════════════════════════════════════════════════════════════════════════
% CALLBACK: Output location changed
% ════════════════════════════════════════════════════════════════════════

    function onOutputLocChanged(~, ~)
        isCustom = strcmp(handles.ddOutputLoc.Value, 'Custom folder...');
        handles.efOutputDir.Visible     = onoff(isCustom);
        handles.btnBrowseOutput.Visible = onoff(isCustom);
    end

% ════════════════════════════════════════════════════════════════════════
% CALLBACK: Browse output directory
% ════════════════════════════════════════════════════════════════════════

    function onBrowseOutputDir(~, ~)
        folderPath = uigetdir(pwd, 'Select output folder');
        if isequal(folderPath, 0), return; end
        handles.efOutputDir.Value = folderPath;
    end

% ════════════════════════════════════════════════════════════════════════
% CALLBACK: Convert button
% ════════════════════════════════════════════════════════════════════════

    function onConvert(~, ~)
        state = fig.UserData;

        % Get selected files
        selectedItems = handles.lbFiles.Value;
        if isempty(selectedItems), return; end

        % Map selected display items → file paths via state (always in sync via rebuildFileList)
        allItems     = handles.lbFiles.Items;
        allFilePaths = state.appData.filePaths;
        selectedPaths = {};

        % Safety check
        if numel(allItems) ~= numel(allFilePaths)
            uialert(fig, ...
                sprintf(['File list is out of sync (%d items vs %d paths).\n\n' ...
                    'Please use "Set Folder..." or "Add Folder..." to reload.'], ...
                    numel(allItems), numel(allFilePaths)), ...
                'File List Error');
            return;
        end

        for j = 1:numel(selectedItems)
            itemIdx = find(strcmp(allItems, selectedItems{j}), 1);
            if ~isempty(itemIdx)
                selectedPaths{end+1} = allFilePaths{itemIdx}; %#ok<AGROW>
            end
        end

        if numel(selectedPaths) ~= numel(selectedItems)
            uialert(fig, ...
                sprintf('Could not resolve all selected files (%d/%d found). Please try again.', ...
                    numel(selectedPaths), numel(selectedItems)), ...
                'Selection Error');
            return;
        end

        % Validate that all selected files still exist on disk (#19)
        missingFiles = selectedPaths(~cellfun(@isfile, selectedPaths));
        if ~isempty(missingFiles)
            msg = sprintf('%d selected file(s) no longer exist on disk:\n\n%s\n\nRemove them from the list and try again.', ...
                numel(missingFiles), strjoin(missingFiles, '\n'));
            uialert(fig, msg, 'Missing Files');
            return;
        end

        % Map dropdown values to option strings
        switch handles.ddFormat.Value
            case 'Standard CSV';   fmt = 'standard';
            case 'Origin ASCII';   fmt = 'origin';
            case 'Send to Origin'; fmt = 'com';
            otherwise;             fmt = 'standard';
        end

        switch handles.ddIntensity.Value
            case 'Both (cps + counts)'; intensity = 'both';
            case 'CPS only';            intensity = 'cps';
            case 'Counts only';         intensity = 'counts';
            otherwise;                  intensity = 'both';
        end

        % Determine output directory
        if strcmp(fmt, 'com')
            outputDir = '';
        elseif strcmp(handles.ddOutputLoc.Value, 'Same folder as source')
            outputDir = '';
        else
            outputDir = handles.efOutputDir.Value;
        end

        % Disable controls during conversion
        state.appData.converting = true;
        fig.UserData = state;

        handles.btnConvert.Enable = 'off';
        handles.btnConvert.Text   = 'Converting...';
        handles.taLog.Visible     = 'on';
        handles.taLog.Value       = '';
        handles.lblStatus.Text    = 'Converting...';
        drawnow;

        % Create progress dialog
        dlg = uiprogressdlg(fig, ...
            'Title',       'Batch XRD Convert', ...
            'Message',     'Starting...', ...
            'Cancelable',  'on', ...
            'Indeterminate','off');
        cleanupDlg = onCleanup(@() closeIfValid(dlg));

        % Run batch conversion
        try
            results = scripts.batchConvertXRD(selectedPaths, ...
                Format=fmt, ...
                OutputDir=outputDir, ...
                Intensity=intensity, ...
                IncludeMetadata=handles.cbMetadata.Value, ...
                Verbose=false, ...
                ProgressFcn=@(k,n,f) progressCallback(k, n, f, dlg));

            nOk  = sum(cellfun(@isempty, {results.error}));
            nErr = sum(~cellfun(@isempty, {results.error}));

            if nErr == 0
                handles.lblStatus.Text = sprintf('✓ Success: %d files converted', nOk);
            else
                handles.lblStatus.Text = sprintf('%d OK, %d failed', nOk, nErr);
            end

        catch ME
            if ~contains(ME.message, 'cancelled')
                handles.taLog.Value = [handles.taLog.Value, ...
                    sprintf('[ERROR] %s\n', ME.message)];
                handles.lblStatus.Text = 'Conversion failed';
            else
                handles.lblStatus.Text = 'Conversion cancelled by user';
            end
        end

        % Re-enable controls
        state = fig.UserData;
        state.appData.converting = false;
        fig.UserData = state;

        handles.btnConvert.Enable = 'on';
        handles.btnConvert.Text   = 'Convert';
        drawnow;
    end

% ════════════════════════════════════════════════════════════════════════
% CALLBACK: Progress (called from batchConvertXRD)
% ════════════════════════════════════════════════════════════════════════

    function progressCallback(k, n, filename, dlg)
        if isvalid(dlg)
            dlg.Value   = k / n;
            dlg.Message = sprintf('[%d/%d]  %s', k, n, filename);
            if dlg.CancelRequested
                error('xrdConvertGUI:cancelled', 'Conversion cancelled by user.');
            end
        end
        logLine = sprintf('[%d/%d] %s', k, n, filename);
        handles.taLog.Value = [handles.taLog.Value, logLine, newline];
        handles.lblStatus.Text = sprintf('Converting: %d/%d  (%d%%)', k, n, round(100*k/n));
        drawnow;
    end

% ════════════════════════════════════════════════════════════════════════
% HELPER: Update convert button enabled state
% ════════════════════════════════════════════════════════════════════════

    function updateConvertButtonState()
        if ~isempty(handles.lbFiles.Value)
            handles.btnConvert.Enable = 'on';
        else
            handles.btnConvert.Enable = 'off';
        end
    end

% ════════════════════════════════════════════════════════════════════════
% CALLBACK: Figure close
% ════════════════════════════════════════════════════════════════════════

    function onFigureClose(~, ~)
        state = fig.UserData;
        if state.appData.converting
            response = questdlg('Conversion in progress. Close anyway?', ...
                'Close Confirmation', 'Yes', 'No', 'No');
            if strcmp(response, 'No'), return; end
        end
        delete(fig);
    end

end

% ════════════════════════════════════════════════════════════════════════
% UTILITY: Convert boolean to 'on'/'off' string
% ════════════════════════════════════════════════════════════════════════

function str = onoff(bool)
    if bool; str = 'on'; else; str = 'off'; end
end

% ════════════════════════════════════════════════════════════════════════
% UTILITY: Safely close a progress dialog if it's still valid
% ════════════════════════════════════════════════════════════════════════

function closeIfValid(dlg)
    if isvalid(dlg); close(dlg); end
end
