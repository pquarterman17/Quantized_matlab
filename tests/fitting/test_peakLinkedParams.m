%TEST_PEAKLINKEDPARAMS  Smoke tests for multi-peak linked-parameter fit.
%   Verifies that a 3-peak Lorentzian fit with Shared FWHM recovers a
%   single FWHM value across all peaks, and that Shared FWHM + eta
%   locks both width and mixing parameter for Pseudo-Voigt.
%
%   Exercises the buildLinkedPacker + onFitSimultaneous logic added to
%   +bosonPlotter/peakAnalysis.m in W3 #33.
%
%   Run: run tests/fitting/test_peakLinkedParams

fprintf('\n=== Peak linked-params tests ===\n\n');
nPass = 0; nFail = 0;

pass = @(msg) fprintf('  [OK]   %s\n', msg);
fail = @(msg) fprintf('  [FAIL] %s\n', msg);

% Build a synthetic spectrum with three overlapping Lorentzians that
% all share a common FWHM.
x = linspace(0, 100, 2001)';
centers = [30, 50, 70];
heights = [10, 8, 6];
fwhmTrue = 3.5;
bg = 0.5 + 0.01 * x;
y = bg;
for ki = 1:numel(centers)
    u = (x - centers(ki)) / fwhmTrue;
    y = y + heights(ki) ./ (1 + 4 * u.^2);
end
rng(0);
y = y + 0.05 * randn(size(y));

% ── 1. Linked FWHM recovers a single width ───────────────────────────
% We can't call the GUI headlessly, so run the packer logic on the
% expected composite-model layout and verify the optimizer pins all
% FWHMs to the master value.

nP        = 3;
nPPerPeak = 3;  % Lorentzian: H, x0, fwhm
nBg       = 2;  % linear background

% Seed parameter vector: H_k, x0_k, fwhm_k, ..., c0, c1
p0 = zeros(1, nP * nPPerPeak + nBg);
for ki = 1:nP
    base = (ki-1) * nPPerPeak;
    p0(base + 1) = heights(ki);
    p0(base + 2) = centers(ki);
    p0(base + 3) = fwhmTrue + 0.5 * randn();  % perturbed seed
end
p0(end-1) = 0.5;  % c0
p0(end)   = 0.0;  % c1
centerIndicesFull = (0:nP-1) * nPPerPeak + 2;

% Build the packer in "Shared FWHM" mode.
[pFree0, expandFn, freeCenterIdx] = bosonPlotter.buildLinkedPacker( ...
    p0, nP, nPPerPeak, nBg, 'Shared FWHM', centerIndicesFull);

% Reduced vector should drop the two slave FWHM slots.
expectedLen = numel(p0) - (nP - 1);
if numel(pFree0) == expectedLen
    pass(sprintf('Shared FWHM: pFree length = %d (expected %d)', numel(pFree0), expectedLen));
    nPass = nPass + 1;
else
    fail(sprintf('pFree length mismatch: %d vs %d', numel(pFree0), expectedLen));
    nFail = nFail + 1;
end

% Expand and verify all FWHMs equal the master.
pFull = expandFn(pFree0);
fwhms = pFull(centerIndicesFull + 1);  % fwhm slot is one after center
if all(fwhms == fwhms(1))
    pass(sprintf('Expand pins all FWHMs to master (=%.3f)', fwhms(1)));
    nPass = nPass + 1;
else
    fail(sprintf('FWHMs not linked: %s', mat2str(fwhms, 4)));
    nFail = nFail + 1;
end

% Center indices in the reduced vector still point at peak centers.
centersInFree = pFree0(freeCenterIdx);
if isequal(centersInFree, p0(centerIndicesFull))
    pass('freeCenterIdx correctly maps to peak centers');
    nPass = nPass + 1;
else
    fail('freeCenterIdx map mismatch');
    nFail = nFail + 1;
end

% Run fminsearch on the reduced objective.
modelFun = @(p, xx) lorentzianComposite(p, xx, nP, nPPerPeak, nBg);
objFun   = @(pFree) sum((modelFun(expandFn(pFree), x) - y).^2);
opts = optimset('Display', 'off', 'MaxIter', 20000, 'TolX', 1e-10, 'TolFun', 1e-12);
pFreeFit = fminsearch(objFun, pFree0, opts);
pFitFull = expandFn(pFreeFit);

fwhmsFit = pFitFull(centerIndicesFull + 1);
if all(abs(fwhmsFit - fwhmsFit(1)) < 1e-10)
    pass(sprintf('After fit, FWHMs remain linked (all=%.4f; true=%.4f)', ...
        fwhmsFit(1), fwhmTrue));
    nPass = nPass + 1;
else
    fail(sprintf('FWHMs diverged during fit: %s', mat2str(fwhmsFit, 4)));
    nFail = nFail + 1;
end

if abs(fwhmsFit(1) - fwhmTrue) / fwhmTrue < 0.05
    pass(sprintf('Recovered FWHM=%.4f within 5%% of true=%.4f', fwhmsFit(1), fwhmTrue));
    nPass = nPass + 1;
else
    fail(sprintf('Recovered FWHM=%.4f off from true=%.4f', fwhmsFit(1), fwhmTrue));
    nFail = nFail + 1;
end

% ── 2. None mode is the identity ─────────────────────────────────────
[pFreeNone, expandNone, freeIdxNone] = bosonPlotter.buildLinkedPacker( ...
    p0, nP, nPPerPeak, nBg, 'None', centerIndicesFull);

if numel(pFreeNone) == numel(p0) && isequal(expandNone(pFreeNone), p0) ...
        && isequal(freeIdxNone, centerIndicesFull)
    pass('None mode is the identity (pFree=p0, expand is no-op)');
    nPass = nPass + 1;
else
    fail('None mode does not round-trip as identity');
    nFail = nFail + 1;
end

% ── 3. Shared FWHM + eta drops two slots per slave peak ──────────────
nPPerPeakPV = 4;  % Pseudo-Voigt
p0PV = zeros(1, nP * nPPerPeakPV + nBg);
for ki = 1:nP
    base = (ki-1) * nPPerPeakPV;
    p0PV(base + 1) = heights(ki);
    p0PV(base + 2) = centers(ki);
    p0PV(base + 3) = fwhmTrue;
    p0PV(base + 4) = 0.5;
end
p0PV(end-1) = 0.5; p0PV(end) = 0.0;
centerIdxPV = (0:nP-1) * nPPerPeakPV + 2;

[pFreePV, expandPV, ~] = bosonPlotter.buildLinkedPacker( ...
    p0PV, nP, nPPerPeakPV, nBg, 'Shared FWHM + eta', centerIdxPV);

expectedLenPV = numel(p0PV) - 2 * (nP - 1);
if numel(pFreePV) == expectedLenPV
    pass(sprintf('Shared FWHM+eta: pFree length = %d (expected %d)', ...
        numel(pFreePV), expectedLenPV));
    nPass = nPass + 1;
else
    fail(sprintf('PV pFree length mismatch: %d vs %d', numel(pFreePV), expectedLenPV));
    nFail = nFail + 1;
end

pFullPV = expandPV(pFreePV);
etas    = pFullPV(centerIdxPV + 2);
if all(etas == etas(1))
    pass(sprintf('All etas linked to master (=%.3f)', etas(1)));
    nPass = nPass + 1;
else
    fail(sprintf('Etas not linked: %s', mat2str(etas, 4)));
    nFail = nFail + 1;
end

fprintf('\nSUMMARY: %d passed, %d failed.\n', nPass, nFail);

% ── Local: composite Lorentzian evaluator ────────────────────────────
function yOut = lorentzianComposite(p, xx, nP_, nPPerPeak_, nBgParams_)
    bgC  = p(end-nBgParams_+1:end);
    yOut = polyval(flip(bgC), xx);
    for k2 = 1:nP_
        b  = (k2-1) * nPPerPeak_;
        H  = p(b + 1);
        x0 = p(b + 2);
        fw = p(b + 3);
        yOut = yOut + H ./ (1 + 4 .* ((xx - x0) ./ fw).^2);
    end
end
