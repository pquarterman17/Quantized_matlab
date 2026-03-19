function matches = matchPhases(peakPositions, opts)
%MATCHPHASES  Match observed XRD peak positions against the built-in phase database.
%
%   Syntax
%   ------
%   matches = calc.crystal.matchPhases(peakPositions)
%   matches = calc.crystal.matchPhases(peakPositions, Lambda=1.5406, Tolerance=0.05)
%
%   Inputs
%   ------
%   peakPositions — vector of observed peak 2theta values (degrees)
%   Lambda        — X-ray wavelength in Å (default 1.5406, Cu Ka1)
%   Tolerance     — d-spacing tolerance in Å (default 0.03)
%   MaxHKL        — maximum Miller index to enumerate (default 5)
%   MinMatchFrac  — minimum fraction of observed peaks matched (default 0.3)
%   Categories    — cell array of categories to search, e.g. {'metal','oxide'}
%                   (default {} = search all)
%
%   Output
%   ------
%   matches — struct array sorted by score (descending), with fields:
%     .phaseName   — name from database
%     .formula     — chemical formula
%     .score       — match score (0 to 1)
%     .nMatched    — number of observed peaks matched
%     .nObserved   — total observed peaks
%     .matchedHKL  — {nMatched x 1} cell of '(hkl)' strings
%     .matchedD    — [nMatched x 1] reference d-spacings
%     .matchedTwoTheta — [nMatched x 1] reference 2theta values
%     .observedIdx — [nMatched x 1] index into peakPositions
%     .allRefTwoTheta — all reference 2theta values for this phase
%     .allRefHKL      — all reference (hkl) as [N x 3]
%     .centering      — Bravais centering
%     .latticeParams  — [a b c alpha beta gamma]
%
%   Examples
%   --------
%   % Match peaks from an XRD scan
%   m = calc.crystal.matchPhases([28.44, 47.30, 56.12, 69.13, 76.37]);
%   fprintf('Best match: %s (%.0f%%)\n', m(1).phaseName, m(1).score*100);

% ════════════════════════════════════════════════════════════════════

arguments
    peakPositions  (:,1) double {mustBeNonempty}
    opts.Lambda        (1,1) double {mustBePositive} = 1.5406
    opts.Tolerance     (1,1) double {mustBePositive} = 0.03
    opts.MaxHKL        (1,1) double {mustBePositive, mustBeInteger} = 5
    opts.MinMatchFrac  (1,1) double = 0.3
    opts.Categories    (1,:) cell   = {}
end

peakPositions = sort(peakPositions(:));
nObs = numel(peakPositions);

% Convert observed 2theta to d-spacings
obsD = opts.Lambda ./ (2 * sind(peakPositions / 2));

% Load phase database
db = calc.crystal.phaseDatabase();

% Filter by category if specified
if ~isempty(opts.Categories)
    keep = ismember({db.category}, opts.Categories);
    db = db(keep);
end

nPhases = numel(db);
results = struct('phaseName',{},'formula',{},'score',{},'nMatched',{}, ...
                 'nObserved',{},'matchedHKL',{},'matchedD',{}, ...
                 'matchedTwoTheta',{},'observedIdx',{}, ...
                 'allRefTwoTheta',{},'allRefHKL',{}, ...
                 'centering',{},'latticeParams',{});

for pi = 1:nPhases
    phase = db(pi);

    % Compute reference reflections
    ref = calc.crystal.planeSpacings(phase.a, ...
        b=phase.b, c=phase.c, ...
        alpha=phase.alpha, beta=phase.beta, gamma=phase.gamma, ...
        Centering=phase.centering, MaxHKL=opts.MaxHKL, Lambda=opts.Lambda);

    % Keep only reflections within the observed 2theta range (with margin)
    margin = 2;  % degrees
    inRange = ref.twoTheta >= min(peakPositions) - margin & ...
              ref.twoTheta <= max(peakPositions) + margin & ...
              ~isnan(ref.twoTheta);
    refD   = ref.d(inRange);
    refHKL = ref.hkl(inRange, :);
    refTT  = ref.twoTheta(inRange);

    if isempty(refD), continue; end

    % Match each observed peak to nearest reference d-spacing
    matchedIdx  = zeros(nObs, 1);   % index into refD
    matchedFlag = false(nObs, 1);

    for oi = 1:nObs
        diffs = abs(obsD(oi) - refD);
        [minDiff, bestIdx] = min(diffs);
        if minDiff <= opts.Tolerance
            matchedFlag(oi) = true;
            matchedIdx(oi)  = bestIdx;
        end
    end

    nMatched = sum(matchedFlag);
    matchFrac = nMatched / nObs;

    if matchFrac < opts.MinMatchFrac, continue; end

    % Score: weighted combination of match fraction and coverage of strong reflections
    % Strong reflections = those with high multiplicity (likely intense)
    score = matchFrac;

    % Build match details
    mIdx = find(matchedFlag);
    mHKL = cell(nMatched, 1);
    for mi = 1:nMatched
        hkl = refHKL(matchedIdx(mIdx(mi)), :);
        mHKL{mi} = sprintf('(%d%d%d)', hkl(1), hkl(2), hkl(3));
    end

    entry.phaseName      = phase.name;
    entry.formula        = phase.formula;
    entry.score          = score;
    entry.nMatched       = nMatched;
    entry.nObserved      = nObs;
    entry.matchedHKL     = mHKL;
    entry.matchedD       = refD(matchedIdx(mIdx));
    entry.matchedTwoTheta = refTT(matchedIdx(mIdx));
    entry.observedIdx    = mIdx;
    entry.allRefTwoTheta = refTT;
    entry.allRefHKL      = refHKL;
    entry.centering      = phase.centering;
    entry.latticeParams  = [phase.a, phase.b, phase.c, phase.alpha, phase.beta, phase.gamma];

    results(end+1) = entry; %#ok<AGROW>
end

% Sort by score descending
if ~isempty(results)
    [~, sortIdx] = sort([results.score], 'descend');
    matches = results(sortIdx);
else
    matches = results;
end

end
