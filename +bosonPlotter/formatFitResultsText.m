function txt = formatFitResultsText(result, options)
%FORMATFITRESULTSTEXT  Build a multi-line annotation string from fit results.
%
%   txt = bosonPlotter.formatFitResultsText(result)
%   txt = bosonPlotter.formatFitResultsText(result, Compact=true)
%
%   Inputs
%     result  - struct with fields: .model, .paramNames, .params, .errors,
%               .R2, .chiSqRed (as returned by doCurveFit in curveFitting.m)
%
%   Options
%     Compact - logical (default false). If true, omit the model header
%               and use shorter number format.

    arguments
        result   struct
        options.Compact logical = false
    end

    lines = {};

    if ~options.Compact
        lines{end+1} = result.model;
    end

    % Parameter values +/- errors
    for i = 1:numel(result.paramNames)
        pName = result.paramNames{i};
        pVal  = result.params(i);
        pErr  = result.errors(i);

        if options.Compact
            if isfinite(pErr) && pErr > 0
                lines{end+1} = sprintf('%s = %.4g +/- %.2g', pName, pVal, pErr);
            else
                lines{end+1} = sprintf('%s = %.4g', pName, pVal);
            end
        else
            if isfinite(pErr) && pErr > 0
                lines{end+1} = sprintf('%s = %.6g %s %.3g', pName, pVal, char(177), pErr);
            else
                lines{end+1} = sprintf('%s = %.6g (fixed)', pName, pVal);
            end
        end
    end

    % Goodness-of-fit metrics
    lines{end+1} = '';
    lines{end+1} = sprintf('R%s = %.6f', char(178), result.R2);
    if isfield(result, 'chiSqRed') && isfinite(result.chiSqRed)
        lines{end+1} = sprintf('%s%s = %.4g', char(967), char(178), result.chiSqRed);
    end

    txt = strjoin(lines, newline);
end
