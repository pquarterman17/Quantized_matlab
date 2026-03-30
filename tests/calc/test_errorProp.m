%TEST_ERRORPROP  Tests for utilities.errorProp and convenience wrappers.
%
%   Run:
%     run tests/calc/test_errorProp
%     runAllTests(Group="calc")

clear; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(fileparts(thisDir));
if ~contains(path, rootDir)
    addpath(rootDir);
end

fprintf('\n=== test_errorProp ===\n');
passed = 0;
failed = 0;

TOL = 1e-6;  % tight tolerance for analytic comparisons

% ════════════════════════════════════════════════════════════════════════
%  errorAdd
% ════════════════════════════════════════════════════════════════════════

fprintf('\n--- utilities.errorAdd ---\n');

% Scalar addition: err = sqrt(da^2 + db^2)
[v, e] = utilities.errorAdd(3.0, 0.1, 4.0, 0.2);
eExpected = sqrt(0.1^2 + 0.2^2);
if abs(v - 7.0) < TOL && abs(e - eExpected) < TOL
    fprintf('  PASS: scalar addition val=%.4g, err=%.6f\n', v, e); passed = passed + 1;
else
    fprintf('  FAIL: got val=%.4g err=%.6f, expected val=7 err=%.6f\n', v, e, eExpected); failed = failed + 1;
end

% Sign: subtraction encoded as negative b
[v, e] = utilities.errorAdd(5.0, 0.2, -2.0, 0.1);
if abs(v - 3.0) < TOL && abs(e - sqrt(0.04 + 0.01)) < TOL
    fprintf('  PASS: subtraction via negative b\n'); passed = passed + 1;
else
    fprintf('  FAIL: subtraction result wrong\n'); failed = failed + 1;
end

% Vector element-wise
a_v  = [1 2 3];
da_v = [0.1 0.1 0.1];
b_v  = [4 5 6];
db_v = [0.2 0.2 0.2];
[v_vec, e_vec] = utilities.errorAdd(a_v, da_v, b_v, db_v);
eExp_vec = sqrt(da_v.^2 + db_v.^2);
if isequal(size(v_vec), [1 3]) && max(abs(v_vec - (a_v + b_v))) < TOL ...
        && max(abs(e_vec - eExp_vec)) < TOL
    fprintf('  PASS: vector element-wise addition\n'); passed = passed + 1;
else
    fprintf('  FAIL: vector addition\n'); failed = failed + 1;
end

% Zero error input
[~, e0] = utilities.errorAdd(3.0, 0, 4.0, 0.1);
if abs(e0 - 0.1) < TOL
    fprintf('  PASS: zero error on one input\n'); passed = passed + 1;
else
    fprintf('  FAIL: zero error case gave %.4g\n', e0); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  errorMul
% ════════════════════════════════════════════════════════════════════════

fprintf('\n--- utilities.errorMul ---\n');

% Scalar: relative errors add in quadrature
a = 3.0; da = 0.3;
b = 4.0; db = 0.4;
[v, e] = utilities.errorMul(a, da, b, db);
vExp = 12.0;
eExp = vExp * sqrt((da/a)^2 + (db/b)^2);
if abs(v - vExp) < TOL && abs(e - eExp) < TOL
    fprintf('  PASS: scalar multiplication err=%.6f\n', e); passed = passed + 1;
else
    fprintf('  FAIL: got val=%.4g err=%.6f, expected val=%.4g err=%.6f\n', v, e, vExp, eExp); failed = failed + 1;
end

% Vector element-wise
a_v  = [2 4 6];
da_v = [0.2 0.2 0.2];
b_v  = [3 5 7];
db_v = [0.3 0.3 0.3];
[v_vec, e_vec] = utilities.errorMul(a_v, da_v, b_v, db_v);
vExp_vec = a_v .* b_v;
eExp_vec = abs(vExp_vec) .* sqrt((da_v./a_v).^2 + (db_v./b_v).^2);
if max(abs(v_vec - vExp_vec)) < TOL && max(abs(e_vec - eExp_vec)) < TOL
    fprintf('  PASS: vector multiplication\n'); passed = passed + 1;
else
    fprintf('  FAIL: vector multiplication\n'); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  errorDiv
% ════════════════════════════════════════════════════════════════════════

fprintf('\n--- utilities.errorDiv ---\n');

% Scalar: same relative-quadrature rule
a = 6.0; da = 0.6;
b = 2.0; db = 0.2;
[v, e] = utilities.errorDiv(a, da, b, db);
vExp = 3.0;
eExp = vExp * sqrt((da/a)^2 + (db/b)^2);
if abs(v - vExp) < TOL && abs(e - eExp) < TOL
    fprintf('  PASS: scalar division err=%.6f\n', e); passed = passed + 1;
else
    fprintf('  FAIL: got val=%.4g err=%.6f, expected val=%.4g err=%.6f\n', v, e, vExp, eExp); failed = failed + 1;
end

% Division and multiplication give same relative error
[~, eMul] = utilities.errorMul(3.0, 0.3, 4.0, 0.4);
[~, eDiv] = utilities.errorDiv(3.0, 0.3, 4.0, 0.4);
relMul = eMul / 12.0;
relDiv = eDiv / (3.0/4.0);
if abs(relMul - relDiv) < TOL
    fprintf('  PASS: mul and div have same relative error rule\n'); passed = passed + 1;
else
    fprintf('  FAIL: relative errors differ: mul=%.6f div=%.6f\n', relMul, relDiv); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  errorFunc (single-variable)
% ════════════════════════════════════════════════════════════════════════

fprintf('\n--- utilities.errorFunc ---\n');

% log(x): df/dx = 1/x
x = 2.0; dx = 0.1;
[v, e] = utilities.errorFunc(@log, x, dx);
eExp = dx / x;
if abs(v - log(2.0)) < TOL && abs(e - eExp) < 1e-8
    fprintf('  PASS: log(x) err=%.6f (expected %.6f)\n', e, eExp); passed = passed + 1;
else
    fprintf('  FAIL: log err=%.6f expected %.6f\n', e, eExp); failed = failed + 1;
end

% exp(x): df/dx = exp(x)
x = 1.0; dx = 0.05;
[v, e] = utilities.errorFunc(@exp, x, dx);
eExp = exp(1.0) * dx;
if abs(v - exp(1.0)) < TOL && abs(e - eExp) < 1e-8
    fprintf('  PASS: exp(x) err=%.6f (expected %.6f)\n', e, eExp); passed = passed + 1;
else
    fprintf('  FAIL: exp err=%.6f expected %.6f\n', e, eExp); failed = failed + 1;
end

% sqrt(x): df/dx = 1/(2*sqrt(x))
x = 4.0; dx = 0.2;
[v, e] = utilities.errorFunc(@sqrt, x, dx);
eExp = dx / (2 * sqrt(x));
if abs(v - 2.0) < TOL && abs(e - eExp) < 1e-8
    fprintf('  PASS: sqrt(x) err=%.6f (expected %.6f)\n', e, eExp); passed = passed + 1;
else
    fprintf('  FAIL: sqrt err=%.6f expected %.6f\n', e, eExp); failed = failed + 1;
end

% Vector input to errorFunc
xv  = [1 4 9];
dxv = [0.1 0.2 0.3];
[vv, ev] = utilities.errorFunc(@sqrt, xv, dxv);
evExp = dxv ./ (2 .* sqrt(xv));
if max(abs(vv - sqrt(xv))) < TOL && max(abs(ev - evExp)) < 1e-8
    fprintf('  PASS: errorFunc vector sqrt\n'); passed = passed + 1;
else
    fprintf('  FAIL: errorFunc vector sqrt\n'); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  errorProp — linear method
% ════════════════════════════════════════════════════════════════════════

fprintf('\n--- utilities.errorProp (linear) ---\n');

% f = a*b + c: partial derivatives are b, a, 1
% sigma_f^2 = b^2*da^2 + a^2*db^2 + dc^2
a = 3.0; da = 0.1;
b = 4.0; db = 0.2;
c = 1.0; dc = 0.05;
f = @(x1, x2, x3) x1.*x2 + x3;
r = utilities.errorProp(f, {a, b, c}, {da, db, dc});

vExp = a*b + c;
eExp = sqrt(b^2*da^2 + a^2*db^2 + dc^2);
if abs(r.value - vExp) < TOL && abs(r.error - eExp) < 1e-6
    fprintf('  PASS: f=a*b+c, err=%.6f (expected %.6f)\n', r.error, eExp); passed = passed + 1;
else
    fprintf('  FAIL: f=a*b+c: val=%.4g err=%.6f expected err=%.6f\n', r.value, r.error, eExp); failed = failed + 1;
end

% Partial derivatives check: df/da = b = 4, df/db = a = 3, df/dc = 1
if abs(r.partials(1) - b) < 1e-4 && abs(r.partials(2) - a) < 1e-4 && abs(r.partials(3) - 1.0) < 1e-4
    fprintf('  PASS: partials [%.4g, %.4g, %.4g] match [%.4g, %.4g, %.4g]\n', ...
        r.partials(1), r.partials(2), r.partials(3), b, a, 1.0); passed = passed + 1;
else
    fprintf('  FAIL: partials [%.4g, %.4g, %.4g] expected [%.4g, %.4g, %.4g]\n', ...
        r.partials(1), r.partials(2), r.partials(3), b, a, 1.0); failed = failed + 1;
end

% relError field
if abs(r.relError - r.error/abs(r.value)) < TOL
    fprintf('  PASS: relError = err/|val|\n'); passed = passed + 1;
else
    fprintf('  FAIL: relError mismatch\n'); failed = failed + 1;
end

% ── Numeric array inputs (not cell) ─────────────────────────────────────
r2 = utilities.errorProp(@(x,y) x + y, [2, 3], [0.1, 0.2]);
if abs(r2.value - 5.0) < TOL && abs(r2.error - sqrt(0.01+0.04)) < 1e-6
    fprintf('  PASS: numeric array inputs accepted\n'); passed = passed + 1;
else
    fprintf('  FAIL: numeric array inputs\n'); failed = failed + 1;
end

% ── Single input ─────────────────────────────────────────────────────────
r3 = utilities.errorProp(@(x) x.^2, {3.0}, {0.1});
eExpSingle = 2*3.0*0.1;
if abs(r3.value - 9.0) < TOL && abs(r3.error - eExpSingle) < 1e-5
    fprintf('  PASS: single-input f=x^2, err=%.6f\n', r3.error); passed = passed + 1;
else
    fprintf('  FAIL: single-input: val=%.4g err=%.6f expected %.6f\n', r3.value, r3.error, eExpSingle); failed = failed + 1;
end

% ── Zero error ────────────────────────────────────────────────────────────
r4 = utilities.errorProp(@(x,y) x + y, {3, 4}, {0, 0});
if abs(r4.error) < TOL
    fprintf('  PASS: zero error propagates to zero\n'); passed = passed + 1;
else
    fprintf('  FAIL: zero error gave %.4g\n', r4.error); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  errorProp — correlated inputs
% ════════════════════════════════════════════════════════════════════════

fprintf('\n--- utilities.errorProp (correlated) ---\n');

% f = a + b
% Uncorrelated: sigma^2 = da^2 + db^2
% Fully correlated (corr=1): sigma^2 = (da+db)^2
da = 0.1; db = 0.1;
rUncorr = utilities.errorProp(@(a,b) a+b, {1, 1}, {da, db});
rCorr1  = utilities.errorProp(@(a,b) a+b, {1, 1}, {da, db}, Correlated=[1,1;1,1]);

eUncorr = sqrt(da^2 + db^2);
eCorr1  = da + db;

if abs(rUncorr.error - eUncorr) < 1e-6
    fprintf('  PASS: uncorrelated sum err=%.6f (expected %.6f)\n', rUncorr.error, eUncorr); passed = passed + 1;
else
    fprintf('  FAIL: uncorrelated sum err=%.6f expected %.6f\n', rUncorr.error, eUncorr); failed = failed + 1;
end

if abs(rCorr1.error - eCorr1) < 1e-6
    fprintf('  PASS: fully-correlated sum err=%.6f (expected %.6f)\n', rCorr1.error, eCorr1); passed = passed + 1;
else
    fprintf('  FAIL: fully-correlated sum err=%.6f expected %.6f\n', rCorr1.error, eCorr1); failed = failed + 1;
end

% Correlated < uncorrelated for subtraction
rSubUncorr = utilities.errorProp(@(a,b) a-b, {5, 3}, {da, db});
rSubCorr1  = utilities.errorProp(@(a,b) a-b, {5, 3}, {da, db}, Correlated=[1,1;1,1]);
if rSubCorr1.error < rSubUncorr.error
    fprintf('  PASS: correlation reduces error in subtraction\n'); passed = passed + 1;
else
    fprintf('  FAIL: correlated subtraction should have smaller error\n'); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  errorProp — Monte Carlo vs linear (linear function)
% ════════════════════════════════════════════════════════════════════════

fprintf('\n--- utilities.errorProp (MC vs linear) ---\n');

% For a linear function, MC and linear should agree closely
f_lin = @(a, b) 2*a + 3*b;
vals = {5.0, 2.0};
errs = {0.1, 0.2};

rLin = utilities.errorProp(f_lin, vals, errs, Method="linear");
rMC  = utilities.errorProp(f_lin, vals, errs, Method="montecarlo", NSamples=100000);

% Analytical: sigma = sqrt((2*0.1)^2 + (3*0.2)^2)
eAnalytic = sqrt((2*0.1)^2 + (3*0.2)^2);

linErr = abs(rLin.error - eAnalytic);
mcErr  = abs(rMC.error  - eAnalytic);

if linErr < 1e-5
    fprintf('  PASS: linear method matches analytic (err=%.2e)\n', linErr); passed = passed + 1;
else
    fprintf('  FAIL: linear method error %.2e (analytic=%.6f, got=%.6f)\n', linErr, eAnalytic, rLin.error); failed = failed + 1;
end

if mcErr < 0.005  % MC has sampling noise, use loose tolerance
    fprintf('  PASS: MC agrees with analytic to within 0.5%% (err=%.2e)\n', mcErr); passed = passed + 1;
else
    fprintf('  FAIL: MC error too large %.2e (analytic=%.6f, got=%.6f)\n', mcErr, eAnalytic, rMC.error); failed = failed + 1;
end

% MC confidence interval contains the nominal value for symmetric dist
nomVal = f_lin(vals{:});
if rMC.ci(1) < nomVal && nomVal < rMC.ci(2)
    fprintf('  PASS: MC CI [%.4g, %.4g] contains nominal value %.4g\n', rMC.ci(1), rMC.ci(2), nomVal); passed = passed + 1;
else
    fprintf('  FAIL: MC CI [%.4g, %.4g] does not contain %.4g\n', rMC.ci(1), rMC.ci(2), nomVal); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  errorProp — vector-valued function (linear method)
% ════════════════════════════════════════════════════════════════════════

fprintf('\n--- utilities.errorProp (vector-valued function) ---\n');

% f(a, b) returns a vector; error should be element-wise
fVec = @(a, b) [a + b; a - b; a .* b];
r5 = utilities.errorProp(fVec, {3.0, 4.0}, {0.1, 0.2});

% Analytical errors for each element
e1 = sqrt(0.1^2 + 0.2^2);          % a + b
e2 = sqrt(0.1^2 + 0.2^2);          % a - b
e3 = 12 * sqrt((0.1/3)^2 + (0.2/4)^2);  % a * b

if numel(r5.error) == 3
    fprintf('  PASS: vector output has 3 error values\n'); passed = passed + 1;
else
    fprintf('  FAIL: expected 3 error values, got %d\n', numel(r5.error)); failed = failed + 1;
end

if abs(r5.error(1) - e1) < 1e-5 && abs(r5.error(2) - e2) < 1e-5 && abs(r5.error(3) - e3) < 1e-5
    fprintf('  PASS: vector errors match analytic\n'); passed = passed + 1;
else
    fprintf('  FAIL: vector errors [%.6f %.6f %.6f] expected [%.6f %.6f %.6f]\n', ...
        r5.error(1), r5.error(2), r5.error(3), e1, e2, e3); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  Edge cases
% ════════════════════════════════════════════════════════════════════════

fprintf('\n--- Edge cases ---\n');

% Zero value (relError should not NaN/Inf — guarded by eps)
r_zero = utilities.errorProp(@(x) x, {0.0}, {0.1});
if isfinite(r_zero.relError)
    fprintf('  PASS: zero value gives finite relError\n'); passed = passed + 1;
else
    fprintf('  FAIL: zero value gave non-finite relError\n'); failed = failed + 1;
end

% errorAdd zero error both sides
[~, ez] = utilities.errorAdd(5, 0, 3, 0);
if abs(ez) < TOL
    fprintf('  PASS: errorAdd both-zero gives zero error\n'); passed = passed + 1;
else
    fprintf('  FAIL: errorAdd both-zero err=%.4g\n', ez); failed = failed + 1;
end

% errorDiv zero numerator (value=0, no NaN in err)
[vdz, edz] = utilities.errorDiv(0.0, 0.1, 2.0, 0.2);
if abs(vdz) < TOL && isfinite(edz)
    fprintf('  PASS: errorDiv zero numerator is finite\n'); passed = passed + 1;
else
    fprintf('  FAIL: errorDiv zero numerator: val=%.4g err=%.4g\n', vdz, edz); failed = failed + 1;
end

% MC error: size mismatch should error
try
    utilities.errorProp(@(a,b) a+b, {1,2}, {0.1});
    fprintf('  FAIL: size mismatch should error\n'); failed = failed + 1;
catch
    fprintf('  PASS: size mismatch throws error\n'); passed = passed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  Summary
% ════════════════════════════════════════════════════════════════════════

fprintf('\n=== test_errorProp: %d passed, %d failed ===\n\n', passed, failed);
if failed > 0
    error('test_errorProp:failures', '%d test(s) failed.', failed);
end
