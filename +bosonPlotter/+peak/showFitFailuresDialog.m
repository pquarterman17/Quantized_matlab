function showFitFailuresDialog(parentFig, failures)
%SHOWFITFAILURESDIALOG  Rich dialog listing failed peaks + actionable hints.
%   failures: struct array with .idx .center .reason .suggestion .window
    if isempty(failures), return; end
    nF = numel(failures);

    dlg = uifigure('Name', sprintf('Fit Issues (%d peak%s)', nF, plural(nF)), ...
        'Position', [300 250 540 min(420, 110 + 64*nF)], ...
        'Resize', 'off');
    rootGL = uigridlayout(dlg, [3 1], ...
        'RowHeight', {26, '1x', 32}, ...
        'Padding', [12 10 12 10], 'RowSpacing', 6);

    uilabel(rootGL, ...
        'Text', sprintf('%d peak%s could not be fitted. Suggested fixes below:', nF, plural(nF)), ...
        'FontWeight', 'bold');

    scrollPanel = uipanel(rootGL, 'BorderType', 'none', 'Scrollable', 'on');
    listGL = uigridlayout(scrollPanel, [nF 1], ...
        'RowHeight', repmat({'fit'}, 1, nF), ...
        'Padding', [0 0 4 0], 'RowSpacing', 4);

    for k = 1:nF
        f = failures(k);
        msg = sprintf(['<html><b>Peak #%d</b> (centre %.3f) — <i>%s</i><br>' ...
                       '&nbsp;&nbsp;%s</html>'], ...
            f.idx, f.center, prettyReason(f.reason), f.suggestion);
        uilabel(listGL, 'Text', msg, ...
            'Interpreter', 'html', ...
            'WordWrap', 'on', ...
            'FontSize', 11);
    end

    btnRow = uigridlayout(rootGL, [1 2], ...
        'ColumnWidth', {'1x', 110}, ...
        'Padding', [0 0 0 0]);
    uilabel(btnRow, 'Text', '');
    btnOK = uibutton(btnRow, 'Text', 'OK', ...
        'ButtonPushedFcn', @(~,~) delete(dlg));
    btnOK.Layout.Column = 2;

    if ~isempty(parentFig) && isvalid(parentFig) && ~strcmpi(parentFig.Visible, 'off')
        figure(dlg);
    end
end

function s = plural(n), if n == 1, s = ''; else, s = 's'; end, end

function s = prettyReason(reason)
    switch reason
        case 'window-too-narrow', s = 'fit window too narrow';
        case 'center-drift',       s = 'centre drifted out of window';
        case 'fwhm-too-wide',      s = 'FWHM grew past sanity limit';
        case 'fminsearch-error',   s = 'optimiser error';
        case 'too-few-points',     s = 'too few data points';
        otherwise,                 s = reason;
    end
end
