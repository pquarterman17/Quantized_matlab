function onCopyDataToClipboard(appData, fig, callbacks)
%ONCOPYDATATOCLIPBOARD  Copy selected datasets as tab-delimited text.
%
% Syntax
%   bosonPlotter.onCopyDataToClipboard(appData, fig, callbacks)
%
% Behaviour
%   Opens a modal multi-select `listdlg` showing every loaded dataset
%   (each entry prefixed with its parser-type badge: [XRD], [MAG],
%   [NR], etc.), then serialises the selection as tab-delimited text
%   with Origin-compatible multi-row headers via
%   `bosonPlotter.buildClipboardString`.  The result goes to the system
%   clipboard; a modal alert confirms the copy count.  Errors surface
%   through `logGUIError` and a user-facing `uialert`.
%
% Inputs
%   appData   - bosonPlotter.AppState handle (reads datasets / activeIdx)
%   fig       - Main figure handle (uialert parent)
%   callbacks - Struct of function handles:
%                 .logGUIError(title, msg, ME)

    if isempty(appData.datasets)
        bosonPlotter.quietAlert(fig, 'Load a file first.', 'No data');
        return;
    end

    % Build display names for each loaded dataset
    nDS = numel(appData.datasets);
    names = cell(1, nDS);
    for i = 1:nDS
        [~, fn, ex] = fileparts(appData.datasets{i}.filepath);
        badge = getParserBadge(appData.datasets{i}.parserName);
        names{i} = sprintf('%s %s%s', badge, fn, ex);
    end

    % Modal multi-select dialog
    sel = listdlg('ListString', names, ...
        'SelectionMode', 'multiple', ...
        'InitialValue', appData.activeIdx, ...
        'Name', 'Copy to Clipboard', ...
        'PromptString', 'Select datasets to copy:', ...
        'ListSize', [350 300]);
    if isempty(sel), return; end

    try
        clipStr = bosonPlotter.buildClipboardString(appData, sel);
        clipboard('copy', clipStr);
        bosonPlotter.quietAlert(fig, sprintf('Copied %d dataset(s) to clipboard.\nPaste into Origin or Excel.', ...
            numel(sel)), 'Copied');
    catch ME
        callbacks.logGUIError('Clipboard error', ME.message, ME);
        bosonPlotter.quietAlert(fig, ME.message, 'Clipboard error');
    end
end

% ════════════════════════════════════════════════════════════════════════
% Local helper (duplicated from BosonPlotter.m module-level scope)
% ════════════════════════════════════════════════════════════════════════

function badge = getParserBadge(parserName)
%GETPARSERBADGE  Return a short parser type tag (e.g. [XRD], [VSM], [CSV]).
    switch parserName
        case {'importRigaku_raw', 'importXRDML', 'importBruker'}
            badge = '[XRD]';
        case {'importQDVSM', 'importPPMS', 'importMPMS', 'importLakeShore'}
            badge = '[MAG]';
        case {'importNCNRDat', 'importNCNRRefl', 'importNCNRPNR'}
            badge = '[NR]';
        case 'importSIMS'
            badge = '[SIMS]';
        case {'importExcel', 'importCSV'}
            badge = '[DAT]';
        case 'lineCut'
            badge = '[CUT]';
        case 'boxIntegral'
            badge = '[BOX]';
        case 'arcIntegral'
            badge = '[ARC]';
        otherwise
            badge = '';
    end
end
