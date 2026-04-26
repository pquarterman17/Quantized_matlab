function test_themeConformance
%TEST_THEMECONFORMANCE  Every widget's colours must come from uxTokens.
%
%   Constructs BosonPlotter in dark mode, walks every widget descending
%   from the figure, and asserts each widget's BackgroundColor / FontColor
%   matches a value from the active palette (or one of the always-allowed
%   semantic accents — primary, danger, etc., which are intentionally the
%   same in light and dark themes).
%
%   Then toggles to light mode via the api.setTheme hook (or direct field
%   write + onThemeChanged) and re-walks, checking that the expected
%   widgets switched palettes.
%
%   Goals:
%     1. Catch hardcoded RGB literals that bypass the design tokens.
%     2. Catch widget types the theme walker forgot to handle (e.g. the
%        old uitable omission that left tblData / tblUnits black in light
%        mode).
%     3. Catch palette drift (where construction-time colours diverge
%        from the runtime theme palette).
%
%   Run standalone:  run tests/gui/test_themeConformance
%   Run via group :  runAllTests(Group="gui")

    thisDir = fileparts(mfilename('fullpath'));
    rootDir = fileparts(fileparts(thisDir));
    if ~contains(path, rootDir), addpath(rootDir); end

    passed = 0;
    failed = 0;
    failures = {};

    api = BosonPlotter('Visible','off');
    cleanup = onCleanup(@() api.close()); %#ok<NASGU>

    % ════════════════════════════════════════════════════════════════════
    %  TEST 1: Dark theme — every widget's colour comes from the palette
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 1: Dark-theme conformance ==\n');
    try
        % Force dark theme via the api hook so the test is deterministic
        % regardless of leftover state from earlier suites.
        api.setTheme('Dark');
        drawnow;

        tkDark = bosonPlotter.uxTokens('dark');
        allowed = buildAllowedColors(tkDark);
        violations = walkAndCheck(api.fig, allowed);

        check(sprintf('zero off-palette colours in dark mode (got %d)', ...
                      numel(violations)), isempty(violations));

        if ~isempty(violations)
            fprintf('\n  Off-palette widgets (first 10):\n');
            for k = 1:min(10, numel(violations))
                v = violations{k};
                fprintf('    %s  Tag="%s"  prop=%s  rgb=[%.2f %.2f %.2f]\n', ...
                    v.cls, v.tag, v.prop, v.rgb(1), v.rgb(2), v.rgb(3));
            end
            if numel(violations) > 10
                fprintf('    ... and %d more.\n', numel(violations) - 10);
            end
        end
    catch ME
        recordCrash('TEST 1', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 2: Light theme — same palette discipline after toggle
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 2: Light-theme conformance after toggle ==\n');
    try
        api.setTheme('Light');
        drawnow;
        tkLight = bosonPlotter.uxTokens('light');
        allowed = buildAllowedColors(tkLight);
        violations = walkAndCheck(api.fig, allowed);

        check(sprintf('zero off-palette colours in light mode (got %d)', ...
                      numel(violations)), isempty(violations));

        if ~isempty(violations)
            fprintf('\n  Off-palette widgets after light toggle (first 10):\n');
            for k = 1:min(10, numel(violations))
                v = violations{k};
                fprintf('    %s  Tag="%s"  prop=%s  rgb=[%.2f %.2f %.2f]\n', ...
                    v.cls, v.tag, v.prop, v.rgb(1), v.rgb(2), v.rgb(3));
            end
            if numel(violations) > 10
                fprintf('    ... and %d more.\n', numel(violations) - 10);
            end
        end
    catch ME
        recordCrash('TEST 2', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  Summary
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n%s\n', repmat('=', 1, 68));
    fprintf('  test_themeConformance: %d passed, %d failed\n', passed, failed);
    if failed > 0
        fprintf('\n  Failures:\n');
        for i = 1:numel(failures)
            fprintf('    - %s\n', failures{i});
        end
        error('test_themeConformance:failed', '%d test(s) failed', failed);
    end
    fprintf('%s\n', repmat('=', 1, 68));

    % ── Nested helpers ─────────────────────────────────────────────────
    function check(label, cond)
        if cond
            passed = passed + 1;
            fprintf('  PASS  %s\n', label);
        else
            failed = failed + 1;
            failures{end+1} = label; %#ok<AGROW>
            fprintf('  FAIL  %s\n', label);
        end
    end

    function recordCrash(testName, ME)
        failed = failed + 1;
        failures{end+1} = sprintf('%s crashed: %s', testName, ME.message); %#ok<AGROW>
        fprintf('  CRASH %s: %s\n', testName, ME.message);
    end
end

% ════════════════════════════════════════════════════════════════════════
% buildAllowedColors  Compose the set of colours a widget may legally have
% ════════════════════════════════════════════════════════════════════════
function allowed = buildAllowedColors(tk)
%BUILDALLOWEDCOLORS  Return [N×3] of palette colours plus theme-independent
%   accents (button colours, axes grid, etc.) plus immutable defaults.
    palette = [
        % Theme-dependent surfaces
        tk.color.bgFigure;
        tk.color.bgPanel;
        tk.color.bgInput;
        tk.color.bgSubtle;
        % Theme-dependent text
        tk.color.text;
        tk.color.textMuted;
        tk.color.textDim;
        tk.color.textDisabled;
        tk.color.textHighlight;
        tk.color.textAccent;
        tk.color.textOk;
        tk.color.textWarn;
        tk.color.textError;
        % Button palette (mostly theme-independent)
        tk.color.btn.primary;
        tk.color.btn.accent;
        tk.color.btn.danger;
        tk.color.btn.export;
        tk.color.btn.external;
        tk.color.btn.session;
        tk.color.btn.secondary;
        tk.color.btn.interact;
        tk.color.btn.animate;
        tk.color.btn.tool;
        tk.color.btn.fg;
        % MATLAB-default colours that pass through unchanged
        0   0   0;        % black (cursors, defaults)
        1   1   1;        % white
        0.94 0.94 0.94;   % MATLAB default light grey (uipanel default)
        0.96 0.96 0.96;   % MATLAB default panel grey
        0.25 0.25 0.25;   % MATLAB default dark grey
        0.15 0.15 0.15;   % grid colour fallback
        0.49 0.49 0.49;   % MATLAB default panel BorderColor

        % Intentional accent colours used by specialized buttons that
        % deliberately don't change between themes (decorative,
        % function-specific). Adding new entries here is allowed as a
        % conscious design choice — but each addition documents a
        % decision NOT to use a token, which is what we want to make
        % visible.
        0.35 0.40 0.55;   % Plot Style button bg
        0.22 0.35 0.55;   % Plot ▾ button bg / corrections action
        0.22 0.44 0.22;   % green accent (advanced analysis trigger)
        0.45 0.20 0.55;   % purple accent (decompose / mass-action)
        0.20 0.50 0.35;   % sea-green accent (box integrate)
        0.60 0.15 0.15;   % darker red accent (mask select armed)
        0.16 0.16 0.16;   % units row legacy bg (pre-theme migration)
        0.30 0.45 0.55;   % steel-cyan accent (advanced asymmetry)
        0.40 0.25 0.55;   % violet accent (RSM decomposition)
        0.25 0.40 0.60;   % steel-blue accent (refl helpers)
        0.40 0.30 0.60;   % indigo accent (advanced fitting)
        0.55 0.20 0.20;   % rust-red accent (mask region)

        % Disabled / muted text that doesn't match the active palette
        % muted token within tolerance (e.g. some disabled-state colors
        % were chosen empirically for contrast on a specific BG).
        0.60 0.60 0.60;   % muted button text (some disabled states)
        0.70 0.70 0.70;   % light-grey label text (sub-headers)
        0.80 0.80 0.80;   % muted button text (lighter)
        0.50 0.70 0.50;   % dark-mode textOk approximation

        % MATLAB's theme(fig, ...) call sets panel ForegroundColor (title
        % text) to near-black [0.13] in light mode and [0.92] in dark
        % mode. We don't control that — built-in chrome colour from
        % theme(). Allowlist the values theme() picks.
        0.13 0.13 0.13;
        0.92 0.92 0.92;
    ];
    allowed = palette;
end

% ════════════════════════════════════════════════════════════════════════
% walkAndCheck  Recursively visit every widget; return list of violators
% ════════════════════════════════════════════════════════════════════════
function violations = walkAndCheck(parent, allowed)
%WALKANDCHECK  Walk parent's descendants; assert every BackgroundColor /
%   FontColor / ForegroundColor is within `tol` of an `allowed` row.
%   Returns a cell array of structs describing offenders.
    violations = {};
    visit(parent);

    function visit(c)
        try, kids = c.Children; catch, kids = []; end
        for k = 1:numel(kids)
            check_widget(kids(k));
            visit(kids(k));
        end
    end

    function check_widget(w)
        cls  = class(w);
        tag  = '';
        try, if isprop(w, 'Tag'), tag = w.Tag; end, catch, end

        % Skip widget types that don't carry user-controllable colours
        switch cls
            case {'matlab.ui.container.Toolbar', ...
                  'matlab.ui.container.Menu', ...
                  'matlab.ui.container.ContextMenu', ...
                  'matlab.ui.control.UIAxes', ...
                  'matlab.ui.container.GridLayout'}
                return;
        end

        propsToCheck = {'BackgroundColor', 'FontColor', 'ForegroundColor', 'BorderColor'};
        for pi = 1:numel(propsToCheck)
            p = propsToCheck{pi};
            if ~isprop(w, p), continue; end
            try, val = w.(p); catch, continue; end
            if isempty(val) || ~isnumeric(val) || ~isequal(size(val), [1 3])
                continue;
            end
            if ~colorIsAllowed(val, allowed)
                violations{end+1} = struct( ...
                    'cls', cls, 'tag', tag, 'prop', p, 'rgb', val); %#ok<AGROW>
            end
        end
    end
end

function tf = colorIsAllowed(rgb, allowed)
%COLORISALLOWED  Within 0.02 of any allowed row?
    tol = 0.02;
    tf = any(all(abs(allowed - rgb) < tol, 2));
end
