%TEST_FIGUREBUILDERMODEL  Isolation tests for the Figure Builder workshop model.
%
%   Exercises FigureBuilderModel + the package generateMultiPanel
%   against synthetic datasets. Proves the workshop pattern decouples
%   figure-builder logic from the dialog so figures can be produced
%   programmatically.
%
%   Run:
%     run tests/fitting/test_figureBuilderModel
%     runAllTests(Group="fitting")

clear; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(fileparts(thisDir));
if ~contains(path, rootDir)
    addpath(rootDir);
end

fprintf('\n=== test_figureBuilderModel ===\n');
passed = 0;
failed = 0;

% ════════════════════════════════════════════════════════════════════
%  Synthetic dataset builder
% ════════════════════════════════════════════════════════════════════
% Wrap each cell-valued field in an extra layer of {} to prevent
% struct() from broadcasting the cell contents into a struct array.
makeDS = @(name, x, ys, labels) struct( ...
    'filepath', sprintf('synthetic_%s.dat', name), ...
    'data', struct('time', x, 'values', ys, ...
                   'labels', {labels}, ...
                   'units',  {repmat({''}, 1, numel(labels))}, ...
                   'metadata', struct('x_column_name', 'X')));

% ════════════════════════════════════════════════════════════════════
%  CONSTRUCTION + DEFAULTS
% ════════════════════════════════════════════════════════════════════
fprintf('\n--- Construction + defaults ---\n');
try
    m = bosonPlotter.figureBuilder.FigureBuilderModel();
    assert(strcmp(m.figureType, 'Multi-Panel'), 'default figureType');
    assert(m.globalOpts.fontSize == 10, 'default font size');
    assert(strcmp(m.globalOpts.fontName, 'Helvetica'), 'default font name');
    assert(m.multiPanelConfig.rows == 2, 'default rows');
    assert(m.multiPanelConfig.cols == 1, 'default cols');
    assert(numel(m.multiPanelConfig.panels) == 2, 'default panel count matches rows*cols');
    fprintf('  PASS: defaults populate canonical 2x1 multi-panel config\n');
    passed = passed + 1;
catch ex
    fprintf('  FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  APPLYTEMPLATE — sets dimensions / font from preset
% ════════════════════════════════════════════════════════════════════
fprintf('\n--- applyTemplate APS / Nature ---\n');
try
    m = bosonPlotter.figureBuilder.FigureBuilderModel();
    m.applyTemplate('APS (Phys Rev)');
    assert(abs(m.globalOpts.figureWidth - 3.375) < 1e-12, 'APS width');
    assert(m.globalOpts.fontSize == 8, 'APS font size');
    assert(strcmp(m.globalOpts.fontName, 'Times New Roman'), 'APS font name');

    m.applyTemplate('Nature');
    assert(abs(m.globalOpts.figureWidth - 3.5) < 1e-12, 'Nature width');
    assert(m.globalOpts.fontSize == 7, 'Nature font size');
    fprintf('  PASS: APS + Nature templates apply correctly\n');
    passed = passed + 1;
catch ex
    fprintf('  FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  ENSUREPANELCOUNT — pads / trims panels array
% ════════════════════════════════════════════════════════════════════
fprintf('\n--- ensurePanelCount ---\n');
try
    m = bosonPlotter.figureBuilder.FigureBuilderModel();
    m.ensurePanelCount(6);
    assert(numel(m.multiPanelConfig.panels) == 6, 'pads to 6');
    m.ensurePanelCount(3);
    assert(numel(m.multiPanelConfig.panels) == 3, 'trims to 3');
    fprintf('  PASS: panel count grows + shrinks\n');
    passed = passed + 1;
catch ex
    fprintf('  FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  GENERATE — Multi-Panel figure from synthetic data
% ════════════════════════════════════════════════════════════════════
fprintf('\n--- generate() produces a multi-panel figure ---\n');
try
    x = linspace(0, 10, 100)';
    ds1 = makeDS('A', x, [sin(x), cos(x)], {'sin', 'cos'});
    ds2 = makeDS('B', x, [exp(-x/3), exp(-x/5)], {'fast', 'slow'});

    m = bosonPlotter.figureBuilder.FigureBuilderModel();
    m.figureType = 'Multi-Panel';
    m.multiPanelConfig.rows = 2;
    m.multiPanelConfig.cols = 1;
    m.ensurePanelCount(2);
    m.multiPanelConfig.panels(1).datasets  = 1;
    m.multiPanelConfig.panels(1).yChannels = {'sin'};
    m.multiPanelConfig.panels(1).title     = 'Panel 1: sin';
    m.multiPanelConfig.panels(2).datasets  = 2;
    m.multiPanelConfig.panels(2).yChannels = {'fast', 'slow'};
    m.multiPanelConfig.panels(2).title     = 'Panel 2: decays';

    fig_ = m.generate({ds1, ds2});
    cleanup = onCleanup(@() close(fig_));
    assert(isgraphics(fig_), 'generate returned a valid figure');
    assert(strcmp(fig_.Type, 'figure'), 'output is a figure');

    % Find the tiledlayout child
    tlo = findobj(fig_, 'Type', 'tiledlayout');
    assert(~isempty(tlo), 'figure contains a tiledlayout');
    axes_ = findobj(fig_, 'Type', 'axes');
    assert(numel(axes_) == 2, sprintf('expected 2 axes; got %d', numel(axes_)));
    fprintf('  PASS: 2x1 figure produced with %d axes\n', numel(axes_));
    passed = passed + 1;
catch ex
    fprintf('  FAIL: %s\n', ex.message);
    if ~isempty(ex.stack)
        for si = 1:min(5, numel(ex.stack))
            fprintf('    at %s (line %d)\n', ex.stack(si).name, ex.stack(si).line);
        end
    end
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  GENERATE — non-migrated type raises clear error
% ════════════════════════════════════════════════════════════════════
fprintf('\n--- generate() rejects non-migrated figure types ---\n');
try
    m = bosonPlotter.figureBuilder.FigureBuilderModel();
    m.figureType = 'Waterfall';
    threw = false;
    try
        m.generate({});
    catch ex
        threw = strcmp(ex.identifier, 'FigureBuilderModel:notMigrated');
    end
    assert(threw, 'generate() must throw notMigrated for unmigrated types');
    fprintf('  PASS: Waterfall raises FigureBuilderModel:notMigrated\n');
    passed = passed + 1;
catch ex
    fprintf('  FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  REGRESSION — normalizeMultiPanelConfig upgrades legacy configs
% ════════════════════════════════════════════════════════════════════
fprintf('\n--- normalizeMultiPanelConfig on legacy partial config ---\n');
try
    % Simulate a config saved before rowSpan/colSpan/y2Channels existed
    legacy = struct( ...
        'rows', 2, 'cols', 2, ...
        'panels', struct('datasets',{1,2,3,4}, 'yChannels',{{},{},{},{}}, 'title',{'','','',''}));
    upgraded = bosonPlotter.figureBuilder.FigureBuilderModel.normalizeMultiPanelConfig(legacy);
    assert(isfield(upgraded, 'shareX'), 'adds shareX');
    assert(isfield(upgraded, 'shareY'), 'adds shareY');
    assert(isfield(upgraded.panels, 'rowSpan'), 'adds rowSpan to panels');
    assert(isfield(upgraded.panels, 'colSpan'), 'adds colSpan to panels');
    assert(isfield(upgraded.panels, 'logY'), 'adds logY to panels');
    assert(isfield(upgraded.panels, 'y2Channels'), 'adds y2Channels to panels');
    assert(numel(upgraded.panels) == 4, 'preserves panel count');
    fprintf('  PASS: legacy config upgraded to canonical shape\n');
    passed = passed + 1;
catch ex
    fprintf('  FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  Summary
% ════════════════════════════════════════════════════════════════════
fprintf('\n=== test_figureBuilderModel: %d passed, %d failed ===\n', passed, failed);
if failed > 0
    error('test_figureBuilderModel:failed', '%d test(s) failed', failed);
end
