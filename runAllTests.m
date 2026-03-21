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
%                "edsquant" | "eels_adv" | "diff_sim" | "fitting"
%                Run only the specified group of test suites.
%
%   Groups:
%       parser   — core parser smoke tests and edge cases (no GUI, fast)
%       batch    — batch import and XRD converter integration tests
%       xrd2d    — 2D area-detector XRDML parser and edge-case tests
%       gui      — headless GUI API tests (opens/closes figures)
%       sims     — SIMS depth profile parser tests
%       em       — EM image parsers: importTIFF, importRawImage (synthetic data)
%       emgui    — headless emViewerGUI API tests (opens/closes figures, slower)
%       eds      — EDS multi-channel composite mode tests
%       eels     — EELS imaging utilities (synthetic data, no files)
%       eels_adv — Advanced EELS: Fourier-log, ELNES, Kramers-Kronig
%       diffindex — diffraction indexing utilities (calcElectronWavelength,
%                   findDiffractionSpots, indexDiffraction)
%       diff_sim — Diffraction simulation, virtual dark-field, ZAF correction
%       edsquant — EDS quantification (edsKFactorTable, cliffLorimer,
%                  edsCompositionProfile)
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
     "eels", "eels_adv", "diffindex", "diff_sim", "edsquant", "contour", "fitting"]);

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
    T('parser','test_sims_parser'),         'sims',   'SIMS depth profile parser'
    T('parser','test_xrdml_2d'),            'xrd2d',  '2D XRDML parser (parser + Q-space)'
    T('parser','test_xrdml_2d_edge'),       'xrd2d',  '2D XRDML edge cases (shapes, cuts, session)'
    % ── Batch tests ───────────────────────────────────────────────────
    T('batch','test_batch_processing'),     'batch',  'batchImport + batchConvertXRD'
    T('batch','test_batch_xrd_converter'),  'batch',  'XRD converter GUI edge cases'
    % ── GUI tests ─────────────────────────────────────────────────────
    T('gui','test_gui_harness'),            'gui',    'GUI API: load, correct, peaks, session'
    T('gui','test_gui_2d'),                 'gui',    'GUI API: 2D map load, plot types, cuts'
    T('gui','test_gui_phase4'),             'gui',    'GUI API: Q-space, colormap, mixed datasets'
    T('gui','test_contour_features'),       'contour','Contour/heatmap: gridding, plot styles, edge cases, export'
    T('gui','test_materials_calc_gui'),     'calcgui','Materials calculator GUI API'
    % ── Imaging tests ─────────────────────────────────────────────────
    T('imaging','test_em_parsers'),         'em',     'EM image parsers: importTIFF + importRawImage'
    T('imaging','test_imaging_utils'),      'em',     'Imaging utilities: contrast, filter, FFT, profile, scale bar, thumbnail'
    T('imaging','test_em_gui_harness'),     'emgui',  'EM Viewer GUI API: load, contrast, filter, FFT, profile, export'
    T('imaging','test_eds_composite'),      'eds',    'EDS multi-channel composite mode API tests'
    T('imaging','test_real_dm3'),           'em',     'Real DM3/TIFF files from +test_datasets/Microscopy'
    T('imaging','test_eels'),              'eels',   'EELS utilities: edge table, background, thickness, ZLP align, extract map'
    T('imaging','test_eels_advanced'),     'eels_adv','EELS advanced: Fourier-log deconvolution, ELNES, Kramers-Kronig'
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
    % ── Fitting tests ────────────────────────────────────────────────────
    T('fitting','test_curve_fitting'),    'fitting', 'Curve fitting engine, models, autoGuess, parseEquation'
    T('fitting','test_templates_fft'),   'fitting', 'Publication templates and FFT filtering'
    T('fitting','test_resample_stats'),  'fitting', 'Resampling, descriptive stats, t-test, linear regression'
    T('fitting','test_batch_roi'),       'fitting', 'Batch fitting, peak tracking'
    T('fitting','test_multipanel'),      'fitting', 'Multi-panel figure builder'
    T('fitting','test_phase8_qol'),      'fitting', 'Phase 8: composer, action log, 3D surface, dataset groups'
    T('fitting','test_reflectivity'),    'fitting', 'Parratt reflectivity, SLD profile, material presets'
    T('fitting','test_hysteresis'),     'fitting', 'Hysteresis loop analysis: Hc, Mr, Ms, SFD, models'
    T('fitting','test_polar'),          'fitting', 'Polar plots for angular-dependent measurements'
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
