%TEST_CALC_OPTICS  Tests for the +calc/+optics/ package.
%   run tests/test_calc_optics
%   runAllTests(Group="optics")
clear; clc;
fprintf('\n=== Optics Module Tests ===\n\n');
ROOT = fileparts(fileparts(mfilename('fullpath'))); addpath(ROOT);
passed = 0; failed = 0;

% Fresnel at normal incidence: glass (n=1.5)
try
    r = calc.optics.fresnelCoefficients(1.0, 1.5, 0);
    % Rs = ((1-1.5)/(1+1.5))^2 = 0.04
    assert(abs(r.Rs - 0.04) < 0.005, 'Rs at normal incidence');
    assert(abs(r.Rs - r.Rp) < 0.005, 'Rs = Rp at normal incidence');
    fprintf('  PASS: Fresnel normal incidence Rs=%.4f\n', r.Rs); passed = passed + 1;
catch ME, fprintf('  FAIL: Fresnel — %s\n', ME.message); failed = failed + 1;
end

% Critical angle: glass to air (n1=1.5, n2=1.0)
try
    r = calc.optics.criticalAngle(1.5, 1.0);
    assert(abs(r.thetaC - asind(1/1.5)) < 0.1, 'Critical angle for glass/air');
    fprintf('  PASS: criticalAngle = %.2f deg\n', r.thetaC); passed = passed + 1;
catch ME, fprintf('  FAIL: criticalAngle — %s\n', ME.message); failed = failed + 1;
end

% No critical angle when n2 > n1
try
    r = calc.optics.criticalAngle(1.0, 1.5);
    assert(isnan(r.thetaC), 'Should be NaN when n2 > n1');
    fprintf('  PASS: criticalAngle NaN when n2>n1\n'); passed = passed + 1;
catch ME, fprintf('  FAIL: criticalAngle NaN — %s\n', ME.message); failed = failed + 1;
end

% Brewster angle: n1=1, n2=1.5 → ~56.3°
try
    r = calc.optics.brewsterAngle(1.0, 1.5);
    assert(abs(r.thetaB - atand(1.5)) < 0.1, 'Brewster angle');
    fprintf('  PASS: brewsterAngle = %.2f deg\n', r.thetaB); passed = passed + 1;
catch ME, fprintf('  FAIL: brewsterAngle — %s\n', ME.message); failed = failed + 1;
end

% Refractive ↔ Dielectric round-trip
try
    r1 = calc.optics.refractiveToDielectric(1.5, 0.01);
    r2 = calc.optics.dielectricToRefractive(r1.eps1, r1.eps2);
    assert(abs(r2.n - 1.5) < 0.001 && abs(r2.k - 0.01) < 0.001, 'Round-trip');
    fprintf('  PASS: n,k round-trip\n'); passed = passed + 1;
catch ME, fprintf('  FAIL: refractive round-trip — %s\n', ME.message); failed = failed + 1;
end

% Penetration depth
try
    r = calc.optics.penetrationDepth(1.0, 0.001, 1.5406);
    assert(r.depth > 0 && isfield(r, 'latex'), 'Penetration depth');
    fprintf('  PASS: penetrationDepth = %.4g\n', r.depth); passed = passed + 1;
catch ME, fprintf('  FAIL: penetrationDepth — %s\n', ME.message); failed = failed + 1;
end

% Skin depth: Cu at 1 GHz
try
    r = calc.optics.skinDepth(1.7e-8, 1e9);
    % ~2 um for Cu at 1 GHz
    assert(r.deltaUm > 1 && r.deltaUm < 5, 'Cu skin depth at 1 GHz');
    fprintf('  PASS: skinDepth(Cu, 1GHz) = %.2f um\n', r.deltaUm); passed = passed + 1;
catch ME, fprintf('  FAIL: skinDepth — %s\n', ME.message); failed = failed + 1;
end

fprintf('\n=== Results: %d passed, %d failed ===\n', passed, failed);
if failed > 0, error('test_calc_optics:failures', '%d FAILED', failed); end
