classdef CurveFitWorkshopModel < handle
%CURVEFITWORKSHOPMODEL  State container for the Curve Fit Workshop.
%
%   Owns the curve-fit dialog's algorithmic state: selected model
%   (built-in or custom equation), parameter table (initial guesses,
%   bounds, fixed flags, constraint expressions), data-segment scope
%   (channel + x-range), weighting choice, and the most recent fit
%   result. Algorithm itself stays in the +fitting/ package
%   (fitting.models, fitting.curveFit, fitting.parseEquation,
%   fitting.autoGuess, fitting.fitCompare).
%
%   Workshop pattern (MASTERPLAN W5 #60). The dialog view
%   (+bosonPlotter/curveFitting.m) writes UI changes onto this model
%   and renders results from it. The model is GUI-free so it can be
%   exercised in isolation against synthetic data.
%
%   Usage:
%       m = bosonPlotter.curveFit.CurveFitWorkshopModel();
%       m.bindFromDataset(ds);
%       m.selectModel('Gaussian');
%       m.params(2).p0 = 5;          % initial centre
%       res = m.fit(xSeg, ySeg);     % populates m.result
%       y   = m.simulate(xDense);

    % ── Model selection ─────────────────────────────────────────────
    properties
        modelName       char    = ''            % name from fitting.models() catalog
                                                % or 'Custom Equation'
        customEquation  char    = ''            % source string (unparsed)
        customFcn               = []            % @(x,p) — populated by parseCustom
        customNames     cell    = {}
    end

    % ── Data-segment scope ──────────────────────────────────────────
    properties
        channelIdx      double  = 1             % 1-based column in ds.values
        xMin            double  = -Inf
        xMax            double  = Inf
        weightsKind     char    = 'None'        % 'None' | '1/y' | '1/y²' | '1/σ²'
    end

    % ── Display preferences ─────────────────────────────────────────
    properties
        showBands       logical = false
    end

    % ── Parameter table (per-parameter struct array) ─────────────────
    % `params` is writable from outside — view callbacks bound to a
    % uitable need to do `model.params(idx).p0 = val` directly. `result`
    % stays protected because only `fit` should populate it; the view
    % consumes it for display.
    properties
        params                  = bosonPlotter.curveFit.CurveFitWorkshopModel.emptyParamArray()
    end

    properties (SetAccess = protected)
        result          struct  = struct()
        catalog         struct  = struct([])    % cached fitting.models() catalog
    end

    methods
        function obj = CurveFitWorkshopModel()
            try
                obj.catalog = fitting.models();
            catch
                obj.catalog = struct([]);
            end
        end

        function bindFromDataset(obj, ds)
        %BINDFROMDATASET  Initialise channel + x-range from a dataset.
            if ~isempty(ds.corrData) && ~isempty(ds.corrData.time)
                d = ds.corrData;
            else
                d = ds.data;
            end
            obj.channelIdx = 1;
            if ~isempty(d.time)
                obj.xMin = double(min(d.time));
                obj.xMax = double(max(d.time));
            end
            obj.result = struct();
        end

        % ── Model picking ───────────────────────────────────────────
        function selectModel(obj, name)
        %SELECTMODEL  Pick a built-in model from fitting.models() by name.
        %   Resets the param table to the model's parameter list with
        %   p0=0, unbounded, not fixed.
            obj.modelName = name;
            if isempty(obj.catalog), return; end
            ix = find(strcmp({obj.catalog.name}, name), 1);
            if isempty(ix), return; end
            m = obj.catalog(ix);
            obj.params = bosonPlotter.curveFit.CurveFitWorkshopModel.makeParamArray(m.paramNames);
        end

        function setCustomEquation(obj, eqStr)
        %SETCUSTOMEQUATION  Parse a custom equation; store fcn + param names.
        %   Throws if parseEquation fails. Caller is responsible for the
        %   try/catch + UI alert.
            [obj.customFcn, obj.customNames] = fitting.parseEquation(eqStr);
            obj.customEquation = eqStr;
            obj.modelName = 'Custom Equation';
            obj.params = bosonPlotter.curveFit.CurveFitWorkshopModel.makeParamArray(obj.customNames);
        end

        function [fcn, pNames] = activeFunction(obj)
        %ACTIVEFUNCTION  Return the model handle + param-name list for the
        %   current selection (built-in or custom).
            if strcmp(obj.modelName, 'Custom Equation')
                if isempty(obj.customFcn)
                    error('CurveFitWorkshopModel:noCustom', ...
                        'No custom equation parsed. Call setCustomEquation first.');
                end
                fcn    = obj.customFcn;
                pNames = obj.customNames;
                return;
            end
            ix = find(strcmp({obj.catalog.name}, obj.modelName), 1);
            if isempty(ix)
                error('CurveFitWorkshopModel:unknownModel', ...
                    'Model "%s" not found in fitting.models() catalog.', obj.modelName);
            end
            fcn    = obj.catalog(ix).fcn;
            pNames = obj.catalog(ix).paramNames;
        end

        % ── Parameter access ────────────────────────────────────────
        function setParam(obj, idx, fld, val)
        %SETPARAM  Update one field of params(idx). Used by view callbacks
        %   when the user edits a cell in the parameter uitable.
            if idx < 1 || idx > numel(obj.params), return; end
            if ~isfield(obj.params(idx), fld)
                error('CurveFitWorkshopModel:badField', ...
                    '"%s" is not a parameter field.', fld);
            end
            obj.params(idx).(fld) = val;
        end

        function [p0, lb, ub, fixed, constraints] = paramVectors(obj)
        %PARAMVECTORS  Pull p0/lb/ub/fixed/constraint vectors from the table.
            n = numel(obj.params);
            p0          = zeros(1, n);
            lb          = repmat(-Inf, 1, n);
            ub          = repmat( Inf, 1, n);
            fixed       = false(1, n);
            constraints = repmat({''}, 1, n);
            for k = 1:n
                p0(k)          = obj.params(k).p0;
                lb(k)          = obj.params(k).lb;
                ub(k)          = obj.params(k).ub;
                fixed(k)       = obj.params(k).fixed;
                constraints{k} = obj.params(k).constraint;
            end
        end

        % ── Algorithms (delegate to +fitting/ package) ──────────────
        function autoGuess(obj, xSeg, ySeg)
        %AUTOGUESS  Fill p0 fields from data shape via fitting.autoGuess.
            if strcmp(obj.modelName, 'Custom Equation'), return; end
            try
                p0g = fitting.autoGuess(obj.modelName, xSeg, ySeg);
            catch
                return;
            end
            for k = 1:min(numel(obj.params), numel(p0g))
                obj.params(k).p0 = p0g(k);
            end
        end

        function res = fit(obj, xSeg, ySeg, weights)
        %FIT  Run fitting.curveFit with current params, weights, constraints.
        %   Stores result on obj.result and returns it.
            arguments
                obj
                xSeg     (:,1) double
                ySeg     (:,1) double
                weights        = []
            end
            [fcn, pNames] = obj.activeFunction();
            [p0, lb, ub, fixed, constraints] = obj.paramVectors();
            hasConstraints = any(~cellfun(@isempty, constraints));

            if hasConstraints
                res = fitting.curveFit(xSeg, ySeg, fcn, p0, ...
                    Lower=lb, Upper=ub, Fixed=fixed, Weights=weights, ...
                    Constraints=constraints, ParamNames=pNames);
            else
                res = fitting.curveFit(xSeg, ySeg, fcn, p0, ...
                    Lower=lb, Upper=ub, Fixed=fixed, Weights=weights);
            end

            % Cache fit metadata + handle
            res.model      = obj.modelName;
            res.modelFcn   = fcn;
            res.paramNames = pNames;
            obj.result     = res;

            % Update each param's fitted value + error
            for k = 1:numel(obj.params)
                if k <= numel(res.params)
                    obj.params(k).fitted    = res.params(k);
                    obj.params(k).fittedErr = res.errors(k);
                end
            end
        end

        function y = simulate(obj, xv)
        %SIMULATE  Evaluate active function at xv using current params.p0.
            [fcn, ~] = obj.activeFunction();
            [p0, ~, ~, ~, ~] = obj.paramVectors();
            y = fcn(xv, p0);
        end

        function tf = hasResult(obj)
            tf = ~isempty(obj.result) && isstruct(obj.result) ...
                && isfield(obj.result, 'params') && ~isempty(obj.result.params);
        end
    end

    methods (Static, Access = public)
        function s = emptyParamArray()
        %EMPTYPARAMARRAY  Canonical empty parameter struct array.
            s = struct('name',{},'p0',{},'lb',{},'ub',{},'fixed',{}, ...
                       'constraint',{},'fitted',{},'fittedErr',{});
        end

        function s = makeParamArray(names)
        %MAKEPARAMARRAY  Build a fresh parameter struct array from names.
            n = numel(names);
            s = bosonPlotter.curveFit.CurveFitWorkshopModel.emptyParamArray();
            for k = 1:n
                s(k).name       = names{k}; %#ok<AGROW>
                s(k).p0         = 0;
                s(k).lb         = -Inf;
                s(k).ub         = Inf;
                s(k).fixed      = false;
                s(k).constraint = '';
                s(k).fitted     = NaN;
                s(k).fittedErr  = NaN;
            end
        end

        function s = normalizeParamArray(input)
        %NORMALIZEPARAMARRAY  Upgrade legacy param entries (e.g. without
        %   'constraint' or 'fittedErr') to the canonical 8-field shape.
        %   Required so any external feeder of params (a session loader,
        %   a future scripted entry point) can hand us data without
        %   triggering "Subscripted assignment between dissimilar
        %   structures" — see plans/workshop-conversion-plan.md
        %   "Lessons from the Peak conversion".
            if isempty(input)
                s = bosonPlotter.curveFit.CurveFitWorkshopModel.emptyParamArray();
                return;
            end
            canonical = {'name','p0','lb','ub','fixed','constraint','fitted','fittedErr'};
            defaults  = {'',  0,  -Inf, Inf, false, '', NaN, NaN};
            s = input;
            for fi = 1:numel(canonical)
                f = canonical{fi};
                if ~isfield(s, f)
                    [s.(f)] = deal(defaults{fi});
                end
            end
        end
    end
end
