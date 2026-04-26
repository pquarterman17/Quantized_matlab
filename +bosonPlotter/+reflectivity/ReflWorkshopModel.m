classdef ReflWorkshopModel < handle
%REFLWORKSHOPMODEL  State container for the Reflectivity Workshop.
%
%   Owns the reflectivity dialog's algorithmic state: mode (Layers vs
%   Spline), layer stack, knot list, fit-fixed mask, background +
%   scale, and the most recent fit / simulate result. Algorithm itself
%   stays in the +fitting/ package (fitting.parrattRefl,
%   fitting.reflFit, fitting.reflBuildSplineLayers).
%
%   Workshop pattern (MASTERPLAN W5 #62). Most cross-cutting feature
%   of the four — has its own layer/knot tables, optional resolution
%   convolution, and produces R(Q) curves overlaid on the main axes.
%   The model is GUI-free so it can be exercised against synthetic
%   reflectivity data and used in scripted reflectivity batches.
%
%   Usage:
%       m = bosonPlotter.reflectivity.ReflWorkshopModel();
%       m.bindFromDataset(ds);          % seeds with default 3-layer stack
%       m.addLayer('SiO2', 200, 3.47);
%       Rsim = m.simulate(Q);           % uses fitting.parrattRefl
%       res  = m.fit(Q, Robs);          % populates m.result

    % ── Mode + scope ────────────────────────────────────────────────
    properties
        mode            char    = 'Layers'      % 'Layers' | 'Spline'
        bg              double  = 0             % flat background in R
        scale           double  = 1             % multiplicative scale on R
        resolutionArg               = []        % numeric Δθ or struct
    end

    % ── Layer / knot tables ─────────────────────────────────────────
    % Layers: struct array with fields {name, thick, sld, abs, rough, fixed}
    % Knots:  struct array with fields {z, sld, fixed}
    properties
        layers          = bosonPlotter.reflectivity.ReflWorkshopModel.emptyLayers()
        knots           = bosonPlotter.reflectivity.ReflWorkshopModel.emptyKnots()
    end

    % ── Output ──────────────────────────────────────────────────────
    properties (SetAccess = protected)
        result          struct  = struct()
    end

    methods
        function obj = ReflWorkshopModel()
            obj.layers = obj.defaultLayerStack();
            obj.knots  = obj.defaultKnots();
        end

        function bindFromDataset(obj, ds)  %#ok<INUSD>
        %BINDFROMDATASET  Reset to default 3-layer stack + 5-knot spline.
        %   The dataset is supplied for symmetry with other workshops;
        %   reflectivity does not auto-detect channels — caller passes
        %   Q + R(Q) explicitly to fit() / simulate().
            obj.layers = obj.defaultLayerStack();
            obj.knots  = obj.defaultKnots();
            obj.result = struct();
        end

        % ── Mode toggling ───────────────────────────────────────────
        function tf = inSplineMode(obj)
            tf = strcmp(obj.mode, 'Spline');
        end

        % ── Layer mutators ──────────────────────────────────────────
        function addLayer(obj, name, thick, sld, abs_, rough)
            arguments
                obj
                name  char
                thick double = 100
                sld   double = 3.0
                abs_  double = 0
                rough double = 5
            end
            new = struct('name', name, 'thick', thick, 'sld', sld, ...
                         'abs', abs_, 'rough', rough, 'fixed', false);
            % Insert just before the substrate (last row).
            if numel(obj.layers) <= 1
                obj.layers(end+1) = new;
            else
                obj.layers = [obj.layers(1:end-1), new, obj.layers(end)];
            end
        end

        function removeLayer(obj, idx)
            % Refuse to delete the ambient (1) or substrate (end) layer.
            if idx <= 1 || idx >= numel(obj.layers), return; end
            obj.layers(idx) = [];
        end

        % ── Knot mutators ───────────────────────────────────────────
        function addKnot(obj, z, sld)
            arguments
                obj
                z   double
                sld double = 3.47
            end
            new = struct('z', z, 'sld', sld, 'fixed', false);
            if numel(obj.knots) <= 1
                obj.knots(end+1) = new;
            else
                obj.knots = [obj.knots(1:end-1), new, obj.knots(end)];
            end
            obj.sortKnots();
        end

        function removeKnot(obj, idx)
            % Refuse to delete the endpoint knots.
            if idx <= 1 || idx >= numel(obj.knots), return; end
            obj.knots(idx) = [];
        end

        % ── Algorithms (delegate to +fitting/) ──────────────────────
        function Rsim = simulate(obj, Q)
        %SIMULATE  Evaluate R(Q) for the current model state.
        %   Layers mode goes directly through fitting.parrattRefl. Spline
        %   mode is not yet supported through the model — the dialog
        %   still owns that path; will migrate in a follow-up commit.
            arguments
                obj
                Q (:,1) double
            end
            if obj.inSplineMode()
                error('ReflWorkshopModel:splineNotImplemented', ...
                    'Spline simulate is not yet supported through the model. Use Layers mode.');
            end
            layerMat = obj.layerMatrix();
            Rsim = fitting.parrattRefl(Q, layerMat) .* obj.scale + obj.bg;
        end

        function res = fit(obj, Q, Robs)
        %FIT  Fit the layer-stack parameters to observed R(Q) via
        %   fitting.curveFit. Operates in log-R space for stability
        %   (matches the dialog's doFit() approach). Result struct
        %   includes: params (flattened layer matrix), errors, R2, RMSE.
            arguments
                obj
                Q    (:,1) double
                Robs (:,1) double
            end
            if obj.inSplineMode()
                error('ReflWorkshopModel:splineFitNotImplemented', ...
                    'Spline fitting is not yet supported through the model. Use Layers mode.');
            end
            L0   = obj.layerMatrix();
            p0   = L0(:);                     % flatten [thick, sld, abs, rough] per layer
            fixedPerLayer = obj.layerFixedMask();
            fixedFlat     = repmat(fixedPerLayer(:)', 4, 1);
            fixedFlat     = fixedFlat(:)';

            scale_ = obj.scale;  bg_ = obj.bg;
            logY    = log10(max(Robs, eps));
            logModel = @(Q_, p) log10(max( ...
                fitting.parrattRefl(Q_, reshape(p, [], 4)) .* scale_ + bg_, eps));

            res = fitting.curveFit(Q, logY, logModel, p0, Fixed=fixedFlat);

            % Decode fitted layer matrix
            Lfit = reshape(res.params, [], 4);
            for k = 1:numel(obj.layers)
                obj.layers(k).thick = Lfit(k, 1);
                obj.layers(k).sld   = Lfit(k, 2);
                obj.layers(k).abs   = Lfit(k, 3);
                obj.layers(k).rough = Lfit(k, 4);
            end
            res.layerMatrix = Lfit;
            res.mode = obj.mode;
            obj.result = res;
        end

        function tf = hasResult(obj)
            tf = ~isempty(obj.result) && isstruct(obj.result) ...
                && isfield(obj.result, 'params');
        end

        % ── Conversions: struct array ↔ numeric matrix ──────────────
        function L = layerMatrix(obj)
        %LAYERMATRIX  Return [nLayers × 4] matrix expected by fitting.parrattRefl:
        %   columns = [thickness(Å), SLD_real(Å⁻²), SLD_imag(Å⁻²), roughness(Å)].
        %   Stored layer .sld and .abs are in user units (×10⁻⁶ Å⁻²) — same
        %   convention as the dialog UI — so they are scaled here.
            n = numel(obj.layers);
            L = zeros(n, 4);
            for k = 1:n
                L(k, :) = [obj.layers(k).thick, ...
                           obj.layers(k).sld * 1e-6, ...
                           obj.layers(k).abs * 1e-6, ...
                           obj.layers(k).rough];
            end
        end

        function fixed = layerFixedMask(obj)
            fixed = [obj.layers.fixed];
        end

        function z = knotZ(obj)
            z = [obj.knots.z];
        end

        function v = knotSLD(obj)
            v = [obj.knots.sld];
        end
    end

    methods (Access = protected)
        function sortKnots(obj)
            [~, ord] = sort([obj.knots.z]);
            obj.knots = obj.knots(ord);
        end

        function L = defaultLayerStack(obj) %#ok<MANU>
            L = [ ...
                struct('name','Air / Vacuum','thick',0,  'sld',0,    'abs',0,'rough',0,'fixed',true), ...
                struct('name','SiO2',        'thick',200,'sld',3.47, 'abs',0,'rough',5,'fixed',false), ...
                struct('name','Silicon',     'thick',0,  'sld',2.073,'abs',0,'rough',3,'fixed',false)];
        end

        function K = defaultKnots(obj) %#ok<MANU>
            K = [ ...
                struct('z',  0, 'sld',0.000,'fixed',true), ...
                struct('z', 40, 'sld',3.470,'fixed',false), ...
                struct('z',100, 'sld',3.470,'fixed',false), ...
                struct('z',160, 'sld',3.470,'fixed',false), ...
                struct('z',200, 'sld',2.073,'fixed',true)];
        end
    end

    methods (Static, Access = public)
        function s = emptyLayers()
            s = struct('name',{},'thick',{},'sld',{},'abs',{},'rough',{},'fixed',{});
        end

        function s = emptyKnots()
            s = struct('z',{},'sld',{},'fixed',{});
        end

        function s = normalizeLayers(input)
        %NORMALIZELAYERS  Upgrade legacy layer arrays to the canonical
        %   6-field shape (workshop pattern contract rule #1 — see
        %   feedback_workshop_pattern.md). Required when binding from
        %   sessions saved before the canonical schema existed.
            if isempty(input)
                s = bosonPlotter.reflectivity.ReflWorkshopModel.emptyLayers();
                return;
            end
            canonical = {'name','thick','sld','abs','rough','fixed'};
            defaults  = {'',  0, 0, 0, 0, false};
            s = input;
            for fi = 1:numel(canonical)
                f = canonical{fi};
                if ~isfield(s, f), [s.(f)] = deal(defaults{fi}); end
            end
        end

        function s = normalizeKnots(input)
            if isempty(input)
                s = bosonPlotter.reflectivity.ReflWorkshopModel.emptyKnots();
                return;
            end
            canonical = {'z','sld','fixed'};
            defaults  = {0, 0, false};
            s = input;
            for fi = 1:numel(canonical)
                f = canonical{fi};
                if ~isfield(s, f), [s.(f)] = deal(defaults{fi}); end
            end
        end
    end
end
