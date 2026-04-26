function suggestion = suggestNextStep(reason, modelName)
%SUGGESTNEXTSTEP  One-line actionable hint based on a fit-failure reason.
    switch reason
        case 'window-too-narrow'
            suggestion = 'window covered too few points — widen via right-click on the peak row, or zoom out before clicking Add Peak';
        case 'center-drift'
            suggestion = 'fit centre wandered out of the window — peak overlap likely; try Fit All (global) or Add Peak closer to the maximum';
        case 'fwhm-too-wide'
            if strcmpi(modelName, 'Lorentzian')
                suggestion = 'shape diverged — try Gaussian or Pseudo-Voigt, or subtract background first (auto-detect once)';
            else
                suggestion = 'shape diverged — subtract background first (run auto-detect once) or pick a tighter manual seed';
            end
        case 'fminsearch-error'
            suggestion = 'optimiser threw — usually NaN/inf in the data window; check for masked rows';
        case 'too-few-points'
            suggestion = 'not enough data points in scan — check x-range filter';
        otherwise
            suggestion = 'try a different fit model';
    end
end
