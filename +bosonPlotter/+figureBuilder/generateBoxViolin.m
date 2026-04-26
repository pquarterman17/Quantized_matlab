function outFig = generateBoxViolin(datasets, cfg, globalOpts)
%GENERATEBOXVIOLIN  Box / violin / swarm plot with three grouping modes.
%   Routes through plotting.boxViolinSwarm for rendering.
%
%   cfg fields:
%     .groupMode    'datasets'   (default)
%                       one box per dataset for a single yChannel
%                       — uses cfg.datasets, cfg.yChannel
%                   'channels'
%                       single dataset, one box per Y column
%                       — uses cfg.datasetIdx, cfg.yChannels
%                   'value-bins'
%                       single dataset, one Y column split into bins by
%                       a grouping column's unique values
%                       — uses cfg.datasetIdx, cfg.yChannel, cfg.groupChannel
%
%   Common cfg fields:
%     .style         'box' (default) | 'violin' | 'swarm' | 'box+swarm'
%     .orientation   'vertical' (default) | 'horizontal'
%     .showMean      logical (default true)
%     .showOutliers  logical (default true)
%     .width         scalar 0.1–1.5 (default 0.6)
    arguments
        datasets   cell
        cfg        struct
        globalOpts struct
    end
    if ~isfield(cfg,'groupMode'),    cfg.groupMode    = 'datasets';  end
    if ~isfield(cfg,'style'),        cfg.style        = 'box';        end
    if ~isfield(cfg,'orientation'),  cfg.orientation  = 'vertical';   end
    if ~isfield(cfg,'showMean'),     cfg.showMean     = true;         end
    if ~isfield(cfg,'showOutliers'), cfg.showOutliers = true;         end
    if ~isfield(cfg,'width'),        cfg.width        = 0.6;          end

    [dataCell, labels, valLbl] = collectGroups(datasets, cfg);
    if isempty(dataCell) || all(cellfun(@isempty, dataCell))
        outFig = bosonPlotter.figureBuilder.createOutFig('Box / Violin', globalOpts);
        return;
    end

    outFig = bosonPlotter.figureBuilder.createOutFig('Box / Violin', globalOpts);
    tAx = axes(outFig);
    plotting.boxViolinSwarm(tAx, dataCell, ...
        Style        = string(cfg.style), ...
        Labels       = labels, ...
        Orientation  = string(cfg.orientation), ...
        ShowMean     = cfg.showMean, ...
        ShowOutliers = cfg.showOutliers, ...
        Width        = cfg.width);
    tAx.FontSize = globalOpts.fontSize; tAx.FontName = globalOpts.fontName;
    tAx.Box = 'on';
    if strcmp(cfg.orientation, 'vertical')
        ylabel(tAx, valLbl, 'Interpreter', 'none');
    else
        xlabel(tAx, valLbl, 'Interpreter', 'none');
    end
end

function [dataCell, labels, valLbl] = collectGroups(datasets, cfg)
%COLLECTGROUPS  Gather data into cell-per-box and a value-axis label.
    dataCell = {};  labels = {};  valLbl = 'Value';
    switch cfg.groupMode
        case 'channels'
            % Single dataset; one box per Y channel
            if ~isfield(cfg,'datasetIdx'), cfg.datasetIdx = 1; end
            if ~isfield(cfg,'yChannels') || isempty(cfg.yChannels), return; end
            ds = datasets{cfg.datasetIdx};
            for k = 1:numel(cfg.yChannels)
                yi = find(strcmp(ds.data.labels, cfg.yChannels{k}), 1);
                if isempty(yi), continue; end
                yV = ds.data.values(:, yi);  yV = yV(~isnan(yV));
                dataCell{end+1} = yV;                                %#ok<AGROW>
                labels{end+1}   = cfg.yChannels{k};                  %#ok<AGROW>
            end
            valLbl = 'Value';

        case 'value-bins'
            % Single dataset; one Y column binned by another column's values
            if ~isfield(cfg,'datasetIdx'),    cfg.datasetIdx = 1;    end
            if ~isfield(cfg,'yChannel'),      cfg.yChannel = '';     end
            if ~isfield(cfg,'groupChannel'),  cfg.groupChannel = ''; end
            ds = datasets{cfg.datasetIdx};
            yi = find(strcmp(ds.data.labels, cfg.yChannel), 1);
            gi = find(strcmp(ds.data.labels, cfg.groupChannel), 1);
            if isempty(yi) || isempty(gi), return; end
            yV = ds.data.values(:, yi);  gV = ds.data.values(:, gi);
            ok = ~isnan(yV) & ~isnan(gV);
            yV = yV(ok);  gV = gV(ok);
            [uG, ~, gix] = unique(round(gV, 6));
            for k = 1:numel(uG)
                dataCell{end+1} = yV(gix == k);                       %#ok<AGROW>
                labels{end+1}   = sprintf('%s=%.4g', cfg.groupChannel, uG(k)); %#ok<AGROW>
            end
            valLbl = cfg.yChannel;

        otherwise   % 'datasets' — one box per dataset for a single Y channel
            if ~isfield(cfg,'datasets') || isempty(cfg.datasets)
                cfg.datasets = 1:numel(datasets);
            end
            if ~isfield(cfg,'yChannel') || isempty(cfg.yChannel)
                cfg.yChannel = datasets{1}.data.labels{1};
            end
            for k = 1:numel(cfg.datasets)
                di = cfg.datasets(k);
                if di < 1 || di > numel(datasets), continue; end
                [~, yv] = bosonPlotter.figureBuilder.extractXY(datasets{di}, cfg.yChannel);
                dataCell{end+1} = yv;                                 %#ok<AGROW>
                labels{end+1}   = sprintf('#%d', di);                 %#ok<AGROW>
            end
            valLbl = cfg.yChannel;
    end
end
