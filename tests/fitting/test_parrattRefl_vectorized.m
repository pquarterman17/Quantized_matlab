function tests = test_parrattRefl_vectorized
%TEST_PARRATTREFL_VECTORIZED  Vectorised resolution-smearing path agrees with
% the per-point loop reference to floating-point round-off.
tests = functiontests(localfunctions);
end

function testConstantResolution(tc)
    % 200 Å SiO2 on Si, 3% dQ/Q
    Q = linspace(0.01, 0.3, 500)';
    layers = [0 0 0 0; 200 3.47e-6 0 5; 0 2.07e-6 0 3];

    Rvec = fitting.parrattRefl(Q, layers, Resolution=0.03);
    Rref = refLoop(Q, layers, 0.03 * Q, true);

    relDiff = abs(Rvec - Rref) ./ max(abs(Rref), 1e-30);
    tc.verifyLessThan(max(relDiff), 1e-10, ...
        sprintf('Constant-resolution max rel-diff = %.3e', max(relDiff)));
end

function testPerPointResolution(tc)
    Q = linspace(0.005, 0.25, 300)';
    layers = [0 0 0 0; 150 4.2e-6 0 4; 0 2.07e-6 0 2];
    dQ = 0.001 + 0.02 * Q;       % per-point σ

    Rvec = fitting.parrattRefl(Q, layers, Resolution=dQ);
    Rref = refLoop(Q, layers, dQ, true);

    relDiff = abs(Rvec - Rref) ./ max(abs(Rref), 1e-30);
    tc.verifyLessThan(max(relDiff), 1e-10, ...
        sprintf('Per-point resolution max rel-diff = %.3e', max(relDiff)));
end

function testZeroResolutionMix(tc)
    Q = linspace(0.01, 0.2, 50)';
    layers = [0 0 0 0; 100 3e-6 0 3; 0 2.07e-6 0 2];
    dQ = 0.005 * ones(size(Q));
    dQ([5, 20, 40]) = 0;          % a few zero-resolution points

    Rvec = fitting.parrattRefl(Q, layers, Resolution=dQ);
    Rref = refLoop(Q, layers, dQ, true);

    relDiff = abs(Rvec - Rref) ./ max(abs(Rref), 1e-30);
    tc.verifyLessThan(max(relDiff), 1e-10, ...
        sprintf('Mixed-zero-resolution max rel-diff = %.3e', max(relDiff)));
end

function testRoughnessOff(tc)
    Q = linspace(0.01, 0.3, 200)';
    layers = [0 0 0 0; 300 3.5e-6 0 4; 0 2.07e-6 0 2];
    Rvec = fitting.parrattRefl(Q, layers, Resolution=0.04, Roughness=false);
    Rref = refLoop(Q, layers, 0.04 * Q, false);
    relDiff = abs(Rvec - Rref) ./ max(abs(Rref), 1e-30);
    tc.verifyLessThan(max(relDiff), 1e-10);
end

function R = refLoop(Q, layers, dQ, roughness)
    % Reference: snapshot of the original per-point loop implementation.
    N = numel(Q);
    nOver  = 21;
    nSigma = 3;
    R = zeros(N, 1);
    for iPt = 1:N
        if dQ(iPt) <= 0
            R(iPt) = fitting.parrattRefl(Q(iPt), layers, ...
                Roughness=roughness);
            continue;
        end
        qSamp = linspace(Q(iPt) - nSigma * dQ(iPt), ...
                         Q(iPt) + nSigma * dQ(iPt), nOver)';
        qSamp = max(qSamp, 1e-6);
        Rsamp = fitting.parrattRefl(qSamp, layers, Roughness=roughness);
        w = exp(-0.5 * ((qSamp - Q(iPt)) / dQ(iPt)).^2);
        R(iPt) = sum(w .* Rsamp) / sum(w);
    end
end
