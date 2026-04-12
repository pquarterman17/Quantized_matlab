function corrections = computeAutoMagCorrections(datasets, indices, lbYValue)
%COMPUTEAUTOMAGCORRECTIONS  Estimate linear BG and Y offset from high-field data.
%   First-pass computation for the Auto Mag Corrections feature.
%   Uses data points at |x| >= 95% of the maximum |x| (field) range to
%   find the saturation region.  Fits a line through those points to get
%   BG slope + intercept, and computes Y offset as the mean of the
%   positive-field and negative-field saturation averages.
%
%   Works on the first selected Y channel.  Operates on the raw data
%   (pre-correction) so the resulting polynomial is compatible with
%   onApplyCorrections.
%
%   Syntax:
%     corrections = bosonPlotter.computeAutoMagCorrections(datasets, indices, lbYValue)
%
%   Inputs:
%     datasets  - cell array of dataset structs (appData.datasets)
%     indices   - row vector of dataset indices to process
%     lbYValue  - current value of lbY listbox (char, string, or cell array)
%
%   Outputs:
%     corrections - struct array with fields: .di, .slope, .intercept, .yOff
%                   Only datasets that are magnetometry parsers and have
%                   sufficient high-field data are included.
%
%   Examples:
%     corrections = bosonPlotter.computeAutoMagCorrections( ...
%         appData.datasets, 1:numel(appData.datasets), lbY.Value);
%     for ci = 1:numel(corrections)
%         c = corrections(ci);
%         efBGSlope.Value     = c.slope;
%         efBGIntercept.Value = c.intercept;
%         efYOffset.Value     = c.yOff;
%     end

    corrections = struct('di', {}, 'slope', {}, 'intercept', {}, 'yOff', {});

    magParsers = {'importQDVSM','importPPMS','importMPMS','importLakeShore'};

    % Resolve Y channel selection
    ySel = ensureCell_local(lbYValue);

    for di = indices
        ds = datasets{di};
        if ~isfield(ds, 'parserName') || ~ismember(ds.parserName, magParsers)
            continue;
        end

        d = ds.data;
        if isdatetime(d.time), continue; end

        xVec = double(d.time);

        % Use first selected Y channel, or fall back to first column
        yIdx = 1;
        if ~isempty(ySel)
            found = find(strcmp(d.labels, ySel{1}), 1);
            if ~isempty(found), yIdx = found; end
        end
        yVec = d.values(:, yIdx);

        % Remove NaNs
        valid = ~isnan(xVec) & ~isnan(yVec);
        xV = xVec(valid);
        yV = yVec(valid);
        if numel(xV) < 4, continue; end

        % Identify high-field region: |x| >= 95% of max |x|
        maxAbsX = max(abs(xV));
        if maxAbsX < eps, continue; end
        threshold = 0.95 * maxAbsX;
        hiPos = xV >=  threshold;
        hiNeg = xV <= -threshold;
        hiField = hiPos | hiNeg;

        if sum(hiField) < 2, continue; end

        % Fit linear BG through high-field points
        p = polyfit(xV(hiField), yV(hiField), 1);

        % Y offset: average of positive and negative saturation means
        % after removing the linear BG
        yDetrended = yV - polyval(p, xV);
        if any(hiPos) && any(hiNeg)
            meanPos = mean(yDetrended(hiPos));
            meanNeg = mean(yDetrended(hiNeg));
            yOff = (meanPos + meanNeg) / 2;
        else
            yOff = mean(yDetrended(hiField));
        end

        corrections(end+1) = struct('di', di, ...  %#ok<AGROW>
            'slope', p(1), 'intercept', p(2), 'yOff', yOff);
    end
end

% ════════════════════════════════════════════════════════════════════════
% Local helpers (duplicated from BosonPlotter.m — not accessible cross-file)
% ════════════════════════════════════════════════════════════════════════

function c = ensureCell_local(v)
    if ischar(v) || isstring(v)
        c = cellstr(v);
    else
        c = v;
    end
end
