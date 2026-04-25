function btn = sectionHeader(parent, label, callback, varargin)
%SECTIONHEADER  Styled collapsible-section header button.
%
% Syntax
%   btn = bosonPlotter.sectionHeader(parent, label, callback)
%   btn = bosonPlotter.sectionHeader(__, name, value, ...)
%
% Inputs
%   parent     uigridlayout (or any uibutton parent)
%   label      Text shown on the button (e.g. '▼ Offsets & BG'). Caller
%              chooses the prefix glyph — char(9660) ▼ for expanded,
%              char(9654) ▶ for collapsed.
%   callback   ButtonPushedFcn handle. Triggered on click; the caller
%              is responsible for toggling the section's RowHeight and
%              flipping the prefix glyph in the button text.
%
% Optional name/value
%   'Tooltip'         hover text (default '')
%   'FontColor'       text colour (default tk.color.textMuted)
%   'BackgroundColor' button BG (default tk.color.bgPanel)
%
% Notes
%   Single source of truth for section-header styling (FontWeight bold,
%   FontSize tk.font.body, left-aligned). Changing the look-and-feel of
%   collapsible sections is now a one-edit change here rather than 8
%   separate uibutton blocks in BosonPlotter.m.
%
%   Returns the uibutton handle so callers can set Tag, Layout.Row,
%   Layout.Column, and update Text on subsequent toggles.

    p = inputParser;
    tk = bosonPlotter.uxTokens();
    p.addParameter('Tooltip', '');
    p.addParameter('FontColor', tk.color.textMuted);
    p.addParameter('BackgroundColor', tk.color.bgPanel);
    p.parse(varargin{:});
    opts = p.Results;

    btn = uibutton(parent, ...
        'Text',                 label, ...
        'FontSize',             tk.font.body, ...
        'FontWeight',           'bold', ...
        'FontColor',            opts.FontColor, ...
        'BackgroundColor',      opts.BackgroundColor, ...
        'HorizontalAlignment',  'left', ...
        'Tooltip',              opts.Tooltip, ...
        'ButtonPushedFcn',      callback);
end
