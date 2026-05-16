classdef templateManager
%TEMPLATEMANAGER  Save/load/list FigDocModel presets from disk.
%
%   Stores templates as .mat files in prefdir/figdoc_templates/.
%   Each template is a snapshot struct from FigDocModel.snapshot()
%   with an added .templateName field.
%
%   Usage:
%     bosonPlotter.figDoc.templateManager.save('myStyle', model);
%     model2 = bosonPlotter.figDoc.templateManager.load('myStyle');
%     names = bosonPlotter.figDoc.templateManager.list();
%     bosonPlotter.figDoc.templateManager.delete('myStyle');

    methods (Static)

        function save(name, model)
        %SAVE  Persist current FigDocModel state as a named template.
            s = model.snapshot();
            s.templateName = name;
            s = rmfield(s, 'dirty');
            dir_ = bosonPlotter.figDoc.templateManager.templateDir_();
            outPath = fullfile(dir_, [name '.mat']);
            save(outPath, '-struct', 's');
        end

        function applyTo(name, model)
        %APPLYTO  Load a named template and apply it to a FigDocModel.
        %   Preserves dataset-specific fields (annotations, traceStyles)
        %   and only overrides visual styling (limits, scale, fonts, legend, margins).
            dir_ = bosonPlotter.figDoc.templateManager.templateDir_();
            f = fullfile(dir_, [name '.mat']);
            if ~isfile(f)
                error('figDoc:templateNotFound', 'Template "%s" not found.', name);
            end
            s = load(f);
            styleFields = {'xScale','yScale','fontSize','fontName','gridOn', ...
                'minorTicks','tickDir','boxOn','legendVisible','legendLocation', ...
                'legendOrientation','legendFontSize','legendColumns','margins'};
            for k = 1:numel(styleFields)
                fn = styleFields{k};
                if isfield(s, fn)
                    model.(fn) = s.(fn);
                end
            end
            model.markDirty();
        end

        function names = list()
        %LIST  Return cell array of available template names.
            dir_ = bosonPlotter.figDoc.templateManager.templateDir_();
            files = dir(fullfile(dir_, '*.mat'));
            names = cell(1, numel(files));
            for k = 1:numel(files)
                [~, names{k}] = fileparts(files(k).name);
            end
        end

        function delete(name)
        %DELETE  Remove a named template from disk.
            dir_ = bosonPlotter.figDoc.templateManager.templateDir_();
            f = fullfile(dir_, [name '.mat']);
            if isfile(f)
                builtin('delete', f);
            end
        end

    end

    methods (Static, Access = private)
        function d = templateDir_()
            d = fullfile(prefdir, 'figdoc_templates');
            if ~isfolder(d)
                mkdir(d);
            end
        end
    end
end
