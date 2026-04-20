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
%   % ids == {'cursor','autoscale','clearOverlays','grid','legend','copy','save'}
%
% ════════════════════════════════════════════════════════════════════════

    ids = {'cursor', 'autoscale', 'clearOverlays', 'grid', 'legend', 'copy', 'save'};
end
