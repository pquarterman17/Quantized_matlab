classdef FigureBuilderModel < handle
%FIGUREBUILDERMODEL  State container for the Advanced Figure Builder.
%
%   Owns the dialog's configuration:
%     - figureType (one of 16 supported types)
%     - globalOpts struct (template, font, dimensions, error style, line style)
%     - Per-type config structs (multiPanel, waterfall, overlayResidual, …)
%
%   Workshop pattern (MASTERPLAN W5 follow-up). The Figure Builder
%   dialog (+bosonPlotter/figureBuilder.m) is 3,411 lines spanning
%   16 figure types. This model + namespace establish the architecture
%   so a future scripted batch can do:
%
%       m = bosonPlotter.figureBuilder.FigureBuilderModel();
%       m.figureType = 'Multi-Panel';
%       m.multiPanelConfig.rows = 2;
%       m.multiPanelConfig.cols = 2;
%       m.multiPanelConfig.panels(1).datasets = [1 3];
%       m.multiPanelConfig.panels(1).yChannels = {'Counts'};
%       outFig = m.generate(datasets);
%
%   Without launching the dialog. As of the initial commit only
%   Multi-Panel is migrated — other 15 types still read from dialog
%   widgets directly.

    % ── Top-level selection ─────────────────────────────────────────
    properties
        figureType   char = 'Multi-Panel'
    end

    % ── Global formatting options (shared across all figure types) ──
    properties
        globalOpts struct = struct( ...
            'template',     'None', ...     % 'None' | 'APS (Phys Rev)' | 'Nature' | 'ACS' | 'Custom' | 'User: <name>'
            'figureWidth',  7.0, ...        % inches
            'figureHeight', 5.0, ...
            'fontSize',     10, ...
            'fontName',     'Helvetica', ...
            'errorStyle',   'None', ...     % 'None' | 'Error Bars' | 'Error Band'
            'lineStyle',    'Line', ...     % 'Line' | 'Scatter' | 'Line+Pts'
            'grayscale',    false)
    end

    % ── Per-type config structs ─────────────────────────────────────
    % Each is a sub-struct with the parameters specific to one figure
    % type. Today only multiPanelConfig is consumed by generate().
    properties
        multiPanelConfig    struct = bosonPlotter.figureBuilder.FigureBuilderModel.defaultMultiPanelConfig()
        quickGridConfig     struct = struct()
        waterfallConfig     struct = struct()
        overlayResConfig    struct = struct()
        normOverlayConfig   struct = struct()
        beforeAfterConfig   struct = struct()
        paramEvolConfig     struct = struct()
        brokenAxisConfig    struct = struct()
        confBandConfig      struct = struct()
        contourConfig       struct = struct()
        colorScatterConfig  struct = struct()
        marginalHistConfig  struct = struct()
        groupedPlotConfig   struct = struct()
        fftSpectralConfig   struct = struct()
        ternaryConfig       struct = struct()
        boxViolinConfig     struct = struct()
    end

    methods
        function obj = FigureBuilderModel()
        end

        function applyTemplate(obj, name)
        %APPLYTEMPLATE  Apply a built-in publication preset to globalOpts.
        %   name: 'APS (Phys Rev)' | 'Nature' | 'ACS' | 'None' | 'Custom'
        %         or 'User: <savedName>' to load via plotting.plotTemplate.
            obj.globalOpts.template = name;
            switch name
                case 'APS (Phys Rev)'
                    obj.globalOpts.figureWidth  = 3.375;
                    obj.globalOpts.figureHeight = 2.8;
                    obj.globalOpts.fontSize     = 8;
                    obj.globalOpts.fontName     = 'Times New Roman';
                case 'Nature'
                    obj.globalOpts.figureWidth  = 3.5;
                    obj.globalOpts.figureHeight = 2.8;
                    obj.globalOpts.fontSize     = 7;
                    obj.globalOpts.fontName     = 'Helvetica';
                case 'ACS'
                    obj.globalOpts.figureWidth  = 3.25;
                    obj.globalOpts.figureHeight = 2.5;
                    obj.globalOpts.fontSize     = 8;
                    obj.globalOpts.fontName     = 'Helvetica';
                case {'None', 'Custom'}
                    % Leave dimensions untouched — user picks
                otherwise
                    if startsWith(name, 'User: ')
                        nm = name(7:end);
                        try
                            ut = plotting.plotTemplate('load', Name=nm);
                            obj.globalOpts.figureWidth  = ut.figureProps.Width  / 96;
                            obj.globalOpts.figureHeight = ut.figureProps.Height / 96;
                            obj.globalOpts.fontSize     = ut.axesProps.FontSize;
                        catch
                            % silently ignore — caller's responsibility to handle
                        end
                    end
            end
        end

        function ensurePanelCount(obj, n)
        %ENSUREPANELCOUNT  Pad multiPanelConfig.panels to length n.
        %   Used when rows/cols change. New panels get default config.
            cur = numel(obj.multiPanelConfig.panels);
            if n > cur
                for k = (cur+1):n
                    obj.multiPanelConfig.panels(k) = ...
                        bosonPlotter.figureBuilder.FigureBuilderModel.defaultPanelSpec(); %#ok<AGROW>
                end
            elseif n < cur
                obj.multiPanelConfig.panels = obj.multiPanelConfig.panels(1:n);
            end
        end

        function outFig = generate(obj, datasets)
        %GENERATE  Dispatch to the right generator based on obj.figureType.
        %   Returns the produced figure handle.
            arguments
                obj
                datasets cell
            end
            switch obj.figureType
                case 'Multi-Panel'
                    outFig = bosonPlotter.figureBuilder.generateMultiPanel( ...
                        datasets, obj.multiPanelConfig, obj.globalOpts);
                otherwise
                    error('FigureBuilderModel:notMigrated', ...
                        ['Figure type "%s" has not been migrated to the model yet. ' ...
                         'Use the dialog (bosonPlotter.figureBuilder) until the ' ...
                         'migration completes.'], obj.figureType);
            end
        end
    end

    % ════════════════════════════════════════════════════════════════
    %  Static defaults + normalisers
    % ════════════════════════════════════════════════════════════════
    methods (Static, Access = public)
        function s = defaultMultiPanelConfig()
        %DEFAULTMULTIPANELCONFIG  Canonical 2x1 multi-panel config.
            s = struct( ...
                'rows',     2, ...
                'cols',     1, ...
                'shareX',   true, ...
                'shareY',   false, ...
                'panels',   bosonPlotter.figureBuilder.FigureBuilderModel.defaultPanelArray(2));
        end

        function p = defaultPanelSpec()
        %DEFAULTPANELSPEC  Canonical single-panel spec (one row in the panels array).
            p = struct( ...
                'datasets',     1, ...        % vector of dataset indices to plot
                'yChannels',    {{}}, ...      % cell array of Y label names
                'y2Channels',   {{}}, ...      % right-axis Y labels (optional)
                'rowSpan',      1, ...
                'colSpan',      1, ...
                'logY',         false, ...
                'title',        '');
        end

        function arr = defaultPanelArray(n)
            arr = repmat( ...
                bosonPlotter.figureBuilder.FigureBuilderModel.defaultPanelSpec(), ...
                1, n);
        end

        function cfg = normalizeMultiPanelConfig(cfg)
        %NORMALIZEMULTIPANELCONFIG  Upgrade legacy configs to canonical schema.
        %   Adds missing top-level fields (rows, cols, shareX, shareY,
        %   panels) and missing panel-spec fields (rowSpan, colSpan,
        %   logY, title, y2Channels) with defaults. Required so any
        %   external feeder of configs (a session loader, a future
        %   batch-script API) can hand us data without triggering
        %   "Subscripted assignment between dissimilar structures".
            if ~isstruct(cfg) || isempty(cfg)
                cfg = bosonPlotter.figureBuilder.FigureBuilderModel.defaultMultiPanelConfig();
                return;
            end
            topDefaults = struct('rows',2,'cols',1,'shareX',true,'shareY',false);
            topFields = fieldnames(topDefaults);
            for fi = 1:numel(topFields)
                if ~isfield(cfg, topFields{fi})
                    cfg.(topFields{fi}) = topDefaults.(topFields{fi});
                end
            end
            if ~isfield(cfg, 'panels') || isempty(cfg.panels)
                cfg.panels = bosonPlotter.figureBuilder.FigureBuilderModel.defaultPanelArray( ...
                    cfg.rows * cfg.cols);
                return;
            end
            % Normalize each panel spec
            panelDefaults = bosonPlotter.figureBuilder.FigureBuilderModel.defaultPanelSpec();
            panelFields   = fieldnames(panelDefaults);
            for fi = 1:numel(panelFields)
                f = panelFields{fi};
                if ~isfield(cfg.panels, f)
                    [cfg.panels.(f)] = deal(panelDefaults.(f));
                end
            end
        end
    end
end
