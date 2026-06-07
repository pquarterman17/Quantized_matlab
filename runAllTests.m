function runAllTests(options)
%RUNALLTESTS  Run the complete test suite and print a summary report.
%
%   Syntax:
%       runAllTests
%       runAllTests(Group="parser")
%
%   Name-Value Options:
%       Group    "all" (default) | "parser" | "batch" | "gui" | "xrd2d" |
%                "sims" | "fitting" | "plotting"
%                Run only the specified group of test suites.
%
%   Note: EM-related groups (em, emgui, eds, eels, eels_adv, diffindex,
%   diff_sim, edsquant, contour, spectral) moved to fermi-viewer:
%   https://github.com/pquarterman17/fermi-viewer
%
%   Groups:
%       parser   — core parser smoke tests and edge cases (no GUI, fast)
%       batch    — batch import and XRD converter integration tests
%       xrd2d    — 2D area-detector XRDML parser and edge-case tests
%       gui      — headless GUI API tests (opens/closes figures)
%       sims     — SIMS depth profile parser tests
%       interp2d  — 2-D interpolation utilities (interpolate2D, regrid2D)
%       baseline  — baseline estimation: ALS, rolling ball, modified polynomial
%       errorprop — error propagation utilities (errorProp and wrappers)
%       magnetic  — magnetometry: Brillouin model, M(T) bg subtraction,
%                   Curie-Weiss analysis, Stoner-Wohlfarth model
%       templates — dataset template engine (fingerprint, match, apply, save/load)
%       workspace — DataWorkspace model (WorkspaceModel add/remove/mask/undo/events)
%       physics3 — Tier-3 physics: BCS gap, Debye/Einstein, FORC, Kissinger, relaxation
%       smoke    — full interaction sequences: fire every button, capture screenshots
%       app      — app-level infrastructure: path shadows, headless detection
%       all      — all of the above, in order
%
%   Examples:
%       runAllTests                      % full suite
%       runAllTests(Group="parser")      % fast parser checks only
%       runAllTests(Group="gui")         % GUI tests only
%
%   Throws an error if any suite fails so CI/scripts can detect failures.

arguments
    options.Group string = "all"
end

options.Group = validatestring(options.Group, ...
    ["all", "parser", "batch", "xrd2d", "gui", "calcgui", "sims", ...
     "xrayneutron", "superconductor", "cif", "optics", "vacuum", "electrochemistry", ...
     "fitting", "plotting", "sigproc", "interp2d", "baseline", "errorprop", ...
     "utilities", "templates", "workspace", "transport", "magnetic", "physics3", ...
     "bugReport", "smoke", "app"]);

% Build absolute paths to test scripts so `run` works regardless of CWD.
% Tests are organized into subdirectories: parser/, gui/, calc/, batch/, fitting/
ROOT  = fileparts(mfilename('fullpath'));
T     = @(subdir, name) fullfile(ROOT, 'tests', subdir, name);

SUITES = {
    % absolute path                                  group              description
    % ── Parser tests ──────────────────────────────────────────────────
    T('parser','test_parsers'),             'parser', 'Parser smoke tests (all formats)'
    T('parser','test_importAuto'),          'parser', 'importAuto dispatch'
    T('parser','test_parsers_edge_cases'),  'parser', 'Parser edge cases / error handling'
    T('parser','test_data_roundtrip'),      'parser', 'CSV export round-trip'
    T('parser','test_csv_mixed_format'),    'parser', 'CSV mixed/awkward format handling'
    T('parser','test_new_features'),        'parser', 'Features 4-16: utilities and parser changes'
    T('parser','test_importAFM'),          'parser', 'AFM / NanoScope .spm parser'
    T('parser','test_sims_parser'),         'sims',   'SIMS depth profile parser'
    T('parser','test_xrdml_2d'),            'xrd2d',  '2D XRDML parser (parser + Q-space)'
    T('parser','test_xrdml_2d_edge'),       'xrd2d',  '2D XRDML edge cases (shapes, cuts, session)'
    % ── Batch tests ───────────────────────────────────────────────────
    T('batch','test_batch_processing'),     'batch',  'batchImport + batchConvertXRD'
    T('batch','test_batch_xrd_converter'),  'batch',  'XRD converter GUI edge cases'
    T('batch','test_batchPlot'),            'batch',  'batchPlot: templates, formats, overwrite, prefix/suffix'
    T('batch','test_generateReport'),       'batch',  'generateReport: HTML/txt output, stats, custom sections'
    T('batch','test_dataConnector'),        'batch',  'dataConnector: file watcher, callback, stop, AutoStart'
    % ── GUI tests ─────────────────────────────────────────────────────
    T('gui','test_gui_harness'),            'gui',    'GUI API: load, correct, peaks, session'
    T('gui','test_gui_2d'),                 'gui',    'GUI API: 2D map load, plot types, cuts'
    T('gui','test_gui_phase4'),             'gui',    'GUI API: Q-space, colormap, mixed datasets'
    T('gui','test_gui_buttons'),            'gui',    'GUI buttons: dataset mgmt, plot controls, corrections, toolbar, macros'
    T('gui','test_actionlog_replay'),       'gui',    'actionLog replay (W3 #14): serializeArg, recordCall, exportScript(fig, path)'
    T('gui','test_dataset_provenance'),     'gui',    'Dataset provenance log (W3 #15): appendHistory, getHistoryScript, exportHistoryScript, formatHistory + BosonPlotter import/correction hooks'
    T('gui','test_toolbarConfig'),          'gui',    'Toolbar customisation: defaults, buildToolbar, save/load, stale IDs'
    T('gui','test_undoManager'),            'gui',    'UndoManager: push, undo, redo, branch discard, cap, clear, labels'
    T('gui','test_filterRows'),             'gui',    'filterRows: expression parser, operators, functions, edge cases'
    T('gui','test_spreadsheetPopup'),       'gui',    'Spreadsheet popup: open, widget, stats, export, ReadOnly, sort, edit'
    T('gui','test_dragToPlot'),             'gui',    'Drag-column-to-plot: AppState props, setChannelFromDrag API, no-ops'
    T('gui','test_styleResolution'),        'gui',    'Style resolution: template/global/ds/channel precedence chain + user templates'
    T('gui','test_renderPlot_styling'),     'gui',    'renderPlot styling: live template switches apply FontName/Size/LineWidth/TickDir to axes'
    T('gui','test_layoutIntegrity'),        'gui',    'Layout integrity: walk uigridlayout tree + flag clipped / zero-size / undersized nested grids'
    T('gui','test_bosonPlotterSize'),       'gui',    'Size ratchet: BosonPlotter.m line count + nested-fn count stay under their ceilings (see W5 #22)'
    T('gui','test_magUnitConversion'),      'gui',    'Mag unit conversion: Oe→T live dropdown change + ds.data preservation + missing-mass warn'
    T('gui','test_plotStyleDialog'),        'gui',    'Plot Style dialog (Phase B) + session round-trip (Phase C): overrides, precedence, reset, save/load'
    T('gui','test_sessionRoundtripWorkspace'), 'gui', 'Session round-trip: WorkspaceModel mask + computed columns + column roles survive save/load (MASTERPLAN W3 #10)'
    T('gui','test_rowLevelMasking'),        'gui',    'Row-level masking: no mask column, context menu, soft-red row style'
    T('gui','test_plotInteractions'),       'gui',    'Plot interactions: double-click labels, context menus on traces, cursor panel readout'
    T('gui','test_insetGraph'),             'gui',    'Inset graph: create, region limits, rect/connectors, remove, replacement, Position option'
    T('gui','test_2dMapStyling'),           'gui',    '2D heatmap axes pick up active template font/tick (Phase F)'
    T('gui','test_reflSplineMode'),         'gui',    'reflFitting Spline mode: reflBuildSplineLayers helper + headless dialog smoke test (MASTERPLAN W3 #11 GUI)'
    T('gui','test_themeConformance'),       'gui',    'Theme conformance: every widget BG/FG comes from uxTokens palette in both dark and light'
    T('gui','test_resolveTheme'),           'gui',    'resolveTheme: Auto-mode resolution + Dark/Light passthrough (themePref Auto support)'
    T('gui','test_noNewColorLiterals'),     'gui',    'Static linter: no new hardcoded RGB literals in BosonPlotter.m / +bosonPlotter/ above the baseline ratchet'
    T('gui','test_headlessHelpers'),        'gui',    'Headless helpers: isHeadless, resolveVisible, quietAlert, quietConfirm — env-var logic + log format'
    T('gui','test_contour_features'),       'contour','Contour/heatmap: gridding, plot styles, edge cases, export'
    T('gui','test_diraculator'),            'calcgui','DiraCulator GUI API'
    % ── Imaging tests ─────────────────────────────────────────────────
    % ── Calc tests ────────────────────────────────────────────────────
    T('calc','test_calc_xrayneutron'),     'xrayneutron', 'X-ray/Neutron calculation module'
    T('calc','test_superconductor'),       'superconductor', 'Superconductor calculation module'
    T('calc','test_cif_parser'),           'cif',    'CIF parser and crystal cache'
    T('calc','test_calc_optics'),          'optics', 'Optics module: Fresnel, angles, depths'
    T('calc','test_calc_vacuum'),          'vacuum', 'Vacuum module: MFP, sputter yield, pump-down'
    T('calc','test_calc_electrochemistry'),'electrochemistry', 'Electrochemistry: Nernst, BV, Tafel'
    T('calc','test_transport_analysis'),  'transport', 'VFT model, Hall analysis, Wiedemann-Franz'
    T('calc','test_magnetic_analysis'),   'magnetic', 'Magnetic analysis: Brillouin, M(T) bg, Curie-Weiss, Stoner-Wohlfarth'
    T('calc','test_physics_tier3'),       'physics3', 'Physics Tier-3: BCS gap, Debye/Einstein, FORC, Kissinger, relaxation'
    % ── Fitting tests ────────────────────────────────────────────────────
    T('fitting','test_peak_detection'),   'fitting', 'Robust peak detection, background estimation, prominence'
    T('fitting','test_peakWorkshopModel'),'fitting', 'PeakWorkshopModel handle class — detect/fit/manual/remove in isolation'
    T('fitting','test_hysteresisWorkshopModel'),'fitting', 'HysteresisWorkshopModel handle class — extractHM/analyze/results in isolation'
    T('fitting','test_curveFitWorkshopModel'),'fitting', 'CurveFitWorkshopModel handle class — selectModel/autoGuess/fit/custom in isolation'
    T('fitting','test_reflWorkshopModel'),'fitting', 'ReflWorkshopModel handle class — simulate/addLayer/addKnot in isolation'
    T('fitting','test_figureBuilderModel'),'fitting', 'FigureBuilderModel handle class — multi-panel config + generate in isolation'
    T('fitting','test_curve_fitting'),    'fitting', 'Curve fitting engine, models, autoGuess, parseEquation'
    T('fitting','test_constraints_batchfit'), 'fitting', 'Parameter constraints + batch fit dialog'
    T('fitting','test_templates_fft'),   'fitting', 'Publication templates and FFT filtering'
    T('fitting','test_resample_stats'),  'fitting', 'Resampling, descriptive stats, t-test, linear regression'
    T('fitting','test_batch_roi'),       'fitting', 'Batch fitting, peak tracking'
    T('fitting','test_multipanel'),      'fitting', 'Multi-panel figure builder'
    T('fitting','test_phase8_qol'),      'fitting', 'Phase 8: composer, action log, 3D surface, dataset groups'
    T('fitting','test_reflectivity'),    'fitting', 'Parratt reflectivity, SLD profile, material presets'
    T('fitting','test_hysteresis'),     'fitting', 'Hysteresis loop analysis: Hc, Mr, Ms, SFD, models'
    T('fitting','test_polar'),          'fitting', 'Polar plots for angular-dependent measurements'
    T('fitting','test_globalfit'),       'fitting', 'Global/shared-parameter fitting (sharedMask API)'
    T('fitting','test_globalCurveFit'), 'fitting', 'Constraint-based global fitting (globalCurveFit)'
    T('fitting','test_fitBands'),           'fitting', 'Confidence and prediction bands (fitBands)'
    T('fitting','test_residualDiagnostics'), 'fitting', 'Residual diagnostics: Q-Q, DW, runs test, skewness'
    T('fitting','test_fitCompare'),          'fitting', 'Model comparison metrics: AIC, BIC, adjR2, F-test'
    T('fitting','test_surfaceFit'),          'fitting', 'Surface/3D fitting: models, autoGuess, surfaceFit engine'
    T('fitting','test_rsmAnalyze'),          'fitting', 'RSM decomposition: rsmAnalyze finds substrate/film peaks in 2D maps; rsmStrain computes ε∥, ε⊥, and relaxation (MASTERPLAN W3 #12)'
    T('fitting','test_odrFit'),              'fitting', 'Orthogonal distance regression (Deming): closed-form slope, jackknife errors, λ dependence, ODR-vs-OLS on symmetric noise'
    T('fitting','test_anovaPca'),            'fitting', 'One-way ANOVA and PCA (SVD-based): F-distribution p-values, explained variance, orthonormal loadings'
    T('fitting','test_cursor_anchor'),       'fitting', 'Cursor fit region + anchor spline background (pure-computation layer)'
    T('fitting','test_mcmcSample'),          'fitting', 'MCMC sampler scaffold (random-walk Metropolis; affine-invariant ensemble TODO)'
    T('fitting','test_pawleyRefine'),        'fitting', 'Pawley whole-pattern XRD refinement scaffold (grid-search cell; Levenberg-Marquardt TODO)'
    T('fitting','test_tchPseudoVoigt'),      'fitting', 'TCH Thompson-Cox-Hastings pseudo-Voigt profile (Rietveld-style)'
    T('fitting','test_peakLinkedParams'),    'fitting', 'Multi-peak linked parameter packer: Shared FWHM, Shared FWHM + eta'
    T('fitting','test_splineSLD'),           'fitting', 'Free-form spline SLD profile + microslicing helper for parrattRefl (MASTERPLAN W3 #11)'
    % ── Plotting tests ───────────────────────────────────────────────────
    T('plotting','test_boxViolinSwarm'),    'plotting', 'Box/violin/swarm plots — objects, KDE, swarm, edge cases'
    T('plotting','test_colorScatterZ'),     'plotting', 'colorScatterZ — scatter, CData, colormaps, colorbar, edge cases'
    T('plotting','test_marginalHistogram'), 'plotting', 'marginalHistogram — axes, scatter, histograms, linked limits, KDE'
    T('plotting','test_groupedPlot'),       'plotting', 'groupedPlot — line/scatter/bar/box, legend, numeric groups, error bars'
    T('plotting','test_ternaryPlot'),       'plotting', 'ternaryPlot — three-component compositions on equilateral triangle (phase diagrams, alloy maps)'
    T('plotting','test_polarContour'),      'plotting', 'polarContour — filled-contour intensity maps on polar coordinates (XRD pole figures, texture plots)'
    T('plotting','test_axisBreak'),         'plotting', 'axisBreak — split Y/X axis with zigzag/slash/gap break marks, remove() restore'
    T('plotting','test_densityPlot'),       'plotting', 'densityPlot — 2D density heatmap (W3 #16): bin sizing, edges, log compression, smoothing, non-finite filter, colormap delegation'
    % ── Spectral tests ───────────────────────────────────────────────────
    T('calc','test_fftSpectral'),          'spectral','FFT spectral analysis, windows, Welch PSD, cross-correlation'
    % ── Signal processing tests ──────────────────────────────────────────
    T('calc','test_signal_processing'),   'sigproc', 'Signal processing: FFT filter (LP/HP/BP/notch) + smoothing roundtrips'
    % ── Interpolation 2-D tests ──────────────────────────────────────────
    T('calc','test_interpolate2D'),        'interp2d','2-D interpolation: linear, natural, TPS, IDW, regrid2D'
    % ── Baseline tests ───────────────────────────────────────────────────
    T('calc','test_baselines'),            'baseline','Baseline estimation: ALS, rolling ball, modified polynomial'
    % ── Error propagation tests ──────────────────────────────────────────
    T('calc','test_errorProp'),            'errorprop','Error propagation: linear Taylor, Monte Carlo, wrappers'
    % ── Signal processing tests ──────────────────────────────────────────
    T('calc','test_signal_processing'),   'sigproc', 'Signal processing: FFT filter (LP/HP/BP/notch) + smoothing roundtrips'
    % ── Utilities tests ──────────────────────────────────────────────────
    T('utilities','test_toOrigin'),        'utilities','Origin COM bridge: call sequence, qualified path, log handling (mock COM)'
    T('utilities','test_convertMagUnits'), 'utilities','Magnetometry unit conversion: Oe/T/mT/A/m, emu/A·m²/emu·g⁻¹/kA·m⁻¹, raw-preserve'
    % ── Template tests ───────────────────────────────────────────────────
    T('templates','test_templateEngine'),  'templates','Template engine: fingerprint, match cascade, apply, save/load/delete round-trip'
    % ── Workspace tests ──────────────────────────────────────────────────
    T('workspace','test_workspaceModel'),  'workspace','WorkspaceModel: add/remove/mask/undo/event firing'
    T('workspace','test_syncMasksFromModel'), 'workspace','syncMasksFromModel: model→appData mask flow (DataWorkspace ↔ BosonPlotter sync)'
    T('workspace','test_tableWidget'),     'workspace','createTableWidget: version-branched uispreadsheet/uitable factory'
    T('workspace','test_formulaEngine'),   'workspace','FormulaEngine: tokenize, RPN, evaluate, hasCircularRef, WorkspaceModel integration'
    % ── App / infrastructure tests ──────────────────────────────────────
    T('app','test_uialert_shadow'),        'app',      'Path-shadow: uialert/uiconfirm intercepted in headless, delegated in normal mode'
    % ── Bug-report tests ─────────────────────────────────────────────────
    T('bugReport','test_reportBug'),       'bugReport','Bug report: buildReport, formatReportMarkdown, URL encoding'
    % ── Smoke tests (full interaction sequences) ──────────────────────
    T('smoke','test_smokeRunner'),           'smoke',  'SmokeRunner framework self-test: widget lookup, callback invocation, snapshots, sequences'
    T('smoke','test_bp_smoke'),             'smoke',  'BosonPlotter smoke: fire every button + interaction sequences with real data'
    T('smoke','test_string_snapshots'),     'smoke',  'String snapshots: button labels, tooltips match expected values (catch refactoring regressions)'
};

% Filter by group
if ~strcmp(options.Group, "all")
    mask   = strcmp(SUITES(:,2), char(options.Group));
    SUITES = SUITES(mask, :);
end

nSuites = size(SUITES, 1);
if nSuites == 0
    fprintf('No suites match group "%s".\n', options.Group);
    return;
end

% ── Run each suite ────────────────────────────────────────────────────
passed  = false(1, nSuites);
msgs    = cell(1,  nSuites);
elapsed = zeros(1, nSuites);

sep = repmat(char(9552), 1, 68);
fprintf('\n%s\n', sep);
fprintf('  runAllTests — %d suite(s)  [group: %s]\n', nSuites, options.Group);
fprintf('%s\n', sep);

testsRoot = fullfile(ROOT, 'tests');
for k = 1:nSuites
    abspath = SUITES{k,1};
    relpath = strrep(abspath, [testsRoot filesep], '');
    desc = SUITES{k,3};
    fprintf('\n  ▶  tests/%s\n     %s\n', relpath, desc);
    t0 = tic;
    [passed(k), msgs{k}] = runSuite(abspath);
    elapsed(k) = toc(t0);
    if passed(k)
        fprintf('     ✔  PASS  (%.1f s)\n', elapsed(k));
    else
        fprintf('     ✘  FAIL  (%.1f s)\n', elapsed(k));
        fprintf('        %s\n', msgs{k});
    end
end

% ── Summary ───────────────────────────────────────────────────────────
nPass = sum(passed);
nFail = nSuites - nPass;

fprintf('\n%s\n', sep);
fprintf('  SUMMARY: %d / %d suites passed  (%.1f s total)\n', ...
    nPass, nSuites, sum(elapsed));
fprintf('%s\n', sep);

if nFail > 0
    fprintf('\n  Failed suites:\n');
    for k = find(~passed)
        relpath = strrep(SUITES{k,1}, [testsRoot filesep], '');
        fprintf('    ✘  tests/%s\n', relpath);
    end
    fprintf('\n');
    error('runAllTests:failures', '%d suite(s) failed.', nFail);
else
    fprintf('\n  All suites PASSED.\n\n');
end

end % runAllTests


% ── Local helper — runs one suite in its own isolated workspace ────────
function [ok, msg] = runSuite(suitePath)
%RUNSUITE  Execute a test script and return pass/fail.
%   The test script runs in this function's workspace, so its `clear`
%   only affects local variables here — the caller's state is untouched.
%   `ok` and `msg` are assigned after `run` returns, so they survive
%   any `clear` that the test script issues at startup.
    try
        run(suitePath);
        ok  = true;
        msg = '';
    catch ME
        ok  = false;
        msg = ME.message;
    end
end
