classdef PeakWorkshop < handle
%PEAKWORKSHOP  Facade for the Peak Workshop subsystem.
%
%   Skeleton landed in 1a. The real construction (build window,
%   wire callbacks via hook API) arrives in 1c. Today this class
%   only documents the target API so BosonPlotter.m can refer to
%   it during the migration.
%
%   Target usage from BosonPlotter:
%       hook = makePeakHook(fig, ax, appData, ...);   % 9-field struct
%       ws   = bosonPlotter.peak.PeakWorkshop(hook);
%       ws.bind(activeDataset);
%       ws.show();
%       peaks = ws.getPeaks();

    properties (SetAccess = protected)
        model     bosonPlotter.peak.PeakWorkshopModel
        hook      struct  = struct()
        peakFig                                    % uifigure handle
        widgets   struct  = struct()
    end

    methods
        function obj = PeakWorkshop(hook)
            arguments
                hook struct = struct()
            end
            obj.hook  = hook;
            obj.model = bosonPlotter.peak.PeakWorkshopModel();
            % Real construction in 1c.
        end

        function bind(obj, dsRef)  %#ok<INUSD>
            % Real implementation in 1b.
            obj.model.bind(dsRef);
        end

        function show(~)
            error('PeakWorkshop:notImplemented', 'show() arrives in 1c.');
        end

        function hide(~)
            error('PeakWorkshop:notImplemented', 'hide() arrives in 1c.');
        end

        function p = getPeaks(obj)
            p = obj.model.peaks;
        end

        function close(obj)
            if ~isempty(obj.peakFig) && isvalid(obj.peakFig)
                delete(obj.peakFig);
            end
        end
    end
end
