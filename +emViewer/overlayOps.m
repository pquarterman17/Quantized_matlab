function appData = overlayOps(action, appData, ctx, varargin)
%OVERLAYOPS  Overlay and measurement management operations for FermiViewer.
%
% Syntax:
%   appData = emViewer.overlayOps(action, appData, ctx, ...)
%
% Actions:
%   'deleteSelected'    — delete the currently selected measurement overlay
%   'assignElements'    — assign element symbols to EDS channels
%   'quantifyCL'        — Cliff-Lorimer EDS quantification
%   'quantifyZAF'       — ZAF-corrected EDS quantification
%
% ctx struct fields:
%   'deleteSelected':
%     .setStatus              — @setStatus function handle
%     .startEndpointDrag      — @startEndpointDrag function handle
%     .selectMeasurement      — @selectMeasurement function handle
%   'assignElements':
%     .setStatus              — @setStatus function handle
%   'quantifyCL':
%     .setStatus              — @setStatus function handle
%   'quantifyZAF':
%     .setStatus              — @setStatus function handle
%     .edtEDSThickness        — thickness edit field handle
%     .edtEDSTakeOff          — take-off angle edit field handle
%
% Examples:
%   ctx = struct('setStatus', @setStatus, ...
%                'startEndpointDrag', @startEndpointDrag, ...
%                'selectMeasurement', @selectMeasurement);
%   appData = emViewer.overlayOps('deleteSelected', appData, ctx);

% ════════════════════════════════════════════════════════════════════
switch lower(action)

    % ── Delete Selected Measurement ───────────────────────────────
    case 'deleteselected'
        idx = appData.selectedMeasIdx;
        if idx < 1 || idx > numel(appData.overlays.measurements)
            return;
        end

        meas = appData.overlays.measurements{idx};

        % Delete graphics objects for each measurement type
        if isfield(meas, 'type') && strcmp(meas.type, 'rectROI')
            if isfield(meas, 'hRect') && isvalid(meas.hRect)
                delete(meas.hRect);
            end
        elseif isfield(meas, 'type') && strcmp(meas.type, 'polyline')
            if isfield(meas, 'hLines')
                for h = meas.hLines(:)'
                    if isvalid(h), delete(h); end
                end
            end
            if isfield(meas, 'hMarkers')
                for h = meas.hMarkers(:)'
                    if isvalid(h), delete(h); end
                end
            end
            if isfield(meas, 'hText') && ~isempty(meas.hText) && isvalid(meas.hText)
                delete(meas.hText);
            end
        else
            if isfield(meas, 'hLine')  && isvalid(meas.hLine),                       delete(meas.hLine); end
            if isfield(meas, 'hP1')    && ~isempty(meas.hP1)   && isvalid(meas.hP1), delete(meas.hP1); end
            if isfield(meas, 'hP2')    && ~isempty(meas.hP2)   && isvalid(meas.hP2), delete(meas.hP2); end
            if isfield(meas, 'hText')  && ~isempty(meas.hText) && isvalid(meas.hText), delete(meas.hText); end
        end

        % Remove from list
        appData.overlays.measurements(idx) = [];
        appData.measWorkshop.sync(appData.overlays.measurements);

        % Re-bind drag + selection callbacks with updated indices
        for mi = 1:numel(appData.overlays.measurements)
            m = appData.overlays.measurements{mi};
            if isfield(m, 'hP1') && ~isempty(m.hP1) && isvalid(m.hP1)
                m.hP1.ButtonDownFcn = @(~,~) ctx.startEndpointDrag(mi, 1);
            end
            if isfield(m, 'hP2') && ~isempty(m.hP2) && isvalid(m.hP2)
                m.hP2.ButtonDownFcn = @(~,~) ctx.startEndpointDrag(mi, 2);
            end
            if isfield(m, 'hLine') && isvalid(m.hLine)
                m.hLine.ButtonDownFcn = @(~,~) ctx.selectMeasurement(mi);
            end
            if isfield(m, 'type') && strcmp(m.type, 'polyline') && isfield(m, 'hLines')
                for h = m.hLines(:)'
                    if isvalid(h)
                        h.ButtonDownFcn = @(~,~) ctx.selectMeasurement(mi);
                    end
                end
            end
        end

        appData.selectedMeasIdx = 0;
        if ~isempty(appData.selectedMeasIndices)
            keep = appData.selectedMeasIndices ~= idx;
            appData.selectedMeasIndices = appData.selectedMeasIndices(keep);
            shift = appData.selectedMeasIndices > idx;
            appData.selectedMeasIndices(shift) = ...
                appData.selectedMeasIndices(shift) - 1;
        end
        ctx.setStatus(sprintf('Deleted %s measurement', meas.type));

    % ── Assign EDS Elements ───────────────────────────────────────
    case 'assignelements'
        if ~appData.edsMode || isempty(appData.edsChannels), return; end

        nCh      = numel(appData.edsChannels);
        elements = cell(1, nCh);

        % Auto-detect element symbol from channel label (e.g. "Fe_Ka" -> "Fe")
        for k = 1:nCh
            lbl = appData.edsChannels{k}.label;
            tok = regexp(lbl, '^([A-Z][a-z]?)', 'tokens', 'once');
            if ~isempty(tok)
                elements{k} = tok{1};
            else
                elements{k} = sprintf('El%d', k);
            end
        end

        prompt   = cell(1, nCh);
        defaults = cell(1, nCh);
        for k = 1:nCh
            prompt{k}   = sprintf('Channel %d (%s):', k, appData.edsChannels{k}.label);
            defaults{k} = elements{k};
        end

        answer = inputdlg(prompt, 'Assign Elements', 1, defaults);
        if isempty(answer), return; end

        appData.edsElements = answer';
        ctx.setStatus(sprintf('Elements assigned: %s', strjoin(appData.edsElements, ', ')));

    % ── Cliff-Lorimer EDS Quantification ─────────────────────────
    case 'quantifycl'
        if ~appData.edsMode || isempty(appData.edsChannels), return; end
        if isempty(appData.edsElements)
            ctx.setStatus('Assign elements first'); return;
        end

        nCh  = numel(appData.edsChannels);
        maps = cell(1, nCh);
        for k = 1:nCh
            chIdx   = appData.edsChannels{k}.imageIdx;
            maps{k} = double(appData.images{chIdx}.metadata.parserSpecific.imageData.pixels);
        end

        try
            result = imaging.cliffLorimer(maps, appData.edsElements);
        catch ME
            ctx.setStatus(['Cliff-Lorimer error: ' ME.message]); return;
        end

        appData.edsAtomicPct  = result.atomicPctMaps;
        appData.edsWeightPct  = result.weightPctMaps;
        appData.edsQuantified = true;

        msg = 'Composition (at%): ';
        for k = 1:nCh
            msg = [msg sprintf('%s=%.1f%% ', appData.edsElements{k}, result.meanAtomicPct(k))]; %#ok<AGROW>
        end
        ctx.setStatus(msg);
        appData.edsWorkshop.sync(appData);

    % ── ZAF-Corrected EDS Quantification ─────────────────────────
    case 'quantifyzaf'
        if ~appData.edsMode || isempty(appData.edsChannels), return; end
        if isempty(appData.edsElements)
            ctx.setStatus('Assign elements first'); return;
        end

        nCh = numel(appData.edsChannels);
        maps = cell(1, nCh);
        for k = 1:nCh
            chIdx = appData.edsChannels{k}.imageIdx;
            maps{k} = double(appData.images{chIdx}.metadata.parserSpecific.imageData.pixels);
        end
        thickness = str2double(ctx.edtEDSThickness.Value);
        takeoff   = str2double(ctx.edtEDSTakeOff.Value);
        if isnan(thickness), thickness = 100; end
        if isnan(takeoff),   takeoff   = 20;  end

        try
            result = imaging.zafCorrection(maps, appData.edsElements, ...
                'Thickness', thickness, 'TakeOffAngle', takeoff);
            appData.edsAtomicPct  = result.atomicPctMaps;
            appData.edsWeightPct  = result.weightPctMaps;
            appData.edsQuantified = true;
            msg = 'ZAF (at%): ';
            for k = 1:nCh
                msg = [msg sprintf('%s=%.1f%% ', appData.edsElements{k}, result.meanAtomicPct(k))]; %#ok<AGROW>
            end
            ctx.setStatus(msg);
        catch ME
            ctx.setStatus(sprintf('ZAF failed: %s', ME.message));
        end

    otherwise
        error('emViewer:overlayOps:unknownAction', 'Unknown action: %s', action);
end
end
