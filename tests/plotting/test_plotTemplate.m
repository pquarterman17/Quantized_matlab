%TEST_PLOTTEMPLATE  Tests for plotting.plotTemplate save/load/apply/list/delete.
%
%   Run:
%       run tests/plotting/test_plotTemplate
%       runAllTests(Group="plotting")

clear; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(fileparts(thisDir));
if ~contains(path, rootDir)
    addpath(rootDir);
end

fprintf('\n=== test_plotTemplate ===\n');
passed = 0;
failed = 0;

% ────────────────────────────────────────────────────────────────────────
%  Redirect template storage to a temp directory so tests are isolated
% ────────────────────────────────────────────────────────────────────────
tmpDir  = fullfile(tempdir(), sprintf('tft_tmpl_test_%d', round(rand()*1e6)));
mkdir(tmpDir);

% Monkey-patch templatePath by overriding prefdir via a custom local wrapper.
% Since plotTemplate builds its dir from prefdir(), we test the full public
% API via a small helper that temporarily swaps the storage root.
% Strategy: call the function directly but pass templates through the
% public API — tests verify observable behaviour, not internal paths.
%
% We use a separate writable dir by calling the underlying private helpers
% through plotTemplate's public actions, seeding with an explicit .mat.

% Helper: seed a fake template .mat file directly in tmpDir
function seedTemplate(dir, name, ax)
    tmpl = captureForTest(ax, name);
    filepath = fullfile(dir, [matlab.lang.makeValidName(name) '.mat']);
    save(filepath, 'tmpl');
end

% ════════════════════════════════════════════════════════════════════════
%  Shared test figure
% ════════════════════════════════════════════════════════════════════════
fig1 = figure('Visible','off');
ax1  = axes(fig1);
x    = linspace(0, 2*pi, 50)';
plot(ax1, x, sin(x), 'Color', [0.1 0.4 0.8], 'LineWidth', 2.0, ...
    'LineStyle', '-', 'Marker', 'o', 'MarkerSize', 5);
hold(ax1, 'on');
plot(ax1, x, cos(x), 'Color', [0.8 0.1 0.1], 'LineWidth', 1.5);
ax1.FontName   = 'Helvetica';
ax1.FontSize   = 12;
ax1.Box        = 'on';
ax1.XGrid      = 'on';
ax1.YGrid      = 'on';
ax1.TickDir    = 'in';
ax1.XScale     = 'linear';
ax1.YScale     = 'linear';
xlabel(ax1, 'Time (s)');
ylabel(ax1, 'Amplitude');
title(ax1, 'Test Figure');

% ════════════════════════════════════════════════════════════════════════
%  TEST 1: Save and load — verify all fields present
% ════════════════════════════════════════════════════════════════════════
fprintf('\n--- Save / Load ---\n');

% Directly invoke the internal capture helper via plotTemplate's save action,
% but redirect output by pointing prefdir mock. We can't mock prefdir in MATLAB
% without an external toolbox, so instead we call save with the public API
% and verify the file appeared in prefdir().
realTmplDir = fullfile(prefdir(), 'boson_templates');
testName1   = 'TFT_test_template_001';
testFile1   = fullfile(realTmplDir, [matlab.lang.makeValidName(testName1) '.mat']);

% Clean up any leftover from a previous run
if isfile(testFile1), delete(testFile1); end

try
    plotting.plotTemplate('save', Name=testName1, Axes=ax1);
    if isfile(testFile1)
        fprintf('  PASS: save created .mat file\n'); passed = passed + 1;
    else
        fprintf('  FAIL: .mat file not found after save\n'); failed = failed + 1;
    end
catch ME
    fprintf('  FAIL: save threw: %s\n', ME.message); failed = failed + 1;
end

% Load and verify struct fields
try
    tmpl = plotting.plotTemplate('load', Name=testName1);
    reqFields = {'name','created','axesProps','lineProps','colorOrder', ...
                 'legendProps','figureProps'};
    allPresent = all(cellfun(@(f) isfield(tmpl, f), reqFields));
    if allPresent
        fprintf('  PASS: loaded struct has all required fields\n'); passed = passed + 1;
    else
        fprintf('  FAIL: loaded struct missing fields\n'); failed = failed + 1;
    end
catch ME
    fprintf('  FAIL: load threw: %s\n', ME.message); failed = failed + 1;
end

% Verify captured values
try
    tmpl = plotting.plotTemplate('load', Name=testName1);
    ok = strcmp(tmpl.axesProps.FontName, 'Helvetica') && ...
         tmpl.axesProps.FontSize == 12 && ...
         strcmp(tmpl.axesProps.Box, 'on') && ...
         strcmp(tmpl.axesProps.XGrid, 'on') && ...
         strcmp(tmpl.axesProps.TickDir, 'in') && ...
         numel(tmpl.lineProps) == 2;
    if ok
        fprintf('  PASS: captured properties match source axes\n'); passed = passed + 1;
    else
        fprintf('  FAIL: captured property mismatch\n'); failed = failed + 1;
    end
catch ME
    fprintf('  FAIL: verify threw: %s\n', ME.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  TEST 2: Apply — verify properties transferred to new axes
% ════════════════════════════════════════════════════════════════════════
fprintf('\n--- Apply ---\n');

fig2 = figure('Visible','off');
ax2  = axes(fig2);
plot(ax2, x, x.*0.1, 'Color', [0 0 0], 'LineWidth', 0.5);
hold(ax2, 'on');
plot(ax2, x, -x.*0.05, 'Color', [0.5 0.5 0.5], 'LineWidth', 0.5);
ax2.FontSize = 8;
ax2.Box      = 'off';

try
    plotting.plotTemplate('apply', Name=testName1, Axes=ax2);
    ok = ax2.FontSize == 12 && ...
         strcmp(ax2.FontName, 'Helvetica') && ...
         strcmp(ax2.Box, 'on') && ...
         strcmp(ax2.XGrid, 'on') && ...
         strcmp(ax2.TickDir, 'in');
    if ok
        fprintf('  PASS: apply transferred axes properties\n'); passed = passed + 1;
    else
        fprintf('  FAIL: apply did not transfer properties (FontSize=%d Box=%s)\n', ...
            ax2.FontSize, ax2.Box); failed = failed + 1;
    end
catch ME
    fprintf('  FAIL: apply threw: %s\n', ME.message); failed = failed + 1;
end

% Verify line properties applied (first two lines)
try
    lineKids = findobj(ax2, 'Type', 'line', '-depth', 1);
    tmpl = plotting.plotTemplate('load', Name=testName1);
    colorOk = isequal(lineKids(1).Color, tmpl.lineProps(1).Color) && ...
              lineKids(1).LineWidth == tmpl.lineProps(1).LineWidth;
    if colorOk
        fprintf('  PASS: apply transferred line properties\n'); passed = passed + 1;
    else
        fprintf('  FAIL: line properties not transferred\n'); failed = failed + 1;
    end
catch ME
    fprintf('  FAIL: line verify threw: %s\n', ME.message); failed = failed + 1;
end

close(fig2);

% ════════════════════════════════════════════════════════════════════════
%  TEST 3: List — returns saved templates
% ════════════════════════════════════════════════════════════════════════
fprintf('\n--- List ---\n');

try
    names = plotting.plotTemplate('list');
    if iscell(names) && any(strcmp(names, testName1))
        fprintf('  PASS: list returns saved template name\n'); passed = passed + 1;
    else
        fprintf('  FAIL: list does not contain saved template\n'); failed = failed + 1;
    end
catch ME
    fprintf('  FAIL: list threw: %s\n', ME.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  TEST 4: Delete — removes the template file
% ════════════════════════════════════════════════════════════════════════
fprintf('\n--- Delete ---\n');

try
    plotting.plotTemplate('delete', Name=testName1);
    if ~isfile(testFile1)
        fprintf('  PASS: delete removed .mat file\n'); passed = passed + 1;
    else
        fprintf('  FAIL: file still exists after delete\n'); failed = failed + 1;
    end
catch ME
    fprintf('  FAIL: delete threw: %s\n', ME.message); failed = failed + 1;
end

% Delete of non-existent template should throw
try
    plotting.plotTemplate('delete', Name=testName1);
    fprintf('  FAIL: delete non-existent did not throw\n'); failed = failed + 1;
catch
    fprintf('  PASS: delete non-existent throws as expected\n'); passed = passed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  TEST 5: Round-trip — save → apply → verify styling matches
% ════════════════════════════════════════════════════════════════════════
fprintf('\n--- Round-trip ---\n');

testName2 = 'TFT_test_roundtrip_002';
testFile2 = fullfile(realTmplDir, [matlab.lang.makeValidName(testName2) '.mat']);
if isfile(testFile2), delete(testFile2); end

ax1.FontSize  = 14;
ax1.FontName  = 'Arial';
ax1.TickDir   = 'out';
ax1.Box       = 'off';

try
    plotting.plotTemplate('save', Name=testName2, Axes=ax1);

    fig3 = figure('Visible','off');
    ax3  = axes(fig3);
    plot(ax3, x, rand(size(x)));

    plotting.plotTemplate('apply', Name=testName2, Axes=ax3);

    ok = ax3.FontSize == 14 && ...
         strcmp(ax3.FontName, 'Arial') && ...
         strcmp(ax3.TickDir, 'out') && ...
         strcmp(ax3.Box, 'off');
    if ok
        fprintf('  PASS: round-trip save→apply preserves styling\n'); passed = passed + 1;
    else
        fprintf('  FAIL: round-trip mismatch (FontSize=%d FontName=%s TickDir=%s Box=%s)\n', ...
            ax3.FontSize, ax3.FontName, ax3.TickDir, ax3.Box);
        failed = failed + 1;
    end
    close(fig3);
catch ME
    fprintf('  FAIL: round-trip threw: %s\n', ME.message); failed = failed + 1;
end

% Cleanup round-trip template
if isfile(testFile2), delete(testFile2); end

% ════════════════════════════════════════════════════════════════════════
%  TEST 6: Apply to axes with fewer lines than template
% ════════════════════════════════════════════════════════════════════════
fprintf('\n--- Edge case: fewer lines ---\n');

testName3 = 'TFT_test_fewlines_003';
testFile3 = fullfile(realTmplDir, [matlab.lang.makeValidName(testName3) '.mat']);
if isfile(testFile3), delete(testFile3); end

% ax1 has 2 lines — save template capturing 2 lineProps
ax1.FontSize = 11;
plotting.plotTemplate('save', Name=testName3, Axes=ax1);

fig4 = figure('Visible','off');
ax4  = axes(fig4);
plot(ax4, x, x);   % only 1 line — template has 2

try
    plotting.plotTemplate('apply', Name=testName3, Axes=ax4);
    % Should not throw; only first line gets styled
    lineKids = findobj(ax4, 'Type', 'line', '-depth', 1);
    if numel(lineKids) == 1
        fprintf('  PASS: apply with fewer lines does not throw\n'); passed = passed + 1;
    else
        fprintf('  FAIL: unexpected line count %d\n', numel(lineKids)); failed = failed + 1;
    end
catch ME
    fprintf('  FAIL: apply with fewer lines threw: %s\n', ME.message); failed = failed + 1;
end
close(fig4);
if isfile(testFile3), delete(testFile3); end

% ════════════════════════════════════════════════════════════════════════
%  TEST 7: Save and apply with no legend present
% ════════════════════════════════════════════════════════════════════════
fprintf('\n--- Edge case: no legend ---\n');

testName4 = 'TFT_test_nolegend_004';
testFile4 = fullfile(realTmplDir, [matlab.lang.makeValidName(testName4) '.mat']);
if isfile(testFile4), delete(testFile4); end

fig5 = figure('Visible','off');
ax5  = axes(fig5);
plot(ax5, x, sin(x));
% No legend added

try
    plotting.plotTemplate('save', Name=testName4, Axes=ax5);
    fprintf('  PASS: save with no legend does not throw\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: save with no legend threw: %s\n', ME.message); failed = failed + 1;
end

fig6 = figure('Visible','off');
ax6  = axes(fig6);
plot(ax6, x, cos(x));

try
    plotting.plotTemplate('apply', Name=testName4, Axes=ax6);
    fprintf('  PASS: apply with no legend does not throw\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: apply with no legend threw: %s\n', ME.message); failed = failed + 1;
end
close(fig5); close(fig6);
if isfile(testFile4), delete(testFile4); end

% ════════════════════════════════════════════════════════════════════════
%  Cleanup
% ════════════════════════════════════════════════════════════════════════
close(fig1);
if isfolder(tmpDir), rmdir(tmpDir, 's'); end

% ════════════════════════════════════════════════════════════════════════
%  SUMMARY
% ════════════════════════════════════════════════════════════════════════
fprintf('\n=== test_plotTemplate: %d passed, %d failed ===\n\n', passed, failed);
if failed > 0
    error('test_plotTemplate:failures', '%d test(s) failed.', failed);
end


% ════════════════════════════════════════════════════════════════════════
%  Local helper — captures axes for direct .mat seeding in tests
% ════════════════════════════════════════════════════════════════════════
function tmpl = captureForTest(ax, name)
    tmpl.name    = char(name);
    tmpl.created = datetime('now');
    ap.FontName = ax.FontName; ap.FontSize = ax.FontSize;
    ap.FontWeight = ax.FontWeight; ap.XColor = ax.XColor; ap.YColor = ax.YColor;
    ap.LineWidth = ax.LineWidth; ap.Box = ax.Box; ap.XGrid = ax.XGrid;
    ap.YGrid = ax.YGrid; ap.XScale = ax.XScale; ap.YScale = ax.YScale;
    ap.XMinorGrid = ax.XMinorGrid; ap.YMinorGrid = ax.YMinorGrid;
    ap.TickDir = ax.TickDir; ap.TickLength = ax.TickLength; ap.Color = ax.Color;
    ap.XLabelString = ax.XLabel.String; ap.XLabelFontSize = ax.XLabel.FontSize;
    ap.YLabelString = ax.YLabel.String; ap.YLabelFontSize = ax.YLabel.FontSize;
    ap.TitleString = ax.Title.String;   ap.TitleFontSize  = ax.Title.FontSize;
    tmpl.axesProps = ap;
    tmpl.lineProps = struct('Color',{},'LineWidth',{},'LineStyle',{},'Marker',{},'MarkerSize',{});
    tmpl.colorOrder = ax.ColorOrder;
    tmpl.legendProps = struct('Location','northeast','FontSize',9,'Box','on','Interpreter','none');
    fig = ancestor(ax,'figure');
    tmpl.figureProps = struct('Color', fig.Color, 'Width', fig.Position(3), 'Height', fig.Position(4));
end
