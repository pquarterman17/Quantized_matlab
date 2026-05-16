function appData = sessionOps(action, appData, ctx, varargin)
%SESSIONOPS  Session save/load and recent-file operations for FermiViewer.
%
% Syntax:
%   appData = emViewer.sessionOps(action, appData, ctx, ...)
%
% Actions:
%   'save'            — prompt user for save path, then save session
%   'saveToPath'      — save session to ctx.outPath (no dialog)
%   'load'            — prompt user for load path, then load session
%   'loadFromPath'    — load session from ctx.inPath (no dialog)
%   'addRecent'       — add ctx.filePath to recent files list
%   'updateDropdown'  — refresh the recent-files dropdown from appData
%   'recentSelected'  — handle recent-file dropdown selection (evt in varargin{1})
%   'renameBatch'     — rename files on disk; idxs in varargin{1}
%
% ctx struct fields (required per action):
%   'save' / 'saveToPath':
%     .fig             — uifigure handle
%     .outPath         — (saveToPath only) full file path
%     .sldLow          — low-contrast slider handle
%     .sldHigh         — high-contrast slider handle
%     .ddColormap      — colormap dropdown handle
%     .setStatus       — @setStatus function handle
%     .lastDir         — initial folder for dialog
%   'load' / 'loadFromPath':
%     .fig             — uifigure handle
%     .inPath          — (loadFromPath only) full file path
%     .sldLow          — low-contrast slider handle
%     .sldHigh         — high-contrast slider handle
%     .sldGamma        — gamma slider handle
%     .efGamma         — gamma edit field handle
%     .ddColormap      — colormap dropdown handle
%     .setStatus       — @setStatus function handle
%     .lastDir         — initial folder for dialog
%     .rebuildImageList — @rebuildImageList callback
%     .displayImage    — @displayImage callback
%     .refreshDisplay  — @refreshDisplay callback
%     .recentFilePath  — path to recent-files MAT file
%   'addRecent':
%     .filePath        — path string to add
%     .recentFilePath  — MAT file path for persistence
%     .ddRecent        — dropdown handle
%   'updateDropdown':
%     .ddRecent        — dropdown handle
%   'recentSelected':
%     .loadImagesFromPaths — @loadImagesFromPaths callback
%     .fig             — uifigure handle
%     (varargin{1} = evt from dropdown ValueChangedFcn)
%   'renameBatch':
%     .fig             — uifigure handle
%     .efRenameBase    — rename base name edit field handle
%     .setStatus       — @setStatus function handle
%     .lbImages        — listbox handle (for refreshing)
%     (varargin{1} = integer array of image indices to rename)
%
% Examples:
%   ctx = buildSessionCtx();
%   appData = emViewer.sessionOps('save', appData, ctx);
%
%   appData = emViewer.sessionOps('addRecent', appData, ctx);

% ════════════════════════════════════════════════════════════════════
switch lower(action)

    % ── Session Save ──────────────────────────────────────────────
    case 'save'
        defName = 'emviewer_session.mat';
        startPath = appData.lastDir;
        if isempty(startPath) || ~isfolder(startPath), startPath = pwd; end
        [fn, fp] = uiputfile({'*.mat', 'Session File (*.mat)'}, ...
            'Save Session', fullfile(startPath, defName));
        if isequal(fn, 0), return; end
        ctx.outPath = fullfile(fp, fn);
        appData = emViewer.sessionOps('savetopath', appData, ctx);

    case 'savetopath'
        ctx.fig.Pointer = 'watch'; drawnow;
        try
            session.images     = appData.images;
            session.activeIdx  = appData.activeIdx;
            session.gamma      = appData.gamma;
            session.roiList    = appData.roiList;
            session.measureLog = appData.measurementLog;
            session.contrastLow  = ctx.sldLow.Value;
            session.contrastHigh = ctx.sldHigh.Value;
            session.colormap     = ctx.ddColormap.Value;
            session.prefs        = appData.prefs;
            session.edsChannels  = appData.edsChannels;
            save(ctx.outPath, 'session', '-v7.3');
            appData.sessionFile = ctx.outPath;
            ctx.setStatus(sprintf('Session saved: %s', ctx.outPath));
        catch ME
            uialert(ctx.fig, sprintf('Save failed:\n%s', ME.message), ...
                'Session Error', 'Icon', 'error');
        end
        ctx.fig.Pointer = 'arrow';

    % ── Session Load ──────────────────────────────────────────────
    case 'load'
        startPath = appData.lastDir;
        if isempty(startPath) || ~isfolder(startPath), startPath = pwd; end
        [fn, fp] = uigetfile({'*.mat', 'Session File (*.mat)'}, ...
            'Load Session', startPath);
        if isequal(fn, 0), return; end
        ctx.inPath = fullfile(fp, fn);
        appData = emViewer.sessionOps('loadfrompath', appData, ctx);

    case 'loadfrompath'
        ctx.fig.Pointer = 'watch'; drawnow;
        try
            tmp = load(ctx.inPath, 'session');
            if ~isfield(tmp, 'session')
                uialert(ctx.fig, 'Not a valid session file.', 'Error', 'Icon', 'error');
                ctx.fig.Pointer = 'arrow'; return;
            end
            s = tmp.session;
            appData.images        = s.images;
            appData.activeIdx     = s.activeIdx;
            % Reset contrast-state cache to match restored image list
            appData.imageContrastState = cell(1, numel(appData.images));
            appData.lastDisplayedIdx   = 0;
            if isfield(s, 'gamma')
                appData.gamma = s.gamma;
                ctx.sldGamma.Value = s.gamma;
                ctx.efGamma.Value = s.gamma;
            end
            if isfield(s, 'roiList'),    appData.roiList = s.roiList; end
            if isfield(s, 'measureLog'), appData.measurementLog = s.measureLog; end
            if isfield(s, 'edsChannels'), appData.edsChannels = s.edsChannels; end
            if isfield(s, 'colormap') && ismember(s.colormap, ctx.ddColormap.Items)
                ctx.ddColormap.Value = s.colormap;
            end
            if isfield(s, 'prefs')
                flds = fieldnames(s.prefs);
                for fi2 = 1:numel(flds)
                    appData.prefs.(flds{fi2}) = s.prefs.(flds{fi2});
                end
            end
            ctx.rebuildImageList();
            if appData.activeIdx >= 1 && appData.activeIdx <= numel(appData.images)
                ctx.displayImage();
                if isfield(s, 'contrastLow') && isfield(s, 'contrastHigh')
                    lo2 = max(ctx.sldLow.Limits(1), ...
                              min(ctx.sldLow.Limits(2), s.contrastLow));
                    hi2 = max(ctx.sldHigh.Limits(1), ...
                              min(ctx.sldHigh.Limits(2), s.contrastHigh));
                    if lo2 < hi2
                        ctx.sldLow.Value  = lo2;
                        ctx.sldHigh.Value = hi2;
                    end
                    ctx.refreshDisplay();
                end
            end
            appData.sessionFile = ctx.inPath;
            ctx.setStatus(sprintf('Session loaded: %d images from %s', ...
                numel(appData.images), ctx.inPath));
        catch ME
            uialert(ctx.fig, sprintf('Load failed:\n%s', ME.message), ...
                'Session Error', 'Icon', 'error');
        end
        ctx.fig.Pointer = 'arrow';

    % ── Recent Files ─────────────────────────────────────────────
    case 'addrecent'
        fp = char(ctx.filePath);
        % Deduplicate: remove existing entry, prepend, cap at 10
        appData.recentFiles(strcmp(appData.recentFiles, fp)) = [];
        appData.recentFiles = [{fp}, appData.recentFiles];
        if numel(appData.recentFiles) > 10
            appData.recentFiles = appData.recentFiles(1:10);
        end
        % Persist
        try
            recentFiles = appData.recentFiles; %#ok<NASGU>
            save(ctx.recentFilePath, 'recentFiles');
        catch
            % Ignore save errors silently
        end
        appData = emViewer.sessionOps('updatedropdown', appData, ctx);

    case 'updatedropdown'
        if isempty(appData.recentFiles)
            ctx.ddRecent.Items = {'(recent files)'};
            ctx.ddRecent.Value = '(recent files)';
        else
            shortNames = cell(size(appData.recentFiles));
            for ri = 1:numel(appData.recentFiles)
                [~, fn, fe] = fileparts(appData.recentFiles{ri});
                shortNames{ri} = [fn fe];
            end
            ctx.ddRecent.Items     = shortNames;
            ctx.ddRecent.ItemsData = appData.recentFiles;
            ctx.ddRecent.Value     = appData.recentFiles{1};
        end

    case 'recentselected'
        evt = varargin{1};
        fp = evt.Value;
        if ischar(fp) && strcmp(fp, '(recent files)'), return; end
        if ~isfile(fp)
            uialert(ctx.fig, sprintf('File not found:\n%s', fp), ...
                'File Missing', 'Icon', 'warning');
            return;
        end
        ctx.loadImagesFromPaths({fp});

    % ── Batch Rename ─────────────────────────────────────────────
    case 'renamebatch'
        idxs = varargin{1};
        if isempty(appData.images)
            ctx.setStatus('No images loaded.'); return;
        end

        baseName = strtrim(ctx.efRenameBase.Value);
        if isempty(baseName)
            ctx.setStatus('Enter a base name before renaming.');
            return;
        end

        msg = sprintf('Rename %d file(s) on disk to %s_001, _002, ...?\nThis cannot be undone.', ...
            numel(idxs), baseName);
        answer = uiconfirm(ctx.fig, msg, 'Confirm Batch Rename', ...
            'Options', {'Rename', 'Cancel'}, 'DefaultOption', 2, 'CancelOption', 2);
        if ~strcmp(answer, 'Rename'), return; end

        ctx.fig.Pointer = 'watch'; drawnow;
        nRenamed = 0;
        for ri = 1:numel(idxs)
            ki = idxs(ri);
            try
                srcPath = appData.images{ki}.metadata.source;
                [srcDir, ~, srcExt] = fileparts(srcPath);
                newName = sprintf('%s_%03d%s', baseName, ri, srcExt);
                newPath = fullfile(srcDir, newName);
                if ~strcmp(srcPath, newPath)
                    if isfile(newPath)
                        warning('FermiViewer:rename', ...
                            'Skipped %s: target %s already exists.', srcPath, newName);
                        continue;
                    end
                    movefile(srcPath, newPath);
                    appData.images{ki}.metadata.source = newPath;
                    nRenamed = nRenamed + 1;
                end
            catch ME
                warning('FermiViewer:rename', 'Failed to rename %s: %s', ...
                    srcPath, ME.message);
            end
        end
        refreshListBox(appData, ctx.lbImages);
        ctx.fig.Pointer = 'arrow';
        ctx.setStatus(sprintf('Renamed %d / %d files with base "%s".', ...
            nRenamed, numel(idxs), baseName));

    otherwise
        error('emViewer:sessionOps:unknownAction', ...
            'Unknown action: %s', action);
end

% ════════════════════════════════════════════════════════════════════
%  LOCAL HELPER
% ════════════════════════════════════════════════════════════════════
function refreshListBox(appData, lbImages)
%REFRESHLISTBOX  Rebuild listbox items from current appData.images.
    if isempty(appData.images)
        lbImages.Items = {'(no images loaded)'};
        lbImages.ItemsData = {0};
        return;
    end
    names = cell(1, numel(appData.images));
    data  = cell(1, numel(appData.images));
    for ri = 1:numel(appData.images)
        [~, nm, ex] = fileparts(appData.images{ri}.metadata.source);
        names{ri} = [nm ex];
        data{ri}  = ri;
    end
    lbImages.Items = names;
    lbImages.ItemsData = data;
end

end
