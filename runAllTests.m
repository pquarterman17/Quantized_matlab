function runAllTests(options)
%RUNALLTESTS  Run the complete test suite and print a summary report.
%
%   Syntax:
%       runAllTests
%       runAllTests(Group="parser")
%
%   Name-Value Options:
%       Group    "all" (default) | "parser" | "batch" | "gui" | "xrd2d" |
%                "sims" | "em" | "emgui" | "eds" | "eels" | "diffindex" |
%                "edsquant" | "eels_adv" | "diff_sim" | "fitting" |
%                "plotting" | "spectral"
%                Run only the specified group of test suites.
%
%   Groups:
%       parser   — core parser smoke tests and edge cases (no GUI, fast)
%       batch    — batch import and XRD converter integration tests
%       xrd2d    — 2D area-detector XRDML parser and edge-case tests
%       gui      — headless GUI API tests (opens/closes figures)
%       sims     — SIMS depth profile parser tests
%       em       — EM image parsers: importTIFF, importRawImage (synthetic data)
%       emgui    — headless FermiViewer API tests (opens/closes figures, slower)
%       eds      — EDS multi-channel composite mode tests
%       eels     — EELS imaging utilities (synthetic data, no files)
%       eels_adv — Advanced EELS: Fourier-log, ELNES, Kramers-Kronig
%       diffindex — diffraction indexing utilities (calcElectronWavelength,
%                   findDiffractionSpots, indexDiffraction)
%       diff_sim  — Diffraction simulation, virtual dark-field, ZAF correction
%       edsquant  — EDS quantification (edsKFactorTable, cliffLorimer,
%                   edsCompositionProfile)
%       interp2d  — 2-D interpolation utilities (interpolate2D, regrid2D)
%       baseline  — baseline estimation: ALS, rolling ball, modified polynomial
%       errorprop — error propagation utilities (errorProp and wrappers)
%       magnetic  — magnetometry: Brillouin model, M(T) bg subtraction,
%                   Curie-Weiss analysis, Stoner-Wohlfarth model
%       templates — dataset template engine (fingerprint, match, apply, save/load)
%       workspace — DataWorkspace model (WorkspaceModel add/remove/mask/undo/events)
%       physics3 — Tier-3 physics: BCS gap, Debye/Einstein, FORC, Kissinger, relaxation
%       all      — all of the above, in order
%
%   Examples:
%       runAllTests                      % full suite
%       runAllTests(Group="parser")      % fast parser checks only
%       runAllTests(Group="gui")         % GUI tests only
%       runAllTests(Group="em")          % EM image parser tests
%       runAllTests(Group="emgui")       % EM Viewer GUI API tests
%       runAllTests(Group="eds")         % EDS composite mode tests
%       runAllTests(Group="eels")        % EELS utilities
%       runAllTests(Group="eels_adv")    % advanced EELS (Fourier-log, ELNES, KK)
%       runAllTests(Group="diffindex")   % diffraction indexing
%       runAllTests(Group="diff_sim")    % diffraction simulation, VDF, ZAF
%       runAllTests(Group="edsquant")    % EDS quantification
%
%   Throws an error if any suite fails so CI/scripts can detect failures.

arguments
    options.Group string = "all"
end

options.Group = validatestring(options.Group, ...
    ["all", "parser", "batch", "xrd2d", "gui", "calcgui", "sims", "em", "emgui", "eds", ...
     "xrayneutron", "superconductor", "cif", "optics", "vacuum", "electrochemistry", ...
     "eels", "eels_adv", "diffindex", "diff_sim", "edsquant", "contour", "fitting", "plotting", ...
     "spectral", "sigproc", "interp2d", "baseline", "errorprop", "utilities", "templates", ...
     "workspace", "transport", "magnetic", "physics3", "bugReport"]);

% Build absolute paths to test scripts so `run` works regardless of CWD.
% Tests are organized into subdirectories: parser/, gui/, imaging/, calc/, batch/
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
    T('parser','test_importBCF'),          'em',     'BCF EDS spectrum parser'
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
    T('gui','test_annotationColorDropdown'),'gui',    'FermiViewer annotation-colour dropdown: items, default, 5-way RGB lookup'
    T('gui','test_contour_features'),       'contour','Contour/heatmap: gridding, plot styles, edge cases, export'
    T('gui','test_diraculator'),            'calcgui','DiraCulator GUI API'
    % ── Imaging tests ─────────────────────────────────────────────────
    T('imaging','test_renderingSharpness'),  'em',     'FermiViewer display pipeline: sharpness/variance preservation regression'
    T('imaging','test_em_parsers'),         'em',     'EM image parsers: importTIFF + importRawImage'
    T('imaging','test_imaging_utils'),      'em',     'Imaging utilities: contrast, filter, FFT, profile, scale bar, thumbnail'
    T('imaging','test_imaging_advanced'),   'em',     'Imaging advanced: bin, unsharp, morph, Otsu, Butterworth, plane level, roughness, lattice, radial, azimuthal, interface fit, stitch, defect count'
    T('imaging','test_tiltCorrection'),     'em',     'SEM/FIB stage tilt: getStageTilt parsing, measureDistance/lineProfile with TiltAngle'
    T('imaging','test_tiltGeometryCorrection'), 'em', 'Tilt geometry: Surface (1/cos) vs Cross-section (1/sin) correction factors'
    T('imaging','test_particle_clahe'),     'em',     'Imaging: CLAHE + connectedComponents + particleAnalysis (synthetic + real DM3/DM4)'
    T('imaging','test_em_gui_harness'),     'emgui',  'EM Viewer GUI API: load, contrast, filter, FFT, profile, export'
    T('imaging','test_em_gui_phase2'),      'emgui',  'EM Viewer GUI Phase 2: stack nav, session, compare, EDS, EELS, diffraction, annotations'
    T('imaging','test_em_measurements'),    'emgui',  'EM Viewer measurement/ROI API: measureDistance, dSpacing, ellipse/polygon ROI, annotRect'
    T('imaging','test_em_contrast_stack'),  'emgui',  'EM Viewer contrast stack API: reset, colormap set/cycle, transform, invert, colorbar'
    T('imaging','test_em_advanced_api'),    'emgui',  'EM Viewer advanced API: virtualDarkField, eelsDeconvolve, eelsKramersKronig (with injected data)'
    T('imaging','test_em_priority3'),       'emgui',  'EM Viewer Priority-3 click-capture bypass: cropRect, zoomRect, resetZoom, fftMask (synthetic + real DM3/DM4)'
    T('imaging','test_em_gui_real_dm'),     'emgui',  'EM Viewer driven by real DM3/DM4 files: per-file load + full button sweep (contrast, filters, FFT, rotate, crop, export, session)'
    T('imaging','test_em_gui_button_wiring'), 'emgui','EM Viewer Processing-panel button wiring: every control present, enabled, callback set, parented to its expected tab'
    T('imaging','test_em_angle_polyline_export'), 'emgui','EM Viewer measurement API: angle (90°/45°/135°), polyline path length, CSV export round-trip'
    T('imaging','test_scaleBarPersistsThroughProcessing'), 'emgui','EM Viewer scale bar: persists across filters, rotate/flip, crop, and undo (regression)'
    T('gui','test_measurementLabelDefaults'), 'emgui','EM Viewer distance label defaults: font size, transparent background, perpendicular offset, tilt tooltip'
    T('imaging','test_transformToolbar'),     'emgui','EM Viewer icon transform toolbar: rotate/flip/zoom/fit/reset/crop wiring + capital-T geometry'
    T('imaging','test_eds_composite'),      'eds',    'EDS multi-channel composite mode API tests'
    T('imaging','test_real_dm3'),           'em',     'Real DM3/TIFF files from +test_datasets/Microscopy'
    T('imaging','test_eels'),              'eels',   'EELS utilities: edge table, background, thickness, ZLP align, extract map'
    T('imaging','test_eels_advanced'),     'eels_adv','EELS advanced: Fourier-log deconvolution, ELNES, Kramers-Kronig'
    T('imaging','test_eelsSVD'),           'eels',   'EELS SVD decomposition: eigenspectra, score maps, denoising'
    T('imaging','test_diffraction_index'), 'diffindex','Diffraction indexing: wavelength, spot finding, phase matching'
    T('imaging','test_diffraction_sim'),   'diff_sim','Diffraction simulation, virtual dark-field, ZAF correction'
    T('imaging','test_eds_quantification'),'edsquant','EDS quantification: k-factor table, Cliff-Lorimer, composition profile'
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
    % ── Plotting tests ───────────────────────────────────────────────────
    T('plotting','test_boxViolinSwarm'),    'plotting', 'Box/violin/swarm plots — objects, KDE, swarm, edge cases'
    T('plotting','test_colorScatterZ'),     'plotting', 'colorScatterZ — scatter, CData, colormaps, colorbar, edge cases'
    T('plotting','test_marginalHistogram'), 'plotting', 'marginalHistogram — axes, scatter, histograms, linked limits, KDE'
    T('plotting','test_groupedPlot'),       'plotting', 'groupedPlot — line/scatter/bar/box, legend, numeric groups, error bars'
    T('plotting','test_ternaryPlot'),       'plotting', 'ternaryPlot — three-component compositions on equilateral triangle (phase diagrams, alloy maps)'
    T('plotting','test_polarContour'),      'plotting', 'polarContour — filled-contour intensity maps on polar coordinates (XRD pole figures, texture plots)'
    T('plotting','test_axisBreak'),         'plotting', 'axisBreak — split Y/X axis with zigzag/slash/gap break marks, remove() restore'
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
    T('workspace','test_tableWidget'),     'workspace','createTableWidget: version-branched uispreadsheet/uitable factory'
    T('workspace','test_formulaEngine'),   'workspace','FormulaEngine: tokenize, RPN, evaluate, hasCircularRef, WorkspaceModel integration'
    % ── Bug-report tests ─────────────────────────────────────────────────
    T('bugReport','test_reportBug'),       'bugReport','Bug report: buildReport, formatReportMarkdown, URL encoding'
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
