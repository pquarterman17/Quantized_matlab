function rgb = palette(name, n)
%PALETTE  Named colour palettes for the Plot Style dialog.
%
%   rgb = styles.palette(name)        % return all stops for the palette
%   rgb = styles.palette(name, n)     % interpolate / cycle to n rows
%
%   Returns an N×3 RGB matrix (values in [0,1]) suitable for assigning
%   to appearance.colors in the override cascade.  Passed through
%   bosonPlotter.resolveStyle without normalisation — the caller is
%   responsible for interpolating if they need a different N than
%   the palette ships with.
%
%   KNOWN NAMES:
%       'default'   — empty; keeps the template's own colour cycle
%       'tab10'     — matplotlib Tab10, 10 stops
%       'tableau10' — alias for tab10
%       'viridis'   — 8-stop perceptually-uniform sequential
%       'plasma'    — 8-stop perceptually-uniform sequential
%       'tol_bright'— Paul Tol bright qualitative, 7 stops, colour-blind safe
%       'tol_muted' — Paul Tol muted qualitative, 9 stops, colour-blind safe
%       'okabe_ito' — Okabe–Ito 8-colour palette, colour-blind safe
%       'aps'       — APS-like high-contrast 6 stops (blue/red/green/...)
%       'nature'    — Nature-like pastel 6 stops
%       'grayscale' — 5-stop grey ramp for monochrome reviewers
%
%   EXAMPLES:
%       styles.palette('tab10')
%       styles.palette('viridis', 12)      % interpolate to 12 stops
%       styles.palette('default')          % returns [] (no override)

    arguments
        name  {mustBeTextScalar}
        n     (1,1) double = 0
    end

    key = lower(strtrim(char(name)));

    switch key
        case {'default', 'template_default', ''}
            % 'template_default' is the dialog-side sentinel — kept as
            % a synonym for 'default' because the literal string
            % 'default' is a reserved MATLAB set() keyword and can't
            % be used as a uidropdown ItemsData value.
            rgb = [];
            return;

        case {'tab10', 'tableau10'}
            rgb = [ ...
                0.122 0.467 0.706;   % blue
                1.000 0.498 0.055;   % orange
                0.173 0.627 0.173;   % green
                0.839 0.153 0.157;   % red
                0.580 0.404 0.741;   % purple
                0.549 0.337 0.294;   % brown
                0.890 0.467 0.761;   % pink
                0.498 0.498 0.498;   % grey
                0.737 0.741 0.133;   % olive
                0.090 0.745 0.812 ]; % cyan

        case 'viridis'
            rgb = [ ...
                0.267 0.005 0.329;
                0.283 0.141 0.458;
                0.254 0.265 0.530;
                0.207 0.372 0.553;
                0.164 0.471 0.558;
                0.128 0.567 0.551;
                0.135 0.659 0.518;
                0.267 0.749 0.441;
                0.478 0.821 0.318;
                0.741 0.873 0.150;
                0.993 0.906 0.144 ];

        case 'plasma'
            rgb = [ ...
                0.050 0.030 0.528;
                0.281 0.010 0.624;
                0.472 0.008 0.648;
                0.636 0.103 0.610;
                0.768 0.215 0.524;
                0.871 0.332 0.427;
                0.953 0.460 0.332;
                0.991 0.596 0.247;
                0.994 0.745 0.180;
                0.951 0.903 0.147;
                0.940 0.975 0.131 ];

        case {'tol_bright', 'tolbright', 'paultol'}
            rgb = [ ...
                0.267 0.467 0.667;   % blue
                0.933 0.400 0.467;   % red
                0.133 0.733 0.533;   % green
                0.933 0.667 0.200;   % yellow
                0.400 0.600 0.867;   % cyan
                0.667 0.400 0.667;   % purple
                0.400 0.400 0.400 ]; % grey

        case {'tol_muted', 'tolmuted'}
            rgb = [ ...
                0.800 0.467 0.467;
                0.533 0.667 0.400;
                0.467 0.600 0.800;
                0.867 0.733 0.267;
                0.733 0.533 0.600;
                0.467 0.533 0.600;
                0.733 0.467 0.267;
                0.533 0.667 0.733;
                0.667 0.533 0.467 ];

        case {'okabe_ito', 'okabeito'}
            rgb = [ ...
                0.000 0.000 0.000;   % black
                0.902 0.624 0.000;   % orange
                0.337 0.706 0.914;   % sky blue
                0.000 0.620 0.451;   % bluish green
                0.941 0.894 0.259;   % yellow
                0.000 0.447 0.698;   % blue
                0.835 0.369 0.000;   % vermillion
                0.800 0.475 0.655 ]; % reddish purple

        case {'aps', 'aps_like'}
            rgb = [ ...
                0.000 0.447 0.741;
                0.850 0.325 0.098;
                0.929 0.694 0.125;
                0.494 0.184 0.556;
                0.466 0.674 0.188;
                0.635 0.078 0.184 ];

        case {'nature', 'nature_like'}
            rgb = [ ...
                0.231 0.443 0.631;
                0.871 0.318 0.318;
                0.424 0.682 0.392;
                0.949 0.698 0.282;
                0.549 0.424 0.647;
                0.600 0.600 0.600 ];

        case {'grayscale', 'gray', 'grey'}
            rgb = linspace(0.15, 0.75, 5)' * [1 1 1];

        otherwise
            error('styles:palette:unknown', ...
                'Unknown palette "%s".  Use styles.palette() with no args to see the list.', name);
    end

    % ── Optional resampling to n rows ──────────────────────────────
    if n > 0 && size(rgb, 1) > 0
        nSrc = size(rgb, 1);
        if n == nSrc
            return;
        end
        if nSrc == 1
            rgb = repmat(rgb, n, 1);
            return;
        end
        % Linear interpolation along each channel.  For sequential
        % palettes (viridis/plasma) this produces a smooth ramp; for
        % qualitative palettes (tab10/okabe_ito) it cycles naturally
        % when n <= nSrc and gently blends between stops when n > nSrc.
        if n <= nSrc
            idx = round(linspace(1, nSrc, n));
            rgb = rgb(idx, :);
        else
            xSrc = linspace(0, 1, nSrc);
            xDst = linspace(0, 1, n);
            rgb = [ ...
                interp1(xSrc, rgb(:,1), xDst, 'linear').', ...
                interp1(xSrc, rgb(:,2), xDst, 'linear').', ...
                interp1(xSrc, rgb(:,3), xDst, 'linear').' ];
        end
    end
end
