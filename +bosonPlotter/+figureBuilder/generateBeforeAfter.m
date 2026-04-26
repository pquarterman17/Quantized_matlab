function outFig = generateBeforeAfter(datasets, cfg, globalOpts)
%GENERATEBEFOREAFTER  Side-by-side raw vs corrected for one dataset.
%
%   cfg fields:
%     .datasetIdx   single dataset index
%     .yChannels    cell array of Y channel names to overlay
%     .logY         logical
%     .linkY        logical (linkaxes 'y' between the two panels)
    arguments
        datasets   cell
        cfg        struct
        globalOpts struct
    end
    if ~isfield(cfg,'datasetIdx') || isempty(cfg.datasetIdx), cfg.datasetIdx = 1; end
    if ~isfield(cfg,'yChannels')  || isempty(cfg.yChannels)
        cfg.yChannels = datasets{cfg.datasetIdx}.data.labels(1);
    end
    if ~isfield(cfg,'logY'),  cfg.logY  = false; end
    if ~isfield(cfg,'linkY'), cfg.linkY = true; end

    ds = datasets{cfg.datasetIdx};
    outFig = bosonPlotter.figureBuilder.createOutFig('Before / After', globalOpts);
    tlo = tiledlayout(outFig, 1, 2, 'TileSpacing','compact', 'Padding','compact');

    axL = nexttile(tlo); hold(axL,'on'); axL.Box = 'on'; title(axL,'Raw');
    axR = nexttile(tlo); hold(axR,'on'); axR.Box = 'on'; title(axR,'Corrected');
    for ax_ = [axL axR], ax_.FontSize = globalOpts.fontSize; ax_.FontName = globalOpts.fontName; end

    cmap = lines(max(numel(cfg.yChannels), 1));
    for k = 1:numel(cfg.yChannels)
        yi = find(strcmp(ds.data.labels, cfg.yChannels{k}), 1);
        if isempty(yi), continue; end
        col = cmap(mod(k-1,size(cmap,1))+1,:);
        plot(axL, double(ds.data.time), ds.data.values(:,yi), '-', ...
            'Color', col, 'DisplayName', cfg.yChannels{k});
        hasCorr = isfield(ds, 'corrData') && ~isempty(ds.corrData) && ...
                  isfield(ds.corrData, 'time') && ~isempty(ds.corrData.time);
        if hasCorr
            yi2 = find(strcmp(ds.corrData.labels, cfg.yChannels{k}), 1);
            if ~isempty(yi2)
                plot(axR, double(ds.corrData.time), ds.corrData.values(:,yi2), '-', ...
                    'Color', col, 'DisplayName', cfg.yChannels{k});
            end
        else
            % No corrected data — mirror raw
            plot(axR, double(ds.data.time), ds.data.values(:,yi), '-', ...
                'Color', col, 'DisplayName', cfg.yChannels{k});
        end
    end
    if cfg.logY, axL.YScale = 'log'; axR.YScale = 'log'; end
    if cfg.linkY, linkaxes([axL axR], 'y'); end
    if numel(cfg.yChannels) > 1
        legend(axL, 'Location','best','FontSize',max(globalOpts.fontSize-2,6));
    end
end
