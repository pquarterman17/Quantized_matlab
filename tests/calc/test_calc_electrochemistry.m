%TEST_CALC_ELECTROCHEMISTRY  Tests for +calc/+electrochemistry/.
%   run tests/test_calc_electrochemistry
%   runAllTests(Group="electrochemistry")
clear; clc;
fprintf('\n=== Electrochemistry Module Tests ===\n\n');
ROOT = fileparts(fileparts(fileparts(mfilename('fullpath')))); addpath(ROOT);
passed = 0; failed = 0;

% Nernst: standard potential with Q=1 → E=E0
try
    r = calc.electrochemistry.nernstPotential(0.77, 1, 1.0);
    assert(abs(r.E - 0.77) < 0.001, 'E=E0 when Q=1');
    fprintf('  PASS: Nernst(Q=1) = %.4f V\n', r.E); passed = passed + 1;
catch ME, fprintf('  FAIL: nernstPotential — %s\n', ME.message); failed = failed + 1;
end

% Nernst: shift with Q=0.01
try
    r = calc.electrochemistry.nernstPotential(0.77, 1, 0.01);
    assert(r.E > 0.77, 'E > E0 when Q < 1');
    fprintf('  PASS: Nernst(Q=0.01) = %.4f V\n', r.E); passed = passed + 1;
catch ME, fprintf('  FAIL: nernstPotential Q<1 — %s\n', ME.message); failed = failed + 1;
end

% Butler-Volmer: zero overpotential → j=0
try
    r = calc.electrochemistry.butlerVolmer(1e-3, 0);
    assert(abs(r.j) < 1e-10, 'j=0 at eta=0');
    fprintf('  PASS: BV(eta=0) = %.2e\n', r.j); passed = passed + 1;
catch ME, fprintf('  FAIL: butlerVolmer eta=0 — %s\n', ME.message); failed = failed + 1;
end

% Butler-Volmer: positive overpotential → positive current
try
    r = calc.electrochemistry.butlerVolmer(1e-3, 0.1);
    assert(r.j > 0, 'j > 0 for positive eta');
    fprintf('  PASS: BV(eta=0.1) = %.4g A/cm2\n', r.j); passed = passed + 1;
catch ME, fprintf('  FAIL: butlerVolmer — %s\n', ME.message); failed = failed + 1;
end

% Tafel slope: alpha=0.5, T=298.15 → ~118 mV/decade
try
    r = calc.electrochemistry.tafelSlope(0.5, T=298.15);
    assert(abs(r.bMv - 118.3) < 2, 'Tafel slope ~118 mV/dec');
    fprintf('  PASS: Tafel slope = %.1f mV/dec\n', r.bMv); passed = passed + 1;
catch ME, fprintf('  FAIL: tafelSlope — %s\n', ME.message); failed = failed + 1;
end

% Double layer capacitance
try
    r = calc.electrochemistry.doubleLayerCapacitance(78, 0.5, 1.0);
    assert(r.CuF > 0 && isfield(r, 'latex'), 'Valid capacitance');
    fprintf('  PASS: DLC = %.2f uF\n', r.CuF); passed = passed + 1;
catch ME, fprintf('  FAIL: doubleLayerCapacitance — %s\n', ME.message); failed = failed + 1;
end

% Ohmic drop
try
    r = calc.electrochemistry.ohmicDrop(0.01, 10);
    assert(abs(r.V - 0.1) < 1e-6, 'IR = 0.01*10 = 0.1 V');
    fprintf('  PASS: IR drop = %.3f V\n', r.V); passed = passed + 1;
catch ME, fprintf('  FAIL: ohmicDrop — %s\n', ME.message); failed = failed + 1;
end

fprintf('\n=== Results: %d passed, %d failed ===\n', passed, failed);
if failed > 0, error('test_calc_electrochemistry:failures', '%d FAILED', failed); end
