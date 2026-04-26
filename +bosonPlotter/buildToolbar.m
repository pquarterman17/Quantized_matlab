function buildToolbar(parentGL, config, registry, btnColor, iconColor)
%BUILDTOOLBAR  Clear and repopulate a toolbar grid with action buttons.
%
% Syntax
%   bosonPlotter.buildToolbar(parentGL, config, registry, btnColor)
%   bosonPlotter.buildToolbar(parentGL, config, registry, btnColor, iconColor)
%
% Inputs
%   parentGL  — uigridlayout (1 row) that hosts the toolbar buttons
%   config    — {1×N} cell of action IDs; empty → use factory default
%   registry  — struct array with fields:
%                 .id        — action identifier (also resolves icons/bosonplotter/<id>.png)
%                 .label     — text label (used as button text for icon+text
%                              actions; also serves as fallback if the icon
%                              PNG is missing)
%                 .tooltip   — hover text (typically includes [Ctrl+...] hint)
%                 .callback  — push callback
%                 .iconOnly  — true → 28px square icon-only; false → icon+text
%                              with width auto-sized via 'fit'
%                 .group     — visual grouping key; transitions between
%                              groups insert a 6px spacer column
%   btnColor  — [1×3] RGB background colour for each button
%   iconColor — [1×3] RGB stroke colour for icons (optional). When omitted
%               icons render at their source colour. Pass tk.color.icon
%               for theme-aware tinting via bosonPlotter.loadTintedIcon.
%
% Notes
%   Pure function — no closure or appData dependencies. Sets each button's
%   `Tag = act.id` so callbacks can locate buttons after creation. Filters
%   `config` to IDs that exist in `registry`; falls back to the factory
%   default config (intersected with the registry) when filtering empties
%   the list.
%
%   Group separators are uilabel widgets (not uibuttons) so the per-button
%   count assertions in tests/gui/test_toolbarConfig.m continue to hold
%   (it counts only matlab.ui.control.Button children).
%
%   Missing icon PNGs degrade gracefully: the button still renders with
%   its text label so a stripped clone (or a renamed action) never breaks
%   the toolbar.

    if nargin < 5 || isempty(iconColor)
        iconColor = [];   % skip tinting; render source PNG as-is
    end

    if isempty(config)
        config = bosonPlotter.toolbarDefaultConfig();
    end

    % Keep only IDs present in the registry
    allRegIds = {registry.id};
    config    = config(ismember(config, allRegIds));
    if isempty(config)
        config = bosonPlotter.toolbarDefaultConfig();
        config = config(ismember(config, allRegIds));
    end

    nBtns = numel(config);

    % Remove all existing children (buttons, spacer labels, group dividers)
    existingChildren = parentGL.Children;
    for ci = 1:numel(existingChildren)
        if isvalid(existingChildren(ci))
            delete(existingChildren(ci));
        end
    end

    % ── Compute column layout in one pass ──────────────────────────────
    % Column 1 is a flex spacer ('1x') that pushes the buttons to the right.
    % Subsequent columns are either:
    %   - an icon-only button: 28 px
    %   - an icon+text button: 'fit' (auto-sized to icon + label)
    %   - a 6 px spacer between adjacent buttons whose .group differs
    colWidths = {'1x'};
    btnCols   = zeros(1, nBtns);
    prevGroup = '';
    for bi = 1:nBtns
        idx = find(strcmp(allRegIds, config{bi}), 1);
        if isempty(idx); continue; end
        act = registry(idx);

        if bi > 1 && ~strcmp(act.group, prevGroup)
            colWidths{end+1} = 6; %#ok<AGROW>  group separator
        end

        if act.iconOnly
            colWidths{end+1} = 28; %#ok<AGROW>
        else
            colWidths{end+1} = 'fit'; %#ok<AGROW>
        end
        btnCols(bi) = numel(colWidths);
        prevGroup   = act.group;
    end
    parentGL.ColumnWidth = colWidths;

    % Spacer label in col 1 (uilabel — does not count as a button child)
    spacer = uilabel(parentGL, 'Text', '');
    spacer.Layout.Column = 1;

    % Resolve icon directory once
    rootDir = fileparts(fileparts(mfilename('fullpath')));
    iconDir = fullfile(rootDir, 'icons', 'bosonplotter');

    % ── Place buttons ──────────────────────────────────────────────────
    for bi = 1:nBtns
        if btnCols(bi) == 0; continue; end
        idx = find(strcmp(allRegIds, config{bi}), 1);
        act = registry(idx);

        iconPath = fullfile(iconDir, [act.id '.png']);
        hasIcon  = isfile(iconPath);
        if hasIcon && ~isempty(iconColor)
            iconPath = bosonPlotter.loadTintedIcon(iconPath, iconColor);
        end

        if act.iconOnly
            % 28x28 icon-only button. Falls back to the text label if the
            % icon PNG is missing so the button stays clickable.
            if hasIcon
                btn = uibutton(parentGL, ...
                    'Text', '', ...
                    'Icon', iconPath, ...
                    'IconAlignment', 'center', ...
                    'BackgroundColor', btnColor, ...
                    'Tooltip', act.tooltip, ...
                    'ButtonPushedFcn', act.callback);
            else
                btn = uibutton(parentGL, ...
                    'Text', act.label, ...
                    'FontSize', 9, ...
                    'BackgroundColor', btnColor, ...
                    'FontColor', [0.85 0.85 0.85], ...
                    'Tooltip', act.tooltip, ...
                    'ButtonPushedFcn', act.callback);
            end
        else
            % Icon + text button (width = 'fit'). Icon left-aligned.
            if hasIcon
                btn = uibutton(parentGL, ...
                    'Text', act.label, ...
                    'Icon', iconPath, ...
                    'IconAlignment', 'left', ...
                    'BackgroundColor', btnColor, ...
                    'FontColor', [0.85 0.85 0.85], ...
                    'FontSize', 9, ...
                    'Tooltip', act.tooltip, ...
                    'ButtonPushedFcn', act.callback);
            else
                btn = uibutton(parentGL, ...
                    'Text', act.label, ...
                    'BackgroundColor', btnColor, ...
                    'FontColor', [0.85 0.85 0.85], ...
                    'FontSize', 9, ...
                    'Tooltip', act.tooltip, ...
                    'ButtonPushedFcn', act.callback);
            end
        end
        btn.Tag           = act.id;
        btn.Layout.Column = btnCols(bi);
    end
end
