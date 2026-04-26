classdef HysteresisWorkshopModel < handle
%HYSTERESISWORKSHOPMODEL  State container for the Hysteresis Workshop.
%
%   Owns the analysis parameters (H/M channel selection, pre-smoothing
%   window, linear-BG subtraction toggle) and the most recent result
%   from utilities.hysteresisAnalysis. The dialog view reads/writes this
%   model via accessors; the actual algorithm lives in +utilities/.
%
%   Usage:
%       m = bosonPlotter.hysteresis.HysteresisWorkshopModel();
%       m.bindFromDataset(ds);          % auto-detects H, M channels
%       [H, M] = m.extractHM(ds);
%       m.analyze(H, M);                % populates m.result
%       data = m.buildResultsTable();   % {param, value, unit} cell
%
%   Unlike the Peak workshop, Hysteresis does NOT persist results back
%   to the dataset — analysis output stays on the model and is consumed
%   by export/copy paths only. So there's no `applyToDataset` / no need
%   for normalize-on-bind: the workshop is a stateless analyser of
%   transient (H, M) inputs.

    % ── Analysis parameters ─────────────────────────────────────────
    properties
        hChannelIdx double  = 0       % 0 = time axis, else 1-based column
        mChannelIdx double  = 1
        preSmooth   double  = 0       % rolling-mean window (0 = none)
        subtractBg  logical = false   % subtract linear high-field slope
    end

    % ── Output ──────────────────────────────────────────────────────
    properties (SetAccess = protected)
        result      struct = struct()
        warnings    cell   = {}
    end

    methods
        function obj = HysteresisWorkshopModel()
        end

        function bindFromDataset(obj, ds)
        %BINDFROMDATASET  Auto-detect H/M channels from labels; clear result.
            if ~isempty(ds.corrData) && ~isempty(ds.corrData.time)
                d = ds.corrData;
            else
                d = ds.data;
            end
            [obj.hChannelIdx, obj.mChannelIdx] = ...
                bosonPlotter.hysteresis.HysteresisWorkshopModel.autoDetectChannels(d.labels);
            obj.result   = struct();
            obj.warnings = {};
        end

        function [H, M] = extractHM(obj, ds)
        %EXTRACTHM  Pull H and M vectors from a dataset using current channels.
        %   Applies linear-BG subtraction if obj.subtractBg is true.
            if ~isempty(ds.corrData) && ~isempty(ds.corrData.time)
                d = ds.corrData;
            else
                d = ds.data;
            end
            H = obj.fetchColumn(d, obj.hChannelIdx);
            M = obj.fetchColumn(d, obj.mChannelIdx);
            if obj.subtractBg
                [H, M] = bosonPlotter.hysteresis.subtractLinearBG(H, M);
            end
        end

        function analyze(obj, H, M)
        %ANALYZE  Run utilities.hysteresisAnalysis with current params.
            arguments
                obj
                H (:,1) double
                M (:,1) double
            end
            obj.result = utilities.hysteresisAnalysis(H, M, ...
                PreSmooth=obj.preSmooth);
            if isfield(obj.result, 'warnings')
                obj.warnings = obj.result.warnings;
            else
                obj.warnings = {};
            end
        end

        function clear(obj)
            obj.result   = struct();
            obj.warnings = {};
        end

        function tf = hasResult(obj)
        %HASRESULT  True if analyze() has been called and produced a result.
            tf = ~isempty(obj.result) && isstruct(obj.result) ...
                && isfield(obj.result, 'Hc');
        end

        function data = buildResultsTable(obj)
        %BUILDRESULTSTABLE  Cell array {param, value, unit} from obj.result.
            if ~obj.hasResult()
                data = {}; return;
            end
            r = obj.result;
            data = {...
                'Hc (ascending)',    sprintf('%.2f', r.Hc(1)),    'Oe'; ...
                'Hc (descending)',   sprintf('%.2f', r.Hc(2)),    'Oe'; ...
                'Hc (average)',      sprintf('%.2f', r.HcMean),   'Oe'; ...
                'Mr (ascending)',    sprintf('%.4e', r.Mr(1)),    'emu'; ...
                'Mr (descending)',   sprintf('%.4e', r.Mr(2)),    'emu'; ...
                'Mr (average)',      sprintf('%.4e', r.MrMean),   'emu'; ...
                'Ms (+)',            sprintf('%.4e', r.Ms(1)),    'emu'; ...
                'Ms (-)',            sprintf('%.4e', r.Ms(2)),    'emu'; ...
                'Ms (average)',      sprintf('%.4e', r.MsMean),   'emu'; ...
                'Squareness (Mr/Ms)',sprintf('%.4f', r.squareness),''; ...
                'SFD FWHM',          sprintf('%.2f', r.SFD.fwhm), 'Oe'; ...
                'Loop Area',         sprintf('%.4e', r.loopArea), 'emu·Oe'};
        end

        function txt = buildClipboardText(obj)
        %BUILDCLIPBOARDTEXT  Tab-delimited results for clipboard / Copy.
            lines = {'Hysteresis Loop Analysis'};
            data = obj.buildResultsTable();
            for ri = 1:size(data, 1)
                lines{end+1} = sprintf('%s\t%s\t%s', ...
                    data{ri,1}, data{ri,2}, data{ri,3}); %#ok<AGROW>
            end
            if ~isempty(obj.warnings)
                lines{end+1} = '';
                lines{end+1} = sprintf('Warnings: %s', strjoin(obj.warnings, '; '));
            end
            txt = strjoin(lines, newline);
        end

        function exportCSV(obj, filename)
        %EXPORTCSV  Write the results table to a CSV file.
            data = obj.buildResultsTable();
            if isempty(data), return; end
            fid = fopen(filename, 'w');
            cleanup = onCleanup(@() fclose(fid));
            fprintf(fid, 'Parameter,Value,Unit\n');
            for ri = 1:size(data, 1)
                fprintf(fid, '%s,%s,%s\n', data{ri,1}, data{ri,2}, data{ri,3});
            end
        end
    end

    methods (Access = protected)
        function v = fetchColumn(~, d, colIdx)
        %FETCHCOLUMN  Return the time vector (colIdx=0) or a values column.
            if colIdx == 0
                v = double(d.time(:));
            else
                v = d.values(:, colIdx);
            end
        end
    end

    methods (Static, Access = public)
        function [hIdx, mIdx] = autoDetectChannels(labels)
        %AUTODETECTCHANNELS  Heuristic match for field/moment in column names.
            lo = lower(labels);
            hIdx = find(contains(lo, 'field') | contains(lo, 'magnetic'), 1);
            mIdx = find(contains(lo, 'moment') | contains(lo, 'emu'), 1);
            if isempty(hIdx), hIdx = 0; end                  % 0 = time axis
            if isempty(mIdx), mIdx = min(1, numel(labels)); end
        end
    end
end
