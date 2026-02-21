function dataImportGUI()
%DATAIMPORTGUI  Browse, import and preview data files using the +parser toolkit.
%
%   dataImportGUI()
%
%   Opens an interactive figure with:
%     - File browser for .dat .csv .tsv .txt .xlsx .xls .xlsm .raw files
%     - Auto-detection of the correct parser (same logic as parser.importAuto)
%     - X / Y channel selectors -- Y supports multi-select for overlay plots
%     - Line, Scatter, and Line+Markers plot styles
%     - Log-scale toggles for both axes
%     - Metadata summary panel
%
%   Run from the project root:
%       cd G:\Onedrive\Coding\git\thin_film_toolkit_matlab
%       dataImportGUI
%
%   See also parser.importAuto, parser.importPPMS, parser.importCSV,
%            parser.importExcel, parser.importRigaku, parser.importQDVSM

    % ── Shared application state ─────────────────────────────────────────
    appData.data       = [];
    appData.filepath   = '';
    appData.parserName = '';
    appData.style      = 'Line';   % current plot style

    % ── Figure ───────────────────────────────────────────────────────────
    fig = uifigure('Name','Data Import & Preview', ...
                   'Position',[80 80 1080 700]);

    % Root grid: toolbar row (fixed) + content row (flexible)
    rootGL = uigridlayout(fig,[2 1], ...
        'RowHeight',   {44,'1x'}, ...
        'ColumnWidth', {'1x'}, ...
        'Padding',     [8 8 8 8], ...
        'RowSpacing',  6);

    % ── Toolbar (3 cols: Browse | path | Load) ────────────────────────────
    % NOTE: uilabel omitted — not available for programmatic uifigure use
    % before R2021b.  Parser name is shown in the Controls panel title instead.
    tbGL = uigridlayout(rootGL,[1 3], ...
        'ColumnWidth',  {90,'1x',115}, ...
        'Padding',      [0 0 0 0], ...
        'ColumnSpacing', 6);
    tbGL.Layout.Row = 1;

    btnBrowse = uibutton(tbGL,'Text','Browse...','ButtonPushedFcn',@onBrowse);
    btnBrowse.Layout.Column = 1;

    editPath = uieditfield(tbGL,'Value','', ...
        'Placeholder','Select a data file  (.dat  .csv  .xlsx  .raw)...', ...
        'Tooltip','Full path to the data file');
    editPath.Layout.Column = 2;

    btnLoad = uibutton(tbGL,'Text','Load & Preview', ...
        'ButtonPushedFcn',@onLoad, ...
        'BackgroundColor',[0.18 0.52 0.18], ...
        'FontColor',[1 1 1], ...
        'FontWeight','bold');
    btnLoad.Layout.Column = 3;

    % ── Content: controls panel (left) | preview axes (right) ────────────
    contentGL = uigridlayout(rootGL,[1 2], ...
        'ColumnWidth',  {215,'1x'}, ...
        'Padding',      [0 0 0 0], ...
        'ColumnSpacing', 8);
    contentGL.Layout.Row = 2;

    % Left controls panel
    % Title updates to show parser name after each load.
    % Row layout (9 rows):
    %   1 -  26px  X dropdown
    %   2 -   4px  spacer
    %   3 -  88px  Y listbox (multi-select)
    %   4 -   4px  spacer
    %   5 -  36px  Plot-style toggle buttons (Line | Scatter | Line+Pts)
    %   6 -  26px  Log-scale checkboxes
    %   7 -   6px  spacer
    %   8 -  30px  Replot button
    %   9 -   1x   Metadata text area
    ctrlPanel = uipanel(contentGL,'Title','Controls');
    ctrlPanel.Layout.Column = 1;

    ctrlGL = uigridlayout(ctrlPanel,[9 1], ...
        'RowHeight', {26,4,88,4,36,26,6,30,'1x'}, ...
        'Padding',   [6 6 6 6], ...
        'RowSpacing', 0);

    ddX = uidropdown(ctrlGL,'Items',{'(load file first)'}, ...
        'ValueChangedFcn',@onAxisChanged, ...
        'Tooltip','X axis channel');
    ddX.Layout.Row = 1;

    lbY = uilistbox(ctrlGL,'Items',{'(load file first)'},'Multiselect','on', ...
        'ValueChangedFcn',@onAxisChanged, ...
        'Tooltip','Y axis channel(s) — Ctrl+click to select multiple');
    lbY.Layout.Row = 3;

    % Plot-style buttons (row 5) — three uibutton objects in a nested grid.
    % The active style is stored in appData.style; the selected button is
    % highlighted green.  Uses only uibutton, which is universally available.
    styleGL = uigridlayout(ctrlGL,[1 3], ...
        'Padding',[0 0 0 0],'ColumnSpacing',2,'ColumnWidth',{'1x','1x','1x'});
    styleGL.Layout.Row = 5;

    btnStyleLine = uibutton(styleGL,'Text','Line', ...
        'ButtonPushedFcn',@(~,~) onStylePick('Line'), ...
        'BackgroundColor',[0.20 0.50 0.20],'FontColor',[1 1 1]);
    btnStyleLine.Layout.Column = 1;

    btnStyleScatter = uibutton(styleGL,'Text','Scatter', ...
        'ButtonPushedFcn',@(~,~) onStylePick('Scatter'));
    btnStyleScatter.Layout.Column = 2;

    btnStyleLineMarkers = uibutton(styleGL,'Text','Line+Pts', ...
        'ButtonPushedFcn',@(~,~) onStylePick('Line+Pts'));
    btnStyleLineMarkers.Layout.Column = 3;

    chkGL = uigridlayout(ctrlGL,[1 2], ...
        'Padding',[0 0 0 0],'ColumnWidth',{'1x','1x'},'ColumnSpacing',4);
    chkGL.Layout.Row = 6;
    cbLogX = uicheckbox(chkGL,'Text','Log X','ValueChangedFcn',@onAxisChanged);
    cbLogX.Layout.Column = 1;
    cbLogY = uicheckbox(chkGL,'Text','Log Y','ValueChangedFcn',@onAxisChanged);
    cbLogY.Layout.Column = 2;

    btnPlot = uibutton(ctrlGL,'Text','Replot','ButtonPushedFcn',@onPlot);
    btnPlot.Layout.Row = 8;

    txtMeta = uitextarea(ctrlGL,'Value','','Editable','off', ...
        'FontSize',8,'FontName','Courier New');
    txtMeta.Layout.Row = 9;

    % ── Right: preview axes ───────────────────────────────────────────────
    axPanel = uipanel(contentGL,'Title','Preview');
    axPanel.Layout.Column = 2;
    axGL = uigridlayout(axPanel,[1 1],'Padding',[2 2 2 2]);
    ax = uiaxes(axGL);
    ax.Box = 'on';
    grid(ax,'on');
    title(ax,'Load a file to preview data','Interpreter','none');
    xlabel(ax,'');
    ylabel(ax,'');

    % ════════════════════════════════════════════════════════════════════
    %  NESTED CALLBACKS  (share appData + all control handles via closure)
    % ════════════════════════════════════════════════════════════════════

    function onBrowse(~,~)
        [fname,fpath] = uigetfile( ...
            {'*.dat;*.csv;*.tsv;*.txt;*.xlsx;*.xls;*.xlsm;*.xlsb;*.raw', ...
             'Supported data files (*.dat, *.csv, *.xlsx, *.raw)'; ...
             '*.*','All files (*.*)'}, ...
            'Select a data file');
        if isequal(fname,0), return; end
        editPath.Value = fullfile(fpath,fname);
    end

    function onLoad(~,~)
        fp = strtrim(editPath.Value);
        if isempty(fp)
            uialert(fig,'Please select a file first.','No file selected');
            return;
        end
        if ~isfile(fp)
            uialert(fig,sprintf('File not found:\n%s',fp),'File not found');
            return;
        end

        try
            [appData.data, appData.parserName] = guiImport(fp);
            appData.filepath = fp;
        catch ME
            fprintf(2, '\n[dataImportGUI] Import error: %s\n', ME.message);
            for si = 1:numel(ME.stack)
                fprintf(2, '  at %s  (line %d)\n', ME.stack(si).name, ME.stack(si).line);
            end
            uialert(fig,ME.message,'Import error');
            return;
        end

        d = appData.data;

        % Suppress value-change callbacks while reconfiguring controls.
        % Setting Items/Value fires onAxisChanged mid-update, clearing the
        % axes before the final consistent onPlot call at the end.
        ddX.ValueChangedFcn = [];
        lbY.ValueChangedFcn = [];

        % Parser name shown in the panel title (avoids uilabel dependency)
        ctrlPanel.Title = sprintf('Controls  —  %s', appData.parserName);

        % X dropdown: default x-axis name first, then all Y channel names
        xName     = guiXName(d.metadata);
        allLabels = [{xName}, d.labels];
        ddX.Items = allLabels;
        ddX.Value = allLabels{1};

        % Y listbox: all Y channels, first selected by default
        lbY.Items = d.labels;
        if ~isempty(d.labels)
            lbY.Value = d.labels(1);
        end

        % Metadata summary
        txtMeta.Value = guiMetaLines(d, appData.parserName, fp);

        % Restore callbacks, then plot once with everything consistent
        ddX.ValueChangedFcn = @onAxisChanged;
        lbY.ValueChangedFcn = @onAxisChanged;
        onPlot([],[]);
    end

    function onAxisChanged(~,~)
        if ~isempty(appData.data)
            onPlot([],[]);
        end
    end

    function onStylePick(styleName)
        appData.style = styleName;
        % Highlight active button green, reset the others to default grey
        allBtns   = {btnStyleLine, btnStyleScatter, btnStyleLineMarkers};
        allStyles = {'Line', 'Scatter', 'Line+Pts'};
        for i = 1:3
            if strcmp(allStyles{i}, styleName)
                allBtns{i}.BackgroundColor = [0.20 0.50 0.20];
                allBtns{i}.FontColor       = [1 1 1];
            else
                allBtns{i}.BackgroundColor = [0.94 0.94 0.94];
                allBtns{i}.FontColor       = [0 0 0];
            end
        end
        if ~isempty(appData.data)
            onPlot([],[]);
        end
    end

    function onPlot(~,~)
        if isempty(appData.data)
            return;   % nothing loaded yet — silent no-op
        end
        try
            d = appData.data;

            % ── Resolve x vector ─────────────────────────────────────────
            xSel  = ddX.Value;
            xName = guiXName(d.metadata);
            xUnit = guiXUnit(d.metadata);

            if strcmp(xSel, xName)
                xVec   = d.time;
                xLabel = guiLabel(xName, xUnit);
            else
                idx = find(strcmp(d.labels, xSel), 1);
                if isempty(idx)
                    xVec   = d.time;
                    xLabel = guiLabel(xName, xUnit);
                else
                    xVec   = d.values(:,idx);
                    xLabel = guiLabel(d.labels{idx}, d.units{idx});
                end
            end

            % ── Resolve y channels ────────────────────────────────────────
            ySel = lbY.Value;
            if ischar(ySel) || isstring(ySel)
                ySel = cellstr(ySel);
            end

            % ── Draw ─────────────────────────────────────────────────────
            cla(ax);
            hold(ax,'on');
            ls     = guiLineSpec(appData.style);
            colors = lines(max(numel(ySel),1));

            for k = 1:numel(ySel)
                idx = find(strcmp(d.labels, ySel{k}), 1);
                if isempty(idx), continue; end

                yVec = d.values(:,idx);

                if isdatetime(xVec)
                    good = ~isnat(xVec) & ~isnan(yVec);
                    xp   = xVec(good);
                else
                    good = ~isnan(xVec) & ~isnan(yVec);
                    xp   = xVec(good);
                end
                yp = yVec(good);

                plot(ax, xp, yp, ls{:}, ...
                    'Color',       colors(k,:), ...
                    'DisplayName', guiLabel(d.labels{idx}, d.units{idx}));
            end
            hold(ax,'off');

            if numel(ySel) > 1
                legend(ax,'Location','best');
            else
                legend(ax,'off');
            end

            xlabel(ax, xLabel);
            if numel(ySel) == 1
                idx = find(strcmp(d.labels, ySel{1}), 1);
                if ~isempty(idx)
                    ylabel(ax, guiLabel(d.labels{idx}, d.units{idx}));
                end
            else
                ylabel(ax,'');
            end

            [~,fn,ex] = fileparts(appData.filepath);
            title(ax, [fn,ex], 'Interpreter','none');

            ax.XScale = guiTernary(cbLogX.Value,'log','linear');
            ax.YScale = guiTernary(cbLogY.Value,'log','linear');
            grid(ax,'on');

        catch ME
            % Print full error + stack to Command Window (stderr = red text)
            fprintf(2, '\n[dataImportGUI] Plot error: %s\n', ME.message);
            for si = 1:numel(ME.stack)
                fprintf(2, '  at %s  (line %d)\n', ME.stack(si).name, ME.stack(si).line);
            end
            uialert(fig, ME.message, 'Plot error');
        end
    end

end  % dataImportGUI


% ════════════════════════════════════════════════════════════════════════
%  Module-level helpers  (stateless — no access to GUI handles)
% ════════════════════════════════════════════════════════════════════════

function [data, parserName] = guiImport(fp)
%GUIIMPORT  Dispatch to the correct parser and return both data and parser name.
    [~,~,ext] = fileparts(fp);
    ext = lower(ext);
    switch ext
        case '.raw'
            data       = parser.importRigaku(fp);
            parserName = 'importRigaku';

        case {'.xlsx','.xls','.xlsm','.xlsb','.ods'}
            data       = parser.importExcel(fp);
            parserName = 'importExcel';

        case {'.csv','.tsv','.txt'}
            data       = parser.importCSV(fp);
            parserName = 'importCSV';

        case '.dat'
            try
                data       = parser.importQDVSM(fp,'Verbose',false);
                parserName = 'importQDVSM';
            catch ME
                if contains(ME.message,'[Data]','IgnoreCase',true)
                    data       = parser.importPPMS(fp);
                    parserName = 'importPPMS';
                else
                    rethrow(ME);
                end
            end

        otherwise
            error('dataImportGUI:unknownExt', ...
                'No parser for extension "%s".\nSupported: .raw  .xlsx  .csv  .tsv  .txt  .dat', ...
                ext);
    end
end


function name = guiXName(meta)
    if isfield(meta,'xColumnName') && ~isempty(meta.xColumnName)
        name = meta.xColumnName;
    elseif isfield(meta,'startAngle')
        name = '2-Theta';
    else
        name = 'X';
    end
end


function u = guiXUnit(meta)
    if isfield(meta,'xColumnUnit')
        u = meta.xColumnUnit;
    elseif isfield(meta,'startAngle')
        u = 'deg';
    else
        u = '';
    end
end


function s = guiLabel(name, unit)
    if isempty(unit)
        s = name;
    else
        s = [name, ' (', unit, ')'];
    end
end


function ls = guiLineSpec(style)
    switch style
        case 'Scatter'
            ls = {'LineStyle','none','Marker','o','MarkerSize',5};
        case 'Line+Pts'
            ls = {'LineStyle','-','Marker','o','MarkerSize',4};
        otherwise   % 'Line'
            ls = {'LineStyle','-'};
    end
end


function v = guiTernary(cond, a, b)
    if cond, v = a; else, v = b; end
end


function out = guiMetaLines(d, parserName, fp)
    [~,fn,ex] = fileparts(fp);
    out = {};
    out{end+1} = sprintf('File:   %s%s', fn, ex);
    out{end+1} = sprintf('Parser: %s',   parserName);
    out{end+1} = sprintf('Rows:   %d',   numel(d.time));
    out{end+1} = sprintf('Chan:   %d',   size(d.values,2));
    out{end+1} = '---';

    if isdatetime(d.time)
        out{end+1} = 'X: datetime';
    else
        t = d.time(~isnan(d.time));
        if ~isempty(t)
            out{end+1} = sprintf('X: [%.4g, %.4g]', min(t), max(t));
        end
    end

    out{end+1} = '';
    for k = 1:size(d.values,2)
        col = d.values(~isnan(d.values(:,k)), k);
        lbl = d.labels{k};
        if ~isempty(d.units{k})
            lbl = [lbl, ' (', d.units{k}, ')'];
        end
        if isempty(col)
            out{end+1} = sprintf('Y%d: %s', k, lbl);
            out{end+1} = '    (all NaN)';
        else
            out{end+1} = sprintf('Y%d: %s', k, lbl);
            out{end+1} = sprintf('    [%.4g, %.4g]', min(col), max(col));
        end
    end
end
