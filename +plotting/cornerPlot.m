function cornerPlot(samples, varargin)
%CORNERPLOT  Triangle / corner plot of MCMC parameter samples.
%
%   TODO: scaffold implementation — functional for 1D histograms on the
%   diagonal and 2D scatter/hexbin on the lower triangle. The production
%   target is full KDE contours with credible-interval shading. See
%   docs/theory/fitting.md "MCMC posterior sampling" for the spec.
%
%   Syntax
%   ------
%       plotting.cornerPlot(samples)
%       plotting.cornerPlot(samples, Labels=labels, Truth=truthVec, ...
%                           Quantiles=[0.16, 0.5, 0.84])
%
%   Inputs
%   ------
%   samples   [N × P] matrix of MCMC samples (one row per draw).
%
%   Options
%   -------
%   Labels      1×P cell array of parameter names (default: {'p1', 'p2', ...}).
%   Truth       1×P vector of "true" values to overlay as red lines.
%   Quantiles   Percentiles drawn on the 1D histograms (default [0.16 0.5 0.84]).
%   Parent      Existing figure handle to plot into (default: new figure).
%
%   Notes
%   -----
%   * Plots a P×P grid of tiled axes: diagonal = 1D posteriors,
%     lower triangle = 2D scatter, upper triangle = empty.
%   * TODO: replace scatter with 2D histogram + contour; show credible
%     regions; suppress upper triangle axes.
%
%   Example
%   -------
%   r = fitting.mcmcSample(lp, [0, 1], NumSteps=5000);
%   plotting.cornerPlot(r.samples, Labels={'mu', 'sigma'});

% ════════════════════════════════════════════════════════════════════════
%  Arguments
% ════════════════════════════════════════════════════════════════════════
arguments
    samples                  (:,:) double {mustBeNonempty}
end
arguments (Repeating)
    varargin
end

p = inputParser();
p.addParameter('Labels',    {});
p.addParameter('Truth',     []);
p.addParameter('Quantiles', [0.16, 0.5, 0.84]);
p.addParameter('Parent',    []);
p.parse(varargin{:});
opts = p.Results;

[N, P] = size(samples);
labels = opts.Labels;
if isempty(labels)
    labels = arrayfun(@(k) sprintf('p%d', k), 1:P, 'UniformOutput', false);
end

if isempty(opts.Parent)
    fig = figure('Name', sprintf('Corner plot — %d samples × %d params', N, P), ...
                 'NumberTitle', 'off');
else
    fig = opts.Parent;
    figure(fig); clf(fig);
end

t = tiledlayout(fig, P, P, 'TileSpacing', 'compact', 'Padding', 'compact');

for r = 1:P
    for c = 1:P
        ax = nexttile(t, (r - 1) * P + c);
        if c > r
            ax.Visible = 'off';
            continue;
        end
        if c == r
            histogram(ax, samples(:, r), 40, ...
                'Normalization', 'pdf', 'FaceAlpha', 0.6);
            hold(ax, 'on');
            % Quantile lines
            q = quantile(samples(:, r), opts.Quantiles);
            yl = ylim(ax);
            for qi = 1:numel(q)
                plot(ax, [q(qi) q(qi)], yl, 'k--', 'LineWidth', 0.6);
            end
            if ~isempty(opts.Truth) && numel(opts.Truth) >= r
                plot(ax, [opts.Truth(r) opts.Truth(r)], yl, 'r-', 'LineWidth', 1.2);
            end
        else
            scatter(ax, samples(:, c), samples(:, r), 3, ...
                [0.2 0.3 0.7], 'filled', 'MarkerFaceAlpha', 0.3);
            if ~isempty(opts.Truth) && numel(opts.Truth) >= max(r, c)
                hold(ax, 'on');
                plot(ax, opts.Truth(c), opts.Truth(r), 'r+', 'MarkerSize', 10, 'LineWidth', 1.5);
            end
        end
        if r == P
            xlabel(ax, labels{c}, 'Interpreter', 'none');
        else
            ax.XTickLabel = [];
        end
        if c == 1 && r > 1
            ylabel(ax, labels{r}, 'Interpreter', 'none');
        else
            if c ~= r, ax.YTickLabel = []; end
        end
    end
end

title(t, sprintf('Posterior samples (N = %d)', N));
end
