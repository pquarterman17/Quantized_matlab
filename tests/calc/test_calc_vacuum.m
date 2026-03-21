%TEST_CALC_VACUUM  Tests for the +calc/+vacuum/ package.
%   run tests/test_calc_vacuum
%   runAllTests(Group="vacuum")
clear; clc;
fprintf('\n=== Vacuum Module Tests ===\n\n');
ROOT = fileparts(fileparts(fileparts(mfilename('fullpath')))); addpath(ROOT);
passed = 0; failed = 0;

% Mean free path at 1e-4 Pa (~ UHV)
try
    r = calc.vacuum.meanFreePath(1e-4);
    assert(r.mfp > 10, 'MFP at UHV should be > 10 m');
    fprintf('  PASS: MFP(1e-4 Pa) = %.1f m\n', r.mfp); passed = passed + 1;
catch ME, fprintf('  FAIL: meanFreePath — %s\n', ME.message); failed = failed + 1;
end

% Knudsen number
try
    r = calc.vacuum.knudsenNumber(100, 0.1);  % 100m MFP, 10cm chamber
    assert(r.Kn > 1 && strcmp(r.regime, 'molecular'), 'Should be molecular flow');
    fprintf('  PASS: Kn = %.1f (%s)\n', r.Kn, r.regime); passed = passed + 1;
catch ME, fprintf('  FAIL: knudsenNumber — %s\n', ME.message); failed = failed + 1;
end

% Monolayer time at ~1e-6 Torr ≈ 1.33e-4 Pa → ~1 s
try
    r = calc.vacuum.monolayerTime(1.33e-4);
    assert(r.tMono > 0.1 && r.tMono < 10, 'Monolayer time at 1e-6 Torr ~1s');
    fprintf('  PASS: tMono(1e-6 Torr) = %.2f s\n', r.tMono); passed = passed + 1;
catch ME, fprintf('  FAIL: monolayerTime — %s\n', ME.message); failed = failed + 1;
end

% Sputter yield: Si/Ar at 500 eV ≈ 0.9
try
    r = calc.vacuum.sputterYield('Si', 500, ion='Ar');
    assert(abs(r.Y - 0.9) < 0.3, 'Si/Ar 500eV yield ~0.9');
    fprintf('  PASS: Y(Si/Ar/500eV) = %.2f\n', r.Y); passed = passed + 1;
catch ME, fprintf('  FAIL: sputterYield — %s\n', ME.message); failed = failed + 1;
end

% Pump-down time
try
    r = calc.vacuum.pumpDownTime(50, 100, 1e5, 1e-4);
    assert(r.time > 0 && r.tau > 0, 'Valid pump-down');
    fprintf('  PASS: pump-down = %.1f s (%.1f min)\n', r.time, r.timeMin); passed = passed + 1;
catch ME, fprintf('  FAIL: pumpDownTime — %s\n', ME.message); failed = failed + 1;
end

% Gas flow conductance
try
    r = calc.vacuum.gasFlow(100, 1, 0.025, 1.0);
    assert(r.Cmol > 0 && r.Cvisc > 0, 'Both regimes computed');
    fprintf('  PASS: C_mol=%.2f L/s, C_visc=%.2f L/s\n', r.Cmol, r.Cvisc); passed = passed + 1;
catch ME, fprintf('  FAIL: gasFlow — %s\n', ME.message); failed = failed + 1;
end

fprintf('\n=== Results: %d passed, %d failed ===\n', passed, failed);
if failed > 0, error('test_calc_vacuum:failures', '%d FAILED', failed); end
