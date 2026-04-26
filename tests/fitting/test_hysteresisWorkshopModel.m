%TEST_HYSTERESISWORKSHOPMODEL  Tests for the HysteresisWorkshopModel handle class.
%
%   Exercises the model in isolation against a synthetic M(H) loop with
%   known Hc, Mr, Ms values. No GUI, no main BosonPlotter state — proves
%   the workshop pattern decouples Hysteresis logic from the orchestrator.
%
%   Run:
%     run tests/fitting/test_hysteresisWorkshopModel
%     runAllTests(Group="fitting")

clear; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(fileparts(thisDir));
if ~contains(path, rootDir)
    addpath(rootDir);
end

fprintf('\n=== test_hysteresisWorkshopModel ===\n');
passed = 0;
failed = 0;

% ════════════════════════════════════════════════════════════════════
%  Synthetic M(H) loop builder
% ════════════════════════════════════════════════════════════════════
% A simple symmetric square-ish loop using tanh: Hc=50 Oe, Ms=1.0 emu.
% Two branches: ascending sweep H: -200 → +200, descending +200 → -200.
makeLoop = @(Hc, Ms) struct( ...
    'H', [linspace(-200, 200, 200), linspace(200, -200, 200)]', ...
    'M', [Ms .* tanh((linspace(-200, 200, 200) - Hc) / 20)'; ...
          Ms .* tanh((linspace(200, -200, 200) + Hc) / 20)']);

% ════════════════════════════════════════════════════════════════════
%  CONSTRUCTION
% ════════════════════════════════════════════════════════════════════
fprintf('\n--- Construction + defaults ---\n');
try
    m = bosonPlotter.hysteresis.HysteresisWorkshopModel();
    assert(m.preSmooth == 0, 'default preSmooth');
    assert(m.subtractBg == false, 'default BG sub off');
    assert(~m.hasResult(), 'no result before analyze');
    fprintf('  PASS: defaults OK\n'); passed = passed + 1;
catch ex
    fprintf('  FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  AUTODETECT — channel detection from labels
% ════════════════════════════════════════════════════════════════════
fprintf('\n--- autoDetectChannels ---\n');
try
    [hIdx, mIdx] = bosonPlotter.hysteresis.HysteresisWorkshopModel.autoDetectChannels( ...
        {'Time Stamp', 'Magnetic Field (Oe)', 'Moment (emu)', 'Temperature (K)'});
    assert(hIdx == 2, sprintf('expected hIdx=2; got %d', hIdx));
    assert(mIdx == 3, sprintf('expected mIdx=3; got %d', mIdx));

    % Fallback when nothing matches: hIdx=0 (time axis), mIdx=1
    [hIdx2, mIdx2] = bosonPlotter.hysteresis.HysteresisWorkshopModel.autoDetectChannels( ...
        {'Foo', 'Bar', 'Baz'});
    assert(hIdx2 == 0 && mIdx2 == 1, 'fallback for non-matching labels');
    fprintf('  PASS: auto-detect picks Field/Moment columns\n');
    passed = passed + 1;
catch ex
    fprintf('  FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  BIND — auto-detect from a synthetic dataset
% ════════════════════════════════════════════════════════════════════
fprintf('\n--- bindFromDataset uses auto-detect ---\n');
try
    loop = makeLoop(50, 1.0);
    nP = numel(loop.H);
    ds = struct( ...
        'data', struct('time', (1:nP)', ...
                       'values', [loop.H, loop.M], ...
                       'labels', {{'Magnetic Field (Oe)', 'Moment (emu)'}}, ...
                       'units',  {{'Oe', 'emu'}}, ...
                       'metadata', struct()), ...
        'corrData', []);

    m = bosonPlotter.hysteresis.HysteresisWorkshopModel();
    m.bindFromDataset(ds);
    assert(m.hChannelIdx == 1, sprintf('hChannelIdx should be 1; got %d', m.hChannelIdx));
    assert(m.mChannelIdx == 2, sprintf('mChannelIdx should be 2; got %d', m.mChannelIdx));
    fprintf('  PASS: bindFromDataset auto-selects H, M\n');
    passed = passed + 1;
catch ex
    fprintf('  FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  EXTRACT + ANALYZE — recovers Hc, Ms from synthetic loop
% ════════════════════════════════════════════════════════════════════
fprintf('\n--- extractHM + analyze recovers Hc, Ms ---\n');
try
    trueHc = 50;  trueMs = 1.0;
    loop = makeLoop(trueHc, trueMs);
    nP = numel(loop.H);
    ds = struct( ...
        'data', struct('time', (1:nP)', ...
                       'values', [loop.H, loop.M], ...
                       'labels', {{'Magnetic Field (Oe)', 'Moment (emu)'}}, ...
                       'units',  {{'Oe', 'emu'}}, ...
                       'metadata', struct()), ...
        'corrData', []);

    m = bosonPlotter.hysteresis.HysteresisWorkshopModel();
    m.bindFromDataset(ds);
    [H, M] = m.extractHM(ds);
    m.analyze(H, M);
    assert(m.hasResult(), 'analyze must populate result');

    r = m.result;
    assert(abs(r.HcMean - trueHc) < 5, ...
        sprintf('Hc=%.2f off from true %d', r.HcMean, trueHc));
    assert(abs(abs(r.MsMean) - trueMs) < 0.05, ...
        sprintf('|Ms|=%.4f off from true %.2f', abs(r.MsMean), trueMs));
    fprintf('  PASS: Hc=%.2f (true %d), Ms=%.4f (true %.2f)\n', ...
        r.HcMean, trueHc, r.MsMean, trueMs);
    passed = passed + 1;
catch ex
    fprintf('  FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  RESULTS TABLE + clipboard text
% ════════════════════════════════════════════════════════════════════
fprintf('\n--- buildResultsTable + buildClipboardText ---\n');
try
    loop = makeLoop(50, 1.0);
    H = loop.H;  M = loop.M;
    m = bosonPlotter.hysteresis.HysteresisWorkshopModel();
    m.analyze(H, M);

    data = m.buildResultsTable();
    assert(size(data, 1) == 12, sprintf('expected 12 rows; got %d', size(data,1)));
    assert(size(data, 2) == 3, 'expected 3 columns');
    assert(strcmp(data{1, 1}, 'Hc (ascending)'), 'first row label');

    txt = m.buildClipboardText();
    assert(contains(txt, 'Hysteresis Loop Analysis'), 'clipboard header');
    assert(contains(txt, sprintf('%s\t', 'Hc (average)')), 'clipboard row');
    fprintf('  PASS: results table %dx%d, clipboard text %d chars\n', ...
        size(data,1), size(data,2), numel(txt));
    passed = passed + 1;
catch ex
    fprintf('  FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  CLEAR — wipes result + warnings
% ════════════════════════════════════════════════════════════════════
fprintf('\n--- clear() wipes result ---\n');
try
    loop = makeLoop(50, 1.0);
    m = bosonPlotter.hysteresis.HysteresisWorkshopModel();
    m.analyze(loop.H, loop.M);
    assert(m.hasResult(), 'has result after analyze');
    m.clear();
    assert(~m.hasResult(), 'no result after clear');
    assert(isempty(m.warnings), 'warnings cleared');
    fprintf('  PASS: clear wipes result + warnings\n');
    passed = passed + 1;
catch ex
    fprintf('  FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  SUBTRACT BG — model toggle changes extracted M
% ════════════════════════════════════════════════════════════════════
fprintf('\n--- subtractBg toggle modifies extractHM output ---\n');
try
    % Build loop with paramagnetic slope baked in: M_total = M_loop + 0.001*H
    loop = makeLoop(50, 1.0);
    Mslope = loop.M + 0.001 * loop.H;
    nP = numel(loop.H);
    ds = struct( ...
        'data', struct('time', (1:nP)', ...
                       'values', [loop.H, Mslope], ...
                       'labels', {{'Field', 'Moment'}}, ...
                       'units',  {{'Oe', 'emu'}}, ...
                       'metadata', struct()), ...
        'corrData', []);

    m = bosonPlotter.hysteresis.HysteresisWorkshopModel();
    m.bindFromDataset(ds);

    % Without BG sub: M extends linearly past saturation
    m.subtractBg = false;
    [~, Mraw] = m.extractHM(ds);

    % With BG sub: linear slope removed
    m.subtractBg = true;
    [~, Mfix] = m.extractHM(ds);

    assert(~isequal(Mraw, Mfix), 'BG sub must change M');
    % After subtraction, high-field tails should be flatter than raw.
    % Use max-min instead of `range()` (Statistics Toolbox).
    tailMaskRaw = abs(loop.H) > 150;
    rawTailRange = max(Mraw(tailMaskRaw)) - min(Mraw(tailMaskRaw));
    fixTailRange = max(Mfix(tailMaskRaw)) - min(Mfix(tailMaskRaw));
    assert(fixTailRange < rawTailRange, ...
        sprintf('BG sub should flatten tails (raw %.4f, fixed %.4f)', ...
            rawTailRange, fixTailRange));
    fprintf('  PASS: BG sub flattens high-field tails (raw range %.3f → %.3f)\n', ...
        rawTailRange, fixTailRange);
    passed = passed + 1;
catch ex
    fprintf('  FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  Summary
% ════════════════════════════════════════════════════════════════════
fprintf('\n=== test_hysteresisWorkshopModel: %d passed, %d failed ===\n', passed, failed);
if failed > 0
    error('test_hysteresisWorkshopModel:failed', '%d test(s) failed', failed);
end
