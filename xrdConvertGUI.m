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
%   to CSV or Origin ASCII format. User selects a folder, chooses output options,
%   selects files, and converts. Progress is logged to a text area.
%
% ════════════════════════════════════════════════════════════════════════

% Create main figure
fig = uifigure('Name', 'XRD Batch Converter', 'Position', [100 100 600 700]);
fig.CloseRequestFcn = @onFigureClose;

% Main grid layout
mainGL = uigridlayout(fig);
mainGL.RowHeight = {30, '1x', 28, 28, 28, 28, 28, 24, 36, '1x', 22};
mainGL.ColumnWidth = {'1x', '1x', 80};
mainGL.Padding = [8 8 8 8];
mainGL.RowSpacing = 6;
mainGL.ColumnSpacing = 6;

% ════════════════════════════════════════════════════════════════════════
% ROW 1: Browse folder + path display
% ════════════════════════════════════════════════════════════════════════

btnBrowse = uibutton(mainGL, 'push', 'Text', 'Browse Folder...', ...
    'ButtonPushedFcn', @onBrowseFolder);
btnBrowse.Layout.Row = 1;
btnBrowse.Layout.Column = 1;

efFolderPath = uieditfield(mainGL, 'text', 'Editable', 'off');
efFolderPath.Layout.Row = 1;
efFolderPath.Layout.Column = [2 3];

% ════════════════════════════════════════════════════════════════════════
% ROW 2: File listbox (multi-select)
% ════════════════════════════════════════════════════════════════════════

lbFiles = uilistbox(mainGL, 'Multiselect', 'on');
lbFiles.Layout.Row = 2;
lbFiles.Layout.Column = [1 3];

% ════════════════════════════════════════════════════════════════════════
% ROW 3: Select All / Deselect All / file count
% ════════════════════════════════════════════════════════════════════════

btnSelectAll = uibutton(mainGL, 'push', 'Text', 'Select All', ...
    'ButtonPushedFcn', @onSelectAll);
btnSelectAll.Layout.Row = 3;
btnSelectAll.Layout.Column = 1;

btnDeselectAll = uibutton(mainGL, 'push', 'Text', 'Deselect All', ...
    'ButtonPushedFcn', @onDeselectAll);
btnDeselectAll.Layout.Row = 3;
btnDeselectAll.Layout.Column = 2;

lblFileCount = uilabel(mainGL, 'Text', 'Ready');
lblFileCount.Layout.Row = 3;
lblFileCount.Layout.Column = 3;
lblFileCount.HorizontalAlignment = 'right';

% ════════════════════════════════════════════════════════════════════════
% ROW 4: Format dropdown
% ════════════════════════════════════════════════════════════════════════

lblFormat = uilabel(mainGL, 'Text', 'Format:');
lblFormat.Layout.Row = 4;
lblFormat.Layout.Column = 1;

ddFormat = uidropdown(mainGL, ...
    'Items', {'Standard CSV', 'Origin ASCII', 'Send to Origin'}, ...
    'Value', 'Standard CSV', ...
    'ValueChangedFcn', @onFormatChanged);
ddFormat.Layout.Row = 4;
ddFormat.Layout.Column = [2 3];

% ════════════════════════════════════════════════════════════════════════
% ROW 5: Intensity dropdown
% ════════════════════════════════════════════════════════════════════════

lblIntensity = uilabel(mainGL, 'Text', 'Intensity:');
lblIntensity.Layout.Row = 5;
lblIntensity.Layout.Column = 1;

ddIntensity = uidropdown(mainGL, ...
    'Items', {'Both (cps + counts)', 'CPS only', 'Counts only'}, ...
    'Value', 'Both (cps + counts)');
ddIntensity.Layout.Row = 5;
ddIntensity.Layout.Column = [2 3];

% ════════════════════════════════════════════════════════════════════════
% ROW 6: Output location dropdown
% ════════════════════════════════════════════════════════════════════════

lblOutput = uilabel(mainGL, 'Text', 'Output:');
lblOutput.Layout.Row = 6;
lblOutput.Layout.Column = 1;

ddOutputLoc = uidropdown(mainGL, ...
    'Items', {'Same folder as source', 'Custom folder...'}, ...
    'Value', 'Same folder as source', ...
    'ValueChangedFcn', @onOutputLocChanged);
ddOutputLoc.Layout.Row = 6;
ddOutputLoc.Layout.Column = [2 3];

% ════════════════════════════════════════════════════════════════════════
% ROW 7: Output path editfield + browse (visible when custom selected)
% ════════════════════════════════════════════════════════════════════════

efOutputDir = uieditfield(mainGL, 'text', 'Editable', 'off');
efOutputDir.Layout.Row = 7;
efOutputDir.Layout.Column = [1 2];
efOutputDir.Visible = 'off';

btnBrowseOutput = uibutton(mainGL, 'push', 'Text', '...', ...
    'ButtonPushedFcn', @onBrowseOutputDir);
btnBrowseOutput.Layout.Row = 7;
btnBrowseOutput.Layout.Column = 3;
btnBrowseOutput.Visible = 'off';

% ════════════════════════════════════════════════════════════════════════
% ROW 8: Metadata checkbox
% ════════════════════════════════════════════════════════════════════════

cbMetadata = uicheckbox(mainGL, 'Text', 'Include metadata header', 'Value', true);
cbMetadata.Layout.Row = 8;
cbMetadata.Layout.Column = [1 3];

% ════════════════════════════════════════════════════════════════════════
% ROW 9: Convert button
% ════════════════════════════════════════════════════════════════════════

btnConvert = uibutton(mainGL, 'push', 'Text', 'Convert', ...
    'ButtonPushedFcn', @onConvert, ...
    'BackgroundColor', [0.2 0.6 0.2]);
btnConvert.Layout.Row = 9;
btnConvert.Layout.Column = [1 3];
btnConvert.FontSize = 13;
btnConvert.FontWeight = 'bold';
btnConvert.Enable = 'off'; % Disabled until files selected

% ════════════════════════════════════════════════════════════════════════
% ROW 10: Log textarea
% ════════════════════════════════════════════════════════════════════════

taLog = uitextarea(mainGL, 'Editable', 'off', 'FontName', 'Courier');
taLog.Layout.Row = 10;
taLog.Layout.Column = [1 3];
taLog.Visible = 'off'; % Hidden until conversion starts

% ════════════════════════════════════════════════════════════════════════
% ROW 11: Status label
% ════════════════════════════════════════════════════════════════════════

lblStatus = uilabel(mainGL, 'Text', 'Ready', 'FontSize', 11);
lblStatus.Layout.Row = 11;
lblStatus.Layout.Column = [1 3];
lblStatus.HorizontalAlignment = 'left';

% ════════════════════════════════════════════════════════════════════════
% App data storage
% ════════════════════════════════════════════════════════════════════════

appData = struct();
appData.folderPath = '';
appData.filePaths = {};
appData.fileTypes = {};
appData.converting = false;

% Store all handles for easy access in callbacks
handles = struct();
handles.fig = fig;
handles.btnBrowse = btnBrowse;
handles.efFolderPath = efFolderPath;
handles.lbFiles = lbFiles;
handles.btnSelectAll = btnSelectAll;
handles.btnDeselectAll = btnDeselectAll;
handles.lblFileCount = lblFileCount;
handles.ddFormat = ddFormat;
handles.ddIntensity = ddIntensity;
handles.ddOutputLoc = ddOutputLoc;
handles.efOutputDir = efOutputDir;
handles.btnBrowseOutput = btnBrowseOutput;
handles.cbMetadata = cbMetadata;
handles.btnConvert = btnConvert;
handles.taLog = taLog;
handles.lblStatus = lblStatus;

fig.UserData = struct('appData', appData, 'handles', handles);

% ════════════════════════════════════════════════════════════════════════
% CALLBACK: Browse folder
% ════════════════════════════════════════════════════════════════════════

    function onBrowseFolder(~, ~)
        folderPath = uigetdir(pwd, 'Select a folder containing XRD files');
        if isequal(folderPath, 0)
            return; % User cancelled
        end

        % Update UI
        state = fig.UserData;
        state.appData.folderPath = folderPath;
        handles.efFolderPath.Value = folderPath;

        % Scan for XRD files
        scanAndPopulateFileList(folderPath);

        fig.UserData = state;
    end

% ════════════════════════════════════════════════════════════════════════
% HELPER: Scan folder and populate file listbox
% ════════════════════════════════════════════════════════════════════════

    function scanAndPopulateFileList(folderPath)
        state = fig.UserData;

        % Get all files in folder (non-recursive for now)
        allFiles = dir(folderPath);

        filePaths = {};
        fileTypes = {};
        listItems = {};

        for i = 1:numel(allFiles)
            f = allFiles(i);
            if f.isdir
                continue;
            end

            [~, ~, ext] = fileparts(f.name);
            ext = lower(ext);

            fileType = '';
            isXRD = false;

            % Classify file
            if strcmp(ext, '.xrdml')
                fileType = 'xrdml';
                isXRD = true;
            elseif strcmp(ext, '.brml')
                fileType = 'bruker';
                isXRD = true;
            elseif strcmp(ext, '.raw')
                % Check magic bytes
                fullPath = fullfile(f.folder, f.name);
                try
                    fid = fopen(fullPath, 'r');
                    if fid >= 0
                        header = fread(fid, 7, '*char')';
                        fclose(fid);

                        if startsWith(header, 'FI')
                            fileType = 'rigaku';
                            isXRD = true;
                        elseif startsWith(header, 'RAW1.01')
                            fileType = 'bruker';
                            isXRD = true;
                        else
                            fileType = 'unknown';
                        end
                    end
                catch
                    fileType = 'unknown';
                end
            end

            if isXRD
                fullPath = fullfile(f.folder, f.name);
                filePaths{end+1} = fullPath;
                fileTypes{end+1} = fileType;

                % Determine badge
                switch fileType
                    case 'xrdml'
                        badge = '[XRDML]';
                    case 'rigaku'
                        badge = '[Rigaku]';
                    case 'bruker'
                        badge = '[Bruker]';
                    otherwise
                        badge = '[???]';
                end

                listItems{end+1} = sprintf('%s %s', badge, f.name);
            end
        end

        % Update state
        state.appData.filePaths = filePaths;
        state.appData.fileTypes = fileTypes;
        fig.UserData = state;

        % Update listbox
        if isempty(listItems)
            handles.lbFiles.Items = {};
            handles.lbFiles.Value = {};
            handles.lblFileCount.Text = 'No XRD files found';
            handles.btnConvert.Enable = 'off';
        else
            handles.lbFiles.Items = listItems;
            handles.lbFiles.Value = listItems; % Select all by default
            handles.lblFileCount.Text = sprintf('%d files found', numel(listItems));
            updateConvertButtonState();
        end

        % Hide log on new folder select
        handles.taLog.Visible = 'off';
        handles.lblStatus.Text = sprintf('Ready to convert (%d files)', numel(listItems));
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
            % Disable output folder controls
            handles.ddOutputLoc.Enable = 'off';
            handles.efOutputDir.Enable = 'off';
            handles.btnBrowseOutput.Enable = 'off';
            handles.cbMetadata.Enable = 'off';
        else
            % Enable output folder controls
            handles.ddOutputLoc.Enable = 'on';
            handles.efOutputDir.Enable = 'on';
            handles.btnBrowseOutput.Enable = 'on';
            handles.cbMetadata.Enable = 'on';

            % Update visibility based on current output location setting
            isCustom = strcmp(handles.ddOutputLoc.Value, 'Custom folder...');
            handles.efOutputDir.Visible = onoff(isCustom);
            handles.btnBrowseOutput.Visible = onoff(isCustom);
        end
    end

% ════════════════════════════════════════════════════════════════════════
% CALLBACK: Output location changed
% ════════════════════════════════════════════════════════════════════════

    function onOutputLocChanged(~, ~)
        isCustom = strcmp(handles.ddOutputLoc.Value, 'Custom folder...');
        handles.efOutputDir.Visible = onoff(isCustom);
        handles.btnBrowseOutput.Visible = onoff(isCustom);
    end

% ════════════════════════════════════════════════════════════════════════
% CALLBACK: Browse output directory
% ════════════════════════════════════════════════════════════════════════

    function onBrowseOutputDir(~, ~)
        folderPath = uigetdir(pwd, 'Select output folder');
        if isequal(folderPath, 0)
            return;
        end
        handles.efOutputDir.Value = folderPath;
    end

% ════════════════════════════════════════════════════════════════════════
% CALLBACK: Convert button
% ════════════════════════════════════════════════════════════════════════

    function onConvert(~, ~)
        state = fig.UserData;

        % Get selected files
        selectedItems = handles.lbFiles.Value;
        if isempty(selectedItems)
            return;
        end

        % Map selected items back to file paths
        allItems = handles.lbFiles.Items;
        selectedPaths = {};
        for i = 1:numel(allItems)
            for j = 1:numel(selectedItems)
                if strcmp(allItems{i}, selectedItems{j})
                    selectedPaths{end+1} = state.appData.filePaths{i};
                    break;
                end
            end
        end

        % Map dropdown values to option strings
        formatMap = struct('Standard CSV', 'standard', ...
                           'Origin ASCII', 'origin', ...
                           'Send to Origin', 'com');
        fmt = formatMap.(handles.ddFormat.Value);

        intensityMap = struct('Both (cps + counts)', 'both', ...
                              'CPS only', 'cps', ...
                              'Counts only', 'counts');
        intensity = intensityMap.(handles.ddIntensity.Value);

        % Determine output directory
        if strcmp(fmt, 'com')
            outputDir = '';
        else
            if strcmp(handles.ddOutputLoc.Value, 'Same folder as source')
                outputDir = '';
            else
                outputDir = handles.efOutputDir.Value;
            end
        end

        % Disable controls during conversion
        state.appData.converting = true;
        fig.UserData = state;

        handles.btnConvert.Enable = 'off';
        handles.btnConvert.Text = 'Converting...';
        handles.taLog.Visible = 'on';
        handles.taLog.Value = '';
        handles.lblStatus.Text = 'Converting...';
        drawnow;

        % Run batch conversion with progress callback
        try
            results = scripts.batchConvertXRD(selectedPaths, ...
                Format=fmt, ...
                OutputDir=outputDir, ...
                Intensity=intensity, ...
                IncludeMetadata=handles.cbMetadata.Value, ...
                Verbose=false, ...
                ProgressFcn=@progressCallback);

            % Count successes and failures
            nOk = sum(cellfun(@isempty, {results.error}));
            nErr = sum(~cellfun(@isempty, {results.error}));

            % Update status
            if nErr == 0
                handles.lblStatus.Text = sprintf('✓ Success: %d files converted', nOk);
            else
                handles.lblStatus.Text = sprintf('%d OK, %d failed', nOk, nErr);
            end

        catch ME
            handles.taLog.Value = [handles.taLog.Value, ...
                sprintf('[ERROR] Conversion failed: %s\n', ME.message)];
            handles.lblStatus.Text = 'Conversion failed';
        end

        % Re-enable controls
        state.appData.converting = false;
        fig.UserData = state;

        handles.btnConvert.Enable = 'on';
        handles.btnConvert.Text = 'Convert';
        drawnow;
    end

% ════════════════════════════════════════════════════════════════════════
% CALLBACK: Progress function (called from batchConvertXRD)
% ════════════════════════════════════════════════════════════════════════

    function progressCallback(k, n, filename)
        % This is called by batchConvertXRD; need to check if file succeeded or errored
        % For now, just show filename being processed
        logLine = sprintf('Processing %d/%d: %s', k, n, filename);
        handles.taLog.Value = [handles.taLog.Value, logLine, newline];
        drawnow;
    end

% ════════════════════════════════════════════════════════════════════════
% HELPER: Update convert button enabled state
% ════════════════════════════════════════════════════════════════════════

    function updateConvertButtonState()
        hasSelection = ~isempty(handles.lbFiles.Value);
        if hasSelection
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
            if strcmp(response, 'No')
                return;
            end
        end
        delete(fig);
    end

end

% ════════════════════════════════════════════════════════════════════════
% UTILITY: Convert boolean to 'on'/'off' string
% ════════════════════════════════════════════════════════════════════════

function str = onoff(bool)
    if bool
        str = 'on';
    else
        str = 'off';
    end
end
