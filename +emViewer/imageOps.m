function appData = imageOps(action, appData, ctx)
%IMAGEOPS  Image management callbacks for FermiViewer -- extracted from main closure.
%
% Syntax:
%   appData = emViewer.imageOps(action, appData, ctx)
%
% Actions:
%   'open'   -- onOpenFiles: open file dialog and load selected images
%   'remove' -- onRemoveImage: remove selected image(s) with confirmation
%
% ctx struct fields:
%   .fig           -- uifigure handle
%   .lbImages      -- image listbox handle
%   .btnCompare    -- Compare toggle button handle
%   .btnEDSToolbar -- EDS toolbar button handle
%   .cb.loadImagesFromPaths -- @loadImagesFromPaths
%   .cb.hideLoading         -- @hideLoading
%   .cb.setStatus           -- @setStatus
%   .cb.rebuildImageList    -- @rebuildImageList
%   .cb.displayImage        -- @displayImage
%   .cb.clearDisplay        -- @clearDisplay
%   .cb.exitCompareMode     -- @exitCompareMode
%   .cb.onOff               -- @onOff
%
% Inputs:
%   action   -- char, 'open' or 'remove'
%   appData  -- FermiViewer appData struct
%   ctx      -- context struct (see above)
%
% Outputs:
%   appData  -- updated appData struct
%
% Examples:
%   appData = emViewer.imageOps('open', appData, buildImageCtx());
%   appData = emViewer.imageOps('remove', appData, buildImageCtx());

switch action

    % ════════════════════════════════════════════════════════════════════
    %  open -- onOpenFiles: browse for image files via uigetfile
    % ════════════════════════════════════════════════════════════════════
    case 'open'
        fig = ctx.fig;

        filterSpec = { ...
            '*.tif;*.tiff;*.jpg;*.jpeg;*.png;*.bmp;*.raw;*.dm3;*.dm4;*.bcf;*.ser;*.mrc;*.mrcs;*.spm;*.000;*.001;*.002;*.003', 'All Supported Images'; ...
            '*.tif;*.tiff',                   'TIFF Files (*.tif, *.tiff)'; ...
            '*.jpg;*.jpeg;*.png;*.bmp',       'Common Images (*.jpg, *.png, *.bmp)'; ...
            '*.dm3;*.dm4',                    'Gatan Files (*.dm3, *.dm4)'; ...
            '*.bcf',                          'Bruker EDS Files (*.bcf)'; ...
            '*.ser',                          'FEI SER Files (*.ser)'; ...
            '*.mrc;*.mrcs',                   'MRC Files (*.mrc, *.mrcs)'; ...
            '*.spm;*.000;*.001;*.002;*.003',  'AFM Files (*.spm, *.000)'; ...
            '*.raw',                          'RAW Binary Files (*.raw)'; ...
            '*.*',                            'All Files (*.*)'};

        startDir = appData.lastDir;
        if isempty(startDir) || ~isfolder(startDir)
            startDir = pwd;
        end

        try
            [files, folder] = uigetfile(filterSpec, 'Select Image File(s)', ...
                startDir, 'MultiSelect', 'on');
        catch
            % uigetfile can fail on unreachable network paths or user interrupt
            fig.Pointer = 'arrow';
            ctx.cb.setStatus('File browser cancelled or failed.');
            return;
        end

        if isequal(files, 0)
            return;   % user cancelled
        end

        appData.lastDir = folder;

        % Normalize to cell array
        if ischar(files)
            files = {files};
        end

        % Build full paths
        fpaths = cellfun(@(f) fullfile(folder, f), files, 'UniformOutput', false);

        try
            ctx.cb.loadImagesFromPaths(fpaths);
        catch ME
            ctx.cb.hideLoading();
            fprintf(2, '\n[FermiViewer] Error loading files: %s\n', ME.message);
            for si = 1:numel(ME.stack)
                fprintf(2, '  at %s (line %d)\n', ME.stack(si).name, ME.stack(si).line);
            end
            uialert(fig, sprintf('Error loading files:\n%s', ME.message), ...
                'Load Error', 'Icon', 'error');
        end

    % ════════════════════════════════════════════════════════════════════
    %  remove -- onRemoveImage: remove selected image(s) from the list
    % ════════════════════════════════════════════════════════════════════
    case 'remove'
        fig           = ctx.fig;
        lbImages      = ctx.lbImages;
        btnCompare    = ctx.btnCompare;
        btnEDSToolbar = ctx.btnEDSToolbar;

        if isempty(appData.images)
            return;
        end

        % Get selected indices from listbox
        selVals = lbImages.Value;
        if iscell(selVals)
            selIdx = [selVals{:}];
        else
            selIdx = selVals;
        end

        % Filter out invalid indices (e.g., the placeholder 0)
        selIdx = selIdx(selIdx > 0 & selIdx <= numel(appData.images));
        if isempty(selIdx)
            return;
        end

        % Confirm multi-image removal -- matches BosonPlotter's dataset-
        % removal prompt so accidental Ctrl+A -> Remove doesn't silently
        % destroy work.
        if numel(selIdx) > 1
            answer = uiconfirm(fig, ...
                sprintf('Remove %d selected images?', numel(selIdx)), ...
                'Confirm Remove', 'Options', {'Remove', 'Cancel'}, ...
                'DefaultOption', 'Remove', 'CancelOption', 'Cancel');
            if strcmp(answer, 'Cancel'), return; end
        end

        % Remove selected images (keep contrast-state cache in lockstep)
        appData.images(selIdx) = [];
        if numel(appData.imageContrastState) >= max(selIdx)
            appData.imageContrastState(selIdx) = [];
        end
        if appData.lastDisplayedIdx > 0 && any(selIdx == appData.lastDisplayedIdx)
            appData.lastDisplayedIdx = 0;   % referenced image gone
        end

        % Update active index
        if isempty(appData.images)
            appData.activeIdx = 0;
        elseif appData.activeIdx > numel(appData.images)
            appData.activeIdx = numel(appData.images);
        elseif any(selIdx == appData.activeIdx)
            appData.activeIdx = min(appData.activeIdx, numel(appData.images));
            if appData.activeIdx == 0 && ~isempty(appData.images)
                appData.activeIdx = 1;
            end
        end

        % Exit compare mode if fewer than 2 images remain
        if numel(appData.images) < 2 && appData.compareMode
            btnCompare.Value = false;
            ctx.cb.exitCompareMode();
        end
        btnCompare.Enable    = ctx.cb.onOff(numel(appData.images) >= 2);
        btnEDSToolbar.Enable = ctx.cb.onOff(numel(appData.images) >= 1);

        ctx.cb.rebuildImageList();

        if appData.activeIdx > 0
            ctx.cb.displayImage();
        else
            ctx.cb.clearDisplay();
        end

    otherwise
        error('emViewer:imageOps:unknownAction', ...
            'Unknown action ''%s''. Valid: open, remove.', action);
end
end
