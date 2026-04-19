function [pFree0, expandFn, freeCenterIdx] = buildLinkedPacker( ...
        p0, nP, nPPerPeak, nBgParams, linkMode, centerIndicesFull) %#ok<INUSD>
%BUILDLINKEDPACKER  Map a reduced free-parameter vector to the full p layout.
%
%   [pFree0, expandFn, freeCenterIdx] = bosonPlotter.buildLinkedPacker( ...
%       p0, nP, nPPerPeak, nBgParams, linkMode, centerIndicesFull)
%
%   Builds the machinery that lets the global-fit objective (in
%   bosonPlotter.peakAnalysis) share selected peak parameters across all
%   peaks — a standard Rietveld-style constraint.  The optimizer works on
%   the reduced pFree vector; the returned expandFn inflates it back to
%   the full p layout that compositeEval expects.
%
%   Supported modes:
%     'None'              — identity: pFree = p0, expand is a no-op
%     'Shared FWHM'       — peak 1's FWHM slot is the master; peaks 2..nP
%                           drop their FWHM slot from pFree
%     'Shared FWHM + eta' — peak 1's FWHM *and* (Pseudo-Voigt) eta are
%                           the masters; peaks 2..nP drop both slots
%
%   Inputs
%   ------
%   p0                 (1,M) full initial parameter vector
%   nP                 scalar  number of peaks
%   nPPerPeak          scalar  parameters per peak (3 for Lorentzian/Gaussian,
%                              4 for Pseudo-Voigt)
%   nBgParams          scalar  number of background polynomial coefficients
%                              (unused — kept for signature stability)
%   linkMode           char    one of the modes above
%   centerIndicesFull  (1,nP) positions of peak centers within p0
%
%   Outputs
%   -------
%   pFree0         (1,K)   reduced initial vector with duplicate slots removed
%   expandFn       handle  pFull = expandFn(pFree) — inflates to the full
%                          p layout by copying master values into slave slots
%   freeCenterIdx  (1,nP)  positions of each peak's center within pFree
%                          (used by the center-constraint penalty in
%                          onFitSimultaneous)

    if strcmp(linkMode, 'None') || nP < 2
        pFree0        = p0;
        expandFn      = @(p) p;
        freeCenterIdx = centerIndicesFull;
        return;
    end

    isPV    = (nPPerPeak == 4);
    linkEta = strcmp(linkMode, 'Shared FWHM + eta') && isPV;

    dropIdx = [];
    for k = 2:nP
        base = (k-1) * nPPerPeak;
        dropIdx(end+1) = base + 3;              %#ok<AGROW> slave FWHM
        if linkEta
            dropIdx(end+1) = base + 4;          %#ok<AGROW> slave eta
        end
    end

    keepIdx = setdiff(1:numel(p0), dropIdx);
    pFree0  = p0(keepIdx);

    masterFWHMFull = 3;
    masterEtaFull  = 4;
    masterFWHMFree = find(keepIdx == masterFWHMFull, 1);
    masterEtaFree  = find(keepIdx == masterEtaFull,  1);

    srcMap = zeros(1, numel(p0));
    srcMap(keepIdx) = 1:numel(keepIdx);
    for k = 2:nP
        base = (k-1) * nPPerPeak;
        srcMap(base + 3) = -1;                  % slave FWHM
        if linkEta
            srcMap(base + 4) = -2;              % slave eta
        end
    end

    expandFn = @(pFree) localExpand(pFree, srcMap, masterFWHMFree, masterEtaFree);

    freeCenterIdx = zeros(1, nP);
    for k = 1:nP
        freeCenterIdx(k) = find(keepIdx == centerIndicesFull(k), 1);
    end
end

function pFull = localExpand(pFree, srcMap, mFW, mEta)
    pFull = zeros(1, numel(srcMap));
    for i = 1:numel(srcMap)
        s = srcMap(i);
        if s > 0
            pFull(i) = pFree(s);
        elseif s == -1
            pFull(i) = pFree(mFW);
        elseif s == -2
            pFull(i) = pFree(mEta);
        end
    end
end
