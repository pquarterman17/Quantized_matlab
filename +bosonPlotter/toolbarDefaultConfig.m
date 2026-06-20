function ids = toolbarDefaultConfig()
%TOOLBARDEFAULTCONFIG  Return the factory-default ordered list of toolbar action IDs.
%
% ── Syntax ────────────────────────────────────────────────────────────────
%
%   ids = bosonPlotter.toolbarDefaultConfig()
%
% ── Outputs ───────────────────────────────────────────────────────────────
%
%   ids   {1×N} cell array of action ID strings in default display order
%
% ── Examples ──────────────────────────────────────────────────────────────
%
%   ids = bosonPlotter.toolbarDefaultConfig();
%
% ── Notes ─────────────────────────────────────────────────────────────────
%
%   Ordered by functional group (Navigate · View · Analyze · Export · History)
%   to match the BosonPlotter UI design system. buildToolbar renders a caption
%   at each group boundary. Every ID here must exist in the toolbar registry
%   (tbActions in BosonPlotter.m); buildToolbar silently drops unknown IDs.
%   Users can pare this down via View ▸ Customise Toolbar (config persists).
%
% ════════════════════════════════════════════════════════════════════════

    ids = { ...
        'cursor', 'pan', 'zoomIn', 'zoomOut', 'autoscale', ...        % Navigate
        'grid', 'legend', 'clearOverlays', 'themeToggle', ...         % View
        'peakWorkshop', 'figBuilder', 'animate', 'watchFile', 'workspace', ...  % Analyze
        'copy', 'save', 'export', ...                                 % Export
        'undo', 'redo'};                                              % History
end
