%TEST_TCHPSEUDOVOIGT  Smoke tests for utilities.tchPseudoVoigt (W3 #40).
%   Verifies:
%     1. Pure-Gaussian limit (fL -> 0) matches a Gaussian profile.
%     2. Pure-Lorentzian limit (fG -> 0) matches a Lorentzian profile.
%     3. Combined FWHM is consistent with the TCH polynomial.
%     4. Area is conserved against numerical integration.
%
%   Run: run tests/fitting/test_tchPseudoVoigt

fprintf('\n=== TCH-pV smoke tests ===\n\n');
nPass = 0; nFail = 0;

function_pass = @(msg) fprintf('  [OK]   %s\n', msg);
function_fail = @(msg) fprintf('  [FAIL] %s\n', msg);

% ── 1. Pure-Gaussian limit ─────────────────────────────────────────────
x = linspace(-5, 5, 501)';
H = 100; x0 = 0; bg = 0;

fG = 1.0; fL = 1e-8;
y_tch = utilities.tchPseudoVoigt(x, [H, x0, fG, fL, bg]);
y_gauss = H .* exp(-4*log(2) .* ((x - x0) ./ fG).^2);
err = max(abs(y_tch - y_gauss)) / max(y_gauss);
if err < 0.01
    function_pass(sprintf('Pure-Gaussian limit (max rel err %.2g)', err));
    nPass = nPass + 1;
else
    function_fail(sprintf('Pure-Gaussian limit err=%.3g', err));
    nFail = nFail + 1;
end

% ── 2. Pure-Lorentzian limit ───────────────────────────────────────────
fG = 1e-8; fL = 1.0;
y_tch = utilities.tchPseudoVoigt(x, [H, x0, fG, fL, bg]);
y_lorz = H ./ (1 + 4 .* ((x - x0) ./ fL).^2);
err = max(abs(y_tch - y_lorz)) / max(y_lorz);
if err < 0.01
    function_pass(sprintf('Pure-Lorentzian limit (max rel err %.2g)', err));
    nPass = nPass + 1;
else
    function_fail(sprintf('Pure-Lorentzian limit err=%.3g', err));
    nFail = nFail + 1;
end

% ── 3. Combined FWHM check ─────────────────────────────────────────────
fG = 0.8; fL = 0.4;
x = linspace(-3, 3, 2001)';
y = utilities.tchPseudoVoigt(x, [H, 0, fG, fL, 0]);
% Expected f from TCH polynomial
f5 = fG^5 + 2.69269*fG^4*fL + 2.42843*fG^3*fL^2 ...
   + 4.47163*fG^2*fL^3 + 0.07842*fG*fL^4 + fL^5;
f_expected = f5^(1/5);
% Measured FWHM from profile crossings
half = max(y) / 2;
above = y >= half;
iL = find(above, 1, 'first');
iR = find(above, 1, 'last');
x_left  = interp1(y(iL-1:iL), x(iL-1:iL), half);
x_right = interp1(y(iR:iR+1), x(iR:iR+1), half);
f_measured = x_right - x_left;
err = abs(f_measured - f_expected) / f_expected;
if err < 0.01
    function_pass(sprintf('Combined FWHM: expected=%.4f measured=%.4f (err %.2g)', ...
        f_expected, f_measured, err));
    nPass = nPass + 1;
else
    function_fail(sprintf('FWHM mismatch: expected=%.4f measured=%.4f', ...
        f_expected, f_measured));
    nFail = nFail + 1;
end

% ── 4. Closed-form area vs numerical integration ───────────────────────
% Lorentzian tails decay as 1/x^2, so we need a wide x range for an
% accurate numerical reference.
x = linspace(-500, 500, 200001)';
fG = 0.5; fL = 0.3;
y = utilities.tchPseudoVoigt(x, [H, 0, fG, fL, 0]);
area_num = trapz(x, y);
% Derive eta from TCH
r = fL / f_expected;  % reusing, recompute for new fG/fL
f5 = fG^5 + 2.69269*fG^4*fL + 2.42843*fG^3*fL^2 ...
   + 4.47163*fG^2*fL^3 + 0.07842*fG*fL^4 + fL^5;
fT = f5^(1/5);
r  = fL / fT;
eta = 1.36603*r - 0.47719*r^2 + 0.11116*r^3;
area_formula = H * fT * (eta*pi/2 + (1-eta)*sqrt(pi)/(2*sqrt(log(2))));
err = abs(area_num - area_formula) / area_formula;
if err < 1e-3
    function_pass(sprintf('Area closed-form: num=%.4f formula=%.4f (err %.2g)', ...
        area_num, area_formula, err));
    nPass = nPass + 1;
else
    function_fail(sprintf('Area mismatch: num=%.4f formula=%.4f', ...
        area_num, area_formula));
    nFail = nFail + 1;
end

fprintf('\nSUMMARY: %d passed, %d failed.\n', nPass, nFail);
