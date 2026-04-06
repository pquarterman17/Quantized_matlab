classdef peakTools
%PEAKTOOLS  Self-contained peak analysis dialogs extracted from Boson.
%
%   All methods open their own dialog figures and return result structs
%   that the caller can save back to the dataset.
%
%   Static methods:
%       result = peakTools.refineLattice(ds, wavelength_A, options)
%       result = peakTools.matchPhases(ds, wavelength_A, options)
%       result = peakTools.fftThickness(ds, wavelength_A, options)
%       result = peakTools.reflectivityFFT(ds, options)
%       result = peakTools.williamsonHall(ds, wavelength_A, kFactor, instBroadening_deg, options)

    methods (Static)

        % ════════════════════════════════════════════════════════════════
        %  LATTICE PARAMETER REFINEMENT
        % ════════════════════════════════════════════════════════════════

        function result = refineLattice(ds, wavelength_A, options)
        %REFINELATTICE  Open dialog to assign hkl and refine lattice parameters.
        %
        %   Syntax:
        %       result = boson.peakTools.refineLattice(ds, wavelength_A)
        %       result = boson.peakTools.refineLattice(ds, wavelength_A, Name, Value)
        %
        %   Inputs:
        %       ds           — dataset struct (must have .peaks with fitted peaks)
        %       wavelength_A — X-ray wavelength in Ångströms
        %
        %   Options:
        %       ParentFig   — figure handle for uialert (default: [])
        %       StatusFcn   — function_handle for status messages
        %       ButtonColors — struct with .primary, .fg fields
        %
        %   Outputs:
        %       result — struct with .system, .a (and .b, .c for non-cubic),
        %                .residuals, .hkl, .d_obs, .d_calc, .theta_rad (cubic)
        %                Empty [] if cancelled.
        %
        %   Example:
        %       r = boson.peakTools.refineLattice(ds, 1.5406);

            arguments
                ds              struct
                wavelength_A    double
                options.ParentFig               = []
                options.StatusFcn  function_handle = @(~) []
                options.ButtonColors struct = struct( ...
                    'primary', [0.18 0.52 0.18], ...
                    'fg',      [1 1 1])
            end

            BTN_PRIMARY = options.ButtonColors.primary;
            BTN_FG      = options.ButtonColors.fg;

            result = [];

            % ── Collect fitted peaks ─────────────────────────────────
            DEG2RAD  = pi / 180;
            fittedIdx = find(strcmp({ds.peaks.status}, 'fitted') | ...
                             strcmp({ds.peaks.status}, 'fitted(global)'));
            nPk = numel(fittedIdx);
            centers = [ds.peaks(fittedIdx).center];
            theta   = centers / 2 * DEG2RAD;
            d_obs   = wavelength_A ./ (2 * sin(theta));

            % ── Create dialog figure ─────────────────────────────────
            dlgFig = uifigure('Name', 'Lattice Parameter Refinement', ...
                'Position', [200 200 520 480], 'Resize', 'on');
            dlgGL = uigridlayout(dlgFig, [5 1], ...
                'RowHeight', {24, '1x', 28, 28, '0.6x'}, ...
                'Padding', [10 10 10 10], 'RowSpacing', 8);

            % Row 1: Crystal system selector
            sysGL = uigridlayout(dlgGL, [1 2], 'ColumnWidth', {120, '1x'}, ...
                'Padding', [0 0 0 0]);
            sysGL.Layout.Row = 1;
            uilabel(sysGL, 'Text', 'Crystal system:', 'FontWeight', 'bold');
            ddSystem = uidropdown(sysGL, ...
                'Items', {'Cubic', 'Tetragonal', 'Hexagonal', 'Orthorhombic'}, ...
                'Value', 'Cubic');

            % Row 2: hkl assignment table
            tblData = cell(nPk, 6);
            for i = 1:nPk
                tblData{i,1} = fittedIdx(i);
                tblData{i,2} = sprintf('%.4f', centers(i));
                tblData{i,3} = sprintf('%.4f', d_obs(i));
                tblData{i,4} = 0;   % h
                tblData{i,5} = 0;   % k
                tblData{i,6} = 0;   % l
            end
            hklTable = uitable(dlgGL, ...
                'ColumnName', {'Peak#', ['2' char(952) ' (' char(176) ')'], ...
                               'd (Å)', 'h', 'k', 'l'}, ...
                'ColumnWidth', {50, 75, 75, 55, 55, 55}, ...
                'ColumnEditable', [false false false true true true], ...
                'ColumnFormat', {'numeric','char','char','numeric','numeric','numeric'}, ...
                'Data', tblData, 'RowName', {});
            hklTable.Layout.Row = 2;

            % Row 3: Refine button
            btnRefine = uibutton(dlgGL, 'Text', 'Refine Lattice Parameters', ...
                'ButtonPushedFcn', @doRefine, ...
                'BackgroundColor', BTN_PRIMARY, 'FontColor', BTN_FG);
            btnRefine.Layout.Row = 3;

            % Row 4: Nelson-Riley plot button
            btnNR = uibutton(dlgGL, 'Text', 'Nelson-Riley Plot (cubic only)', ...
                'ButtonPushedFcn', @doNelsonRiley, 'Enable', 'off');
            btnNR.Layout.Row = 4;

            % Row 5: Results text area
            taResults = uitextarea(dlgGL, 'Value', {'Assign hkl indices and click Refine.'}, ...
                'Editable', false, 'FontName', 'Consolas');
            taResults.Layout.Row = 5;

            % ── Closure state ────────────────────────────────────────
            refinedResult = [];

            % ────────────────────────────────────────────────────────
            function doRefine(~, ~)
                tData  = hklTable.Data;
                h_arr  = cell2mat(tData(:,4));
                k_arr  = cell2mat(tData(:,5));
                l_arr  = cell2mat(tData(:,6));
                hklSum = abs(h_arr) + abs(k_arr) + abs(l_arr);
                valid  = hklSum > 0;
                if sum(valid) < 1
                    taResults.Value = {'Error: assign non-zero hkl to at least one peak.'};
                    return;
                end
                hv = h_arr(valid);  kv = k_arr(valid);  lv = l_arr(valid);
                dv = d_obs(valid);
                inv_d2 = (1 ./ dv.^2)';

                sys = ddSystem.Value;
                lines_out = {};
                switch sys
                    case 'Cubic'
                        a_each = dv' .* sqrt(hv.^2 + kv.^2 + lv.^2);
                        a_mean = mean(a_each);
                        a_std  = std(a_each);
                        A_mat  = hv.^2 + kv.^2 + lv.^2;
                        inv_a2 = A_mat \ inv_d2;
                        a_ls   = 1 / sqrt(inv_a2);
                        d_calc = a_ls ./ sqrt(hv.^2 + kv.^2 + lv.^2);
                        resid  = dv' - d_calc;
                        lines_out = {
                            sprintf('Crystal system: Cubic')
                            sprintf('Refined a = %.5f %s', a_ls, char(197))
                            sprintf('Mean a   = %.5f %s %s %.5f', a_mean, char(197), char(177), a_std)
                            ''
                            'Per-peak residuals (d_obs - d_calc):'
                        };
                        for ri = 1:numel(dv')
                            lines_out{end+1} = sprintf('  (%d%d%d)  d=%.4f  calc=%.4f  %s=%.4f', ...
                                hv(ri), kv(ri), lv(ri), dv(ri), d_calc(ri), char(916), resid(ri)); %#ok<AGROW>
                        end
                        refinedResult = struct('system','Cubic','a',a_ls,'residuals',resid, ...
                            'hkl',[hv kv lv],'d_obs',dv','d_calc',d_calc, ...
                            'theta_rad',theta(valid)');
                        btnNR.Enable = 'on';

                    case 'Tetragonal'
                        A_mat = [hv.^2+kv.^2, lv.^2];
                        if size(A_mat,1) < 2
                            taResults.Value = {'Error: tetragonal needs >= 2 peaks with hkl.'};
                            return;
                        end
                        x = A_mat \ inv_d2;
                        a_ref = 1/sqrt(x(1));  c_ref = 1/sqrt(x(2));
                        d_calc = 1 ./ sqrt(A_mat * x);
                        resid  = dv' - d_calc;
                        lines_out = {
                            sprintf('Crystal system: Tetragonal')
                            sprintf('Refined a = %.5f %s', a_ref, char(197))
                            sprintf('Refined c = %.5f %s', c_ref, char(197))
                            sprintf('c/a = %.5f', c_ref/a_ref)
                            ''
                            'Per-peak residuals:'
                        };
                        for ri = 1:numel(dv')
                            lines_out{end+1} = sprintf('  (%d%d%d)  d=%.4f  calc=%.4f  %s=%.4f', ...
                                hv(ri), kv(ri), lv(ri), dv(ri), d_calc(ri), char(916), resid(ri)); %#ok<AGROW>
                        end
                        refinedResult = struct('system','Tetragonal','a',a_ref,'c',c_ref, ...
                            'residuals',resid,'hkl',[hv kv lv],'d_obs',dv','d_calc',d_calc);
                        btnNR.Enable = 'off';

                    case 'Hexagonal'
                        A_mat = [(4/3)*(hv.^2 + hv.*kv + kv.^2), lv.^2];
                        if size(A_mat,1) < 2
                            taResults.Value = {'Error: hexagonal needs >= 2 peaks with hkl.'};
                            return;
                        end
                        x = A_mat \ inv_d2;
                        a_ref = 1/sqrt(x(1));  c_ref = 1/sqrt(x(2));
                        d_calc = 1 ./ sqrt(A_mat * x);
                        resid  = dv' - d_calc;
                        lines_out = {
                            sprintf('Crystal system: Hexagonal')
                            sprintf('Refined a = %.5f %s', a_ref, char(197))
                            sprintf('Refined c = %.5f %s', c_ref, char(197))
                            sprintf('c/a = %.5f', c_ref/a_ref)
                            ''
                            'Per-peak residuals:'
                        };
                        for ri = 1:numel(dv')
                            lines_out{end+1} = sprintf('  (%d%d%d)  d=%.4f  calc=%.4f  %s=%.4f', ...
                                hv(ri), kv(ri), lv(ri), dv(ri), d_calc(ri), char(916), resid(ri)); %#ok<AGROW>
                        end
                        refinedResult = struct('system','Hexagonal','a',a_ref,'c',c_ref, ...
                            'residuals',resid,'hkl',[hv kv lv],'d_obs',dv','d_calc',d_calc);
                        btnNR.Enable = 'off';

                    case 'Orthorhombic'
                        A_mat = [hv.^2, kv.^2, lv.^2];
                        if size(A_mat,1) < 3
                            taResults.Value = {'Error: orthorhombic needs >= 3 peaks with hkl.'};
                            return;
                        end
                        x = A_mat \ inv_d2;
                        a_ref = 1/sqrt(x(1));  b_ref = 1/sqrt(x(2));  c_ref = 1/sqrt(x(3));
                        d_calc = 1 ./ sqrt(A_mat * x);
                        resid  = dv' - d_calc;
                        lines_out = {
                            sprintf('Crystal system: Orthorhombic')
                            sprintf('Refined a = %.5f %s', a_ref, char(197))
                            sprintf('Refined b = %.5f %s', b_ref, char(197))
                            sprintf('Refined c = %.5f %s', c_ref, char(197))
                            ''
                            'Per-peak residuals:'
                        };
                        for ri = 1:numel(dv')
                            lines_out{end+1} = sprintf('  (%d%d%d)  d=%.4f  calc=%.4f  %s=%.4f', ...
                                hv(ri), kv(ri), lv(ri), dv(ri), d_calc(ri), char(916), resid(ri)); %#ok<AGROW>
                        end
                        refinedResult = struct('system','Orthorhombic','a',a_ref,'b',b_ref,'c',c_ref, ...
                            'residuals',resid,'hkl',[hv kv lv],'d_obs',dv','d_calc',d_calc);
                        btnNR.Enable = 'off';
                end

                rms = sqrt(mean(resid.^2));
                lines_out{end+1} = '';
                lines_out{end+1} = sprintf('RMS residual = %.6f %s', rms, char(197));
                taResults.Value = lines_out;

                % Return result to caller via output variable
                result = refinedResult;
                options.StatusFcn(sprintf('Lattice refined: %s system', refinedResult.system));
            end

            % ────────────────────────────────────────────────────────
            function doNelsonRiley(~, ~)
                if isempty(refinedResult) || ~strcmp(refinedResult.system, 'Cubic')
                    return;
                end
                th   = refinedResult.theta_rad;
                hkl  = refinedResult.hkl;
                dObs = refinedResult.d_obs;
                a_each = dObs .* sqrt(hkl(:,1).^2 + hkl(:,2).^2 + hkl(:,3).^2);
                NR     = cos(th).^2 ./ sin(th) + cos(th).^2 ./ th;
                p      = polyfit(NR, a_each, 1);
                a_extrap = p(2);
                NR_fit  = linspace(0, max(NR)*1.1, 100);
                a_fit   = polyval(p, NR_fit);

                nrFig = figure('Name', 'Nelson-Riley Extrapolation', ...
                    'NumberTitle', 'off', 'Position', [300 250 500 380]);
                nrAx = axes(nrFig);
                plot(nrAx, NR, a_each, 'ko', 'MarkerSize', 8, 'MarkerFaceColor', [0.2 0.5 0.8]);
                hold(nrAx, 'on');
                plot(nrAx, NR_fit, a_fit, 'r-', 'LineWidth', 1.5);
                plot(nrAx, 0, a_extrap, 'r^', 'MarkerSize', 12, 'MarkerFaceColor', 'r');
                hold(nrAx, 'off');
                xlabel(nrAx, ['cos' char(178) char(952) '/sin' char(952) ...
                    ' + cos' char(178) char(952) '/' char(952)]);
                ylabel(nrAx, ['a (' char(197) ')']);
                title(nrAx, sprintf('Nelson-Riley:  a_0 = %.5f %s (extrapolated)', ...
                    a_extrap, char(197)));
                grid(nrAx, 'on');  box(nrAx, 'on');
                legend(nrAx, 'Per-peak a', 'Linear fit', ...
                    sprintf('a_0 = %.5f', a_extrap), 'Location', 'best');
                for li = 1:numel(NR)
                    text(nrAx, NR(li), a_each(li), ...
                        sprintf(' (%d%d%d)', hkl(li,1), hkl(li,2), hkl(li,3)), ...
                        'FontSize', 8);
                end
            end

        end  % refineLattice

        % ════════════════════════════════════════════════════════════════
        %  PHASE IDENTIFICATION (PEAK DATABASE MATCHING)
        % ════════════════════════════════════════════════════════════════

        function matchPhases(ds, wavelength_A, options)
        %MATCHPHASES  Match detected peaks against built-in crystallographic database.
        %
        %   Syntax:
        %       boson.peakTools.matchPhases(ds, wavelength_A)
        %       boson.peakTools.matchPhases(ds, wavelength_A, Name, Value)
        %
        %   Inputs:
        %       ds           — dataset struct with .peaks
        %       wavelength_A — X-ray wavelength in Ångströms
        %
        %   Options:
        %       ParentFig   — figure handle for uialert
        %       StatusFcn   — function_handle for status messages
        %       MainAx      — main Boson axes handle for overlay
        %
        %   Example:
        %       boson.peakTools.matchPhases(ds, 1.5406, MainAx=ax);

            arguments
                ds              struct
                wavelength_A    double
                options.ParentFig               = []
                options.StatusFcn  function_handle = @(~) []
                options.MainAx                  = []
            end

            parentFig = options.ParentFig;
            ax        = options.MainAx;

            pks = ds.peaks;
            centers = [pks.center];
            centers = centers(~isnan(centers));

            try
                answer = inputdlg( ...
                    {['d-spacing tolerance (' char(197) '):'], ...
                     'Min. match fraction (0-1):'}, ...
                    'Phase Match Settings', [1 40], {'0.03', '0.3'});
                if isempty(answer), return; end
                tol     = str2double(answer{1});
                minFrac = str2double(answer{2});
                if isnan(tol) || isnan(minFrac)
                    if ~isempty(parentFig) && isvalid(parentFig)
                        uialert(parentFig, 'Invalid numeric input.', 'Error');
                    end
                    return;
                end

                matches = calc.crystal.matchPhases(centers(:), ...
                    Lambda=wavelength_A, Tolerance=tol, MinMatchFrac=minFrac);

                if isempty(matches)
                    if ~isempty(parentFig) && isvalid(parentFig)
                        uialert(parentFig, ...
                            sprintf('No phases matched with tolerance %.3f %s and min fraction %.0f%%.', ...
                                    tol, char(197), minFrac*100), ...
                            'No matches');
                    end
                    return;
                end

                % Build results display
                nShow = min(numel(matches), 10);
                lines = cell(nShow, 1);
                for mi = 1:nShow
                    m = matches(mi);
                    hklStr = strjoin(m.matchedHKL, ', ');
                    lines{mi} = sprintf('%d. %s  [%s]  —  %.0f%%  (%d/%d peaks)  hkl: %s', ...
                        mi, m.phaseName, m.formula, m.score*100, m.nMatched, m.nObserved, hklStr);
                end

                [sel, ok] = listdlg('ListString', lines, ...
                    'SelectionMode', 'multiple', ...
                    'ListSize', [550 300], ...
                    'PromptString', 'Select phase(s) to overlay on plot:', ...
                    'Name', 'Phase Match Results');
                if ~ok || isempty(sel), return; end

                % Overlay on main axes
                if ~isempty(ax) && isvalid(ax)
                    delete(findall(ax, 'Tag', 'GUIPhaseTickMark'));
                    delete(findall(ax, 'Tag', 'GUIPhaseLabel'));

                    phaseColors = [ ...
                        0.85 0.20 0.20;
                        0.20 0.50 0.80;
                        0.20 0.70 0.30;
                        0.80 0.50 0.10;
                        0.60 0.20 0.70;
                        0.10 0.70 0.70;
                        0.90 0.40 0.60;
                        0.50 0.50 0.20;
                        0.35 0.35 0.80;
                        0.80 0.30 0.30];

                    yLims    = ax.YLim;
                    tickBase = yLims(1);
                    tickTop  = tickBase + 0.08 * (yLims(2) - yLims(1));
                    labelY   = tickBase - 0.03 * (yLims(2) - yLims(1));

                    hold(ax, 'on');
                    for si = 1:numel(sel)
                        m   = matches(sel(si));
                        ci  = mod(si-1, size(phaseColors, 1)) + 1;
                        col = phaseColors(ci, :);

                        refTT  = m.allRefTwoTheta;
                        xRange = ax.XLim;
                        inView = refTT(refTT >= xRange(1) & refTT <= xRange(2) & ~isnan(refTT));

                        for ti = 1:numel(inView)
                            line(ax, [inView(ti), inView(ti)], [tickBase, tickTop], ...
                                'Color', col, 'LineWidth', 1.5, ...
                                'HandleVisibility', 'off', 'Tag', 'GUIPhaseTickMark');
                        end

                        if ~isempty(inView)
                            text(ax, xRange(1) + 0.01*(xRange(2)-xRange(1)), ...
                                 labelY - (si-1)*0.035*(yLims(2)-yLims(1)), ...
                                 sprintf('%s', m.phaseName), ...
                                 'Color', col, 'FontSize', 8, 'FontWeight', 'bold', ...
                                 'HandleVisibility', 'off', 'Tag', 'GUIPhaseLabel');
                        end
                    end
                end

                topMatch = matches(sel(1));
                options.StatusFcn(sprintf('Phase match: %s (%.0f%%) — %d phase(s) overlaid', ...
                    topMatch.phaseName, topMatch.score*100, numel(sel)));

            catch ME
                rethrow(ME);
            end
        end  % matchPhases

        % ════════════════════════════════════════════════════════════════
        %  FILM THICKNESS FROM LAUE FRINGES (FFT)
        % ════════════════════════════════════════════════════════════════

        function result = fftThickness(ds, wavelength_A, options)
        %FFTTHICKNESS  Compute film thickness from fringe periodicity via FFT.
        %
        %   Syntax:
        %       result = boson.peakTools.fftThickness(ds, wavelength_A)
        %       result = boson.peakTools.fftThickness(ds, wavelength_A, Name, Value)
        %
        %   Inputs:
        %       ds           — dataset struct
        %       wavelength_A — X-ray wavelength in Ångströms
        %
        %   Options:
        %       ParentFig    — figure for uialert
        %       StatusFcn    — status message callback
        %       ButtonColors — struct with .accent, .fg
        %       AxisLimits   — [xLo xHi] from main plot (default: [0 180])
        %
        %   Outputs:
        %       result — struct with .thickness_nm, .uncertainty_nm, .wavelength_A,
        %                .twoTheta_range, .fft_magnitude, .thickness_axis
        %                Empty [] if cancelled.
        %
        %   Example:
        %       r = boson.peakTools.fftThickness(ds, 1.5406, AxisLimits=[10 60]);

            arguments
                ds              struct
                wavelength_A    double
                options.ParentFig               = []
                options.StatusFcn  function_handle = @(~) []
                options.ButtonColors struct = struct( ...
                    'accent', [0.15 0.37 0.63], ...
                    'fg',     [1 1 1])
                options.AxisLimits  double = [0 180]
            end

            BTN_ACCENT = options.ButtonColors.accent;
            BTN_FG     = options.ButtonColors.fg;
            result     = [];

            % Get current data (corrected if available)
            d     = ptResolveData(ds);
            dmask = ptBuildDisplayMask(ds);
            xAll  = d.time(dmask);
            yAll  = d.values(dmask, 1);

            xLo = options.AxisLimits(1);
            xHi = options.AxisLimits(2);

            % ── Create dialog figure ─────────────────────────────────
            fftFig = uifigure('Name', 'FFT Film Thickness — Laue Fringes', ...
                'Position', [250 150 680 580], 'Resize', 'on');
            fftGL = uigridlayout(fftFig, [4 1], ...
                'RowHeight', {78, 30, '1x', 72}, ...
                'Padding', [10 10 10 10], 'RowSpacing', 8);

            % ── Row 1: Parameter controls ────────────────────────────
            paramPanel = uipanel(fftGL, 'Title', 'Parameters', 'FontSize', 11);
            paramPanel.Layout.Row = 1;
            paramGL = uigridlayout(paramPanel, [2 6], ...
                'ColumnWidth', {80, '1x', 80, '1x', 80, '1x'}, ...
                'RowHeight', {24, 24}, ...
                'Padding', [6 4 6 4], 'ColumnSpacing', 6, 'RowSpacing', 4);

            lbl1 = uilabel(paramGL, 'Text', ['2' char(952) ' min (' char(176) '):'], ...
                'FontWeight', 'bold');
            lbl1.Layout.Row = 1; lbl1.Layout.Column = 1;
            efFFTMin = uieditfield(paramGL, 'numeric', 'Value', xLo, 'Limits', [-10 180], ...
                'Tooltip', ['Lower bound of the 2' char(952) ' range for FFT analysis'], ...
                'ValueChangedFcn', @(~,~) doFFT([],[]));
            efFFTMin.Layout.Row = 1; efFFTMin.Layout.Column = 2;
            lbl2 = uilabel(paramGL, 'Text', ['2' char(952) ' max (' char(176) '):'], ...
                'FontWeight', 'bold');
            lbl2.Layout.Row = 1; lbl2.Layout.Column = 3;
            efFFTMax = uieditfield(paramGL, 'numeric', 'Value', xHi, 'Limits', [-10 180], ...
                'Tooltip', ['Upper bound of the 2' char(952) ' range for FFT analysis'], ...
                'ValueChangedFcn', @(~,~) doFFT([],[]));
            efFFTMax.Layout.Row = 1; efFFTMax.Layout.Column = 4;
            lbl3 = uilabel(paramGL, 'Text', 'Max t (nm):', 'FontWeight', 'bold');
            lbl3.Layout.Row = 1; lbl3.Layout.Column = 5;
            efMaxThick = uieditfield(paramGL, 'numeric', 'Value', 200, 'Limits', [1 10000], ...
                'Tooltip', 'Maximum thickness to display on the x-axis (nm)', ...
                'ValueChangedFcn', @(~,~) doFFT([],[]));
            efMaxThick.Layout.Row = 1; efMaxThick.Layout.Column = 6;

            lbl4 = uilabel(paramGL, 'Text', 'Window:', 'FontWeight', 'bold');
            lbl4.Layout.Row = 2; lbl4.Layout.Column = 1;
            ddWindow = uidropdown(paramGL, ...
                'Items', {'Hann', 'None', 'Blackman'}, 'Value', 'Hann', ...
                'Tooltip', ['Windowing function applied before FFT.' newline ...
                            'Hann reduces spectral leakage (recommended).'], ...
                'ValueChangedFcn', @(~,~) doFFT([],[]));
            ddWindow.Layout.Row = 2; ddWindow.Layout.Column = 2;
            btnCompute = uibutton(paramGL, 'Text', 'Compute FFT', ...
                'ButtonPushedFcn', @doFFT, ...
                'BackgroundColor', BTN_ACCENT, 'FontColor', BTN_FG, ...
                'FontWeight', 'bold');
            btnCompute.Layout.Row = 2; btnCompute.Layout.Column = [5 6];

            % ── Row 2: Wavelength info label ─────────────────────────
            lblWavelength = uilabel(fftGL, 'Text', ...
                sprintf('%s = %.5f %s', char(955), wavelength_A, char(197)), ...
                'FontSize', 11, 'FontColor', [0.4 0.4 0.4]);
            lblWavelength.Layout.Row = 2;

            % ── Row 3: Axes for FFT plot ─────────────────────────────
            fftAxPanel = uipanel(fftGL, 'BorderType', 'none');
            fftAxPanel.Layout.Row = 3;
            fftAx = axes(fftAxPanel);

            % ── Row 4: Results panel ─────────────────────────────────
            resultPanel = uipanel(fftGL, 'Title', 'Result', ...
                'FontSize', 11, 'FontWeight', 'bold');
            resultPanel.Layout.Row = 4;
            resultGL = uigridlayout(resultPanel, [2 4], ...
                'ColumnWidth', {90, '1x', 100, '1x'}, ...
                'RowHeight', {20, 20}, ...
                'Padding', [8 4 8 4], 'ColumnSpacing', 6, 'RowSpacing', 2);
            uilabel(resultGL, 'Text', 'Thickness:', 'FontWeight', 'bold', 'FontSize', 12);
            lblResThick = uilabel(resultGL, 'Text', '---', 'FontSize', 12);
            lblResThick.Layout.Row = 1; lblResThick.Layout.Column = 2;
            uilabel(resultGL, 'Text', 'Uncertainty:', 'FontWeight', 'bold', 'FontSize', 12);
            lblResUncert = uilabel(resultGL, 'Text', '---', 'FontSize', 12);
            lblResUncert.Layout.Row = 1; lblResUncert.Layout.Column = 4;
            uilabel(resultGL, 'Text', 'Range:', 'FontWeight', 'bold', ...
                'FontSize', 11, 'FontColor', [0.4 0.4 0.4]);
            lblResRange = uilabel(resultGL, 'Text', '---', 'FontSize', 11, ...
                'FontColor', [0.4 0.4 0.4]);
            lblResRange.Layout.Row = 2; lblResRange.Layout.Column = 2;
            uilabel(resultGL, 'Text', 'Data points:', 'FontWeight', 'bold', ...
                'FontSize', 11, 'FontColor', [0.4 0.4 0.4]);
            lblResNpts = uilabel(resultGL, 'Text', '---', 'FontSize', 11, ...
                'FontColor', [0.4 0.4 0.4]);
            lblResNpts.Layout.Row = 2; lblResNpts.Layout.Column = 4;

            % ────────────────────────────────────────────────────────
            function doFFT(~, ~)
                twoThMin = efFFTMin.Value;
                twoThMax = efFFTMax.Value;
                if twoThMin >= twoThMax
                    uialert(fftFig, 'Min must be less than Max.', 'Invalid range');
                    return;
                end

                mask = xAll >= twoThMin & xAll <= twoThMax;
                if sum(mask) < 10
                    uialert(fftFig, 'Too few data points in selected range (need >= 10).', ...
                        'Insufficient data');
                    return;
                end
                twoTh_sel = xAll(mask);
                I_sel     = yAll(mask);

                Q = (4 * pi / wavelength_A) * sin(twoTh_sel / 2 * pi / 180);

                nPts      = numel(Q);
                Q_uniform = linspace(min(Q), max(Q), nPts);
                I_uniform = interp1(Q, I_sel, Q_uniform, 'pchip');
                I_uniform = I_uniform - mean(I_uniform);

                N = numel(I_uniform);
                switch ddWindow.Value
                    case 'Hann'
                        w = 0.5 * (1 - cos(2*pi*(0:N-1)/(N-1)));
                    case 'Blackman'
                        w = 0.42 - 0.5*cos(2*pi*(0:N-1)/(N-1)) + 0.08*cos(4*pi*(0:N-1)/(N-1));
                    otherwise
                        w = ones(1, N);
                end
                I_windowed = I_uniform(:)' .* w;

                N_fft = 2^nextpow2(4 * N);
                F     = abs(fft(I_windowed, N_fft));
                F     = F(1:N_fft/2);

                dQ           = Q_uniform(2) - Q_uniform(1);
                thickness_A  = 2*pi*(0:N_fft/2-1) / (N_fft * dQ);
                thickness_nm = thickness_A / 10;

                searchMin = 4;
                maxT_nm   = efMaxThick.Value;
                searchMax = find(thickness_nm <= maxT_nm, 1, 'last');
                if isempty(searchMax) || searchMax < searchMin + 1
                    searchMax = numel(F);
                end
                [peakVal, peakIdx] = max(F(searchMin:searchMax));
                peakIdx = peakIdx + searchMin - 1;
                t_nm    = thickness_nm(peakIdx);

                halfMax  = peakVal / 2;
                leftIdx  = find(F(1:peakIdx) < halfMax, 1, 'last');
                rightIdx = peakIdx + find(F(peakIdx:end) < halfMax, 1, 'first') - 1;
                if ~isempty(leftIdx) && ~isempty(rightIdx)
                    fwhm_bins = rightIdx - leftIdx;
                    dt_nm = thickness_nm(min(peakIdx + ceil(fwhm_bins/2), numel(thickness_nm))) - ...
                            thickness_nm(max(peakIdx - ceil(fwhm_bins/2), 1));
                else
                    dt_nm = NaN;
                end

                cla(fftAx);
                plot(fftAx, thickness_nm(1:searchMax), F(1:searchMax), '-', ...
                    'Color', [0.2 0.4 0.7], 'LineWidth', 1.2);
                hold(fftAx, 'on');
                plot(fftAx, t_nm, peakVal, 'rv', 'MarkerSize', 12, 'MarkerFaceColor', 'r');
                hold(fftAx, 'off');
                xlabel(fftAx, 'Film thickness (nm)');
                ylabel(fftAx, 'FFT magnitude');
                title(fftAx, 'FFT Magnitude Spectrum');
                grid(fftAx, 'on');  box(fftAx, 'on');
                xlim(fftAx, [0 maxT_nm]);

                lblResThick.Text = sprintf('%.1f nm', t_nm);
                if ~isnan(dt_nm)
                    lblResUncert.Text = sprintf('%s %.1f nm (FWHM/2)', char(177), dt_nm/2);
                else
                    lblResUncert.Text = 'N/A (peak too broad)';
                end
                lblResRange.Text = sprintf(['%.2f' char(176) ' – %.2f' char(176) ...
                    ' 2' char(952)], twoThMin, twoThMax);
                lblResNpts.Text = sprintf('%d', sum(mask));

                % Update output result
                fftResult.thickness_nm    = t_nm;
                fftResult.uncertainty_nm  = ptTernary(isnan(dt_nm), NaN, dt_nm/2);
                fftResult.wavelength_A    = wavelength_A;
                fftResult.twoTheta_range  = [twoThMin twoThMax];
                fftResult.fft_magnitude   = F(1:searchMax);
                fftResult.thickness_axis  = thickness_nm(1:searchMax);
                result = fftResult;
            end

            % Auto-compute on open
            doFFT([], []);
        end  % fftThickness

        % ════════════════════════════════════════════════════════════════
        %  REFLECTIVITY FFT (KIESSIG FRINGES)
        % ════════════════════════════════════════════════════════════════

        function result = reflectivityFFT(ds, options)
        %REFLECTIVITYFFT  Compute film thickness from Kiessig fringe periodicity.
        %
        %   Supports neutron NR (Q-space) and XRR (2theta-space) data.
        %   Detects multiple FFT peaks for multilayer / superlattice structures.
        %   Preprocessing modes: log(R), log(R·Q⁴), R, R·Q⁴.
        %
        %   Syntax:
        %       result = boson.peakTools.reflectivityFFT(ds)
        %       result = boson.peakTools.reflectivityFFT(ds, Name, Value)
        %
        %   Inputs:
        %       ds — dataset struct (parserName used to detect neutron data)
        %
        %   Options:
        %       WavelengthA  — X-ray wavelength in Å (required for XRR; ignored for neutron)
        %       ParentFig    — figure for uialert
        %       StatusFcn    — status message callback
        %       ButtonColors — struct with .accent, .fg
        %       AxisLimits   — [xLo xHi] from main plot (default: [0 10])
        %       XraySources  — Nx2 cell array of {name, wavelength_A} (optional override)
        %
        %   Outputs:
        %       result — struct with .thicknesses_nm, .amplitudes, .harmonicLabels,
        %                .superlattice, .Q_range, .preprocess, .fft_magnitude,
        %                .thickness_axis, .isNeutron, and optionally .wavelength_A
        %
        %   Example:
        %       r = boson.peakTools.reflectivityFFT(ds, WavelengthA=1.5406);

            arguments
                ds              struct
                options.WavelengthA   double = NaN
                options.ParentFig               = []
                options.StatusFcn  function_handle = @(~) []
                options.ButtonColors struct = struct( ...
                    'accent', [0.15 0.37 0.63], ...
                    'fg',     [1 1 1])
                options.AxisLimits  double = [0 10]
                options.XraySources cell   = {}
            end

            BTN_ACCENT = options.ButtonColors.accent;
            BTN_FG     = options.ButtonColors.fg;
            result     = [];

            XRAY_SOURCES = ptXraySources();
            if ~isempty(options.XraySources)
                XRAY_SOURCES = options.XraySources;
            end

            isNeutronDS = isfield(ds, 'parserName') && ...
                ptIsNeutronParser(ds.parserName);
            wl_A = options.WavelengthA;

            % Get current data
            d     = ptResolveData(ds);
            dmask = ptBuildDisplayMask(ds);
            xAll  = d.time(dmask);
            yAll  = d.values(dmask, 1);

            xLo = options.AxisLimits(1);
            xHi = options.AxisLimits(2);

            % ── Dialog figure ────────────────────────────────────────
            rfFig = uifigure('Name', 'Reflectivity FFT — Kiessig Thickness', ...
                'Position', [200 150 780 720], 'Resize', 'on');
            rfGL = uigridlayout(rfFig, [5 1], ...
                'RowHeight', {80, 28, '2x', 80, '1x'}, ...
                'Padding', [10 10 10 10], 'RowSpacing', 6);

            % ── Row 1: Controls ──────────────────────────────────────
            ctrlGL = uigridlayout(rfGL, [3 6], ...
                'ColumnWidth', {80, '1x', 80, '1x', 90, '1x'}, ...
                'RowHeight', {24, 24, 24}, ...
                'Padding', [0 0 0 0], 'ColumnSpacing', 6, 'RowSpacing', 4);
            ctrlGL.Layout.Row = 1;

            if isNeutronDS
                xLabel    = ['Q min (' char(197) char(8315) char(185) '):'];
                xMaxLabel = ['Q max (' char(197) char(8315) char(185) '):'];
            else
                xLabel    = ['2' char(952) ' min (' char(176) '):'];
                xMaxLabel = ['2' char(952) ' max (' char(176) '):'];
            end
            lblRFXMin = uilabel(ctrlGL, 'Text', xLabel, 'FontWeight', 'bold');
            lblRFXMin.Layout.Row = 1; lblRFXMin.Layout.Column = 1;
            efRFMin = uieditfield(ctrlGL, 'numeric', 'Value', max(0, xLo), 'Limits', [-10 180]);
            efRFMin.Layout.Row = 1; efRFMin.Layout.Column = 2;
            lblRFXMax = uilabel(ctrlGL, 'Text', xMaxLabel, 'FontWeight', 'bold');
            lblRFXMax.Layout.Row = 1; lblRFXMax.Layout.Column = 3;
            efRFMax = uieditfield(ctrlGL, 'numeric', 'Value', xHi, 'Limits', [-10 180]);
            efRFMax.Layout.Row = 1; efRFMax.Layout.Column = 4;
            lblRFMaxT = uilabel(ctrlGL, 'Text', 'Max t (nm):', 'FontWeight', 'bold');
            lblRFMaxT.Layout.Row = 1; lblRFMaxT.Layout.Column = 5;
            efRFMaxThick = uieditfield(ctrlGL, 'numeric', 'Value', 500, 'Limits', [1 100000], ...
                'Tooltip', 'Maximum thickness to show on x-axis (nm)');
            efRFMaxThick.Layout.Row = 1; efRFMaxThick.Layout.Column = 6;

            lblRFWin = uilabel(ctrlGL, 'Text', 'Window:', 'FontWeight', 'bold');
            lblRFWin.Layout.Row = 2; lblRFWin.Layout.Column = 1;
            ddRFWindow = uidropdown(ctrlGL, ...
                'Items', {'Hann', 'None', 'Blackman'}, 'Value', 'Hann', ...
                'Tooltip', 'Windowing function applied before FFT (Hann reduces spectral leakage)');
            ddRFWindow.Layout.Row = 2; ddRFWindow.Layout.Column = 2;
            lblRFPrep = uilabel(ctrlGL, 'Text', 'Preprocess:', 'FontWeight', 'bold');
            lblRFPrep.Layout.Row = 2; lblRFPrep.Layout.Column = 3;
            ddRFPreprocess = uidropdown(ctrlGL, ...
                'Items', {'log(R)', ['log(R' char(183) 'Q' char(8308) ')'], ...
                          'R', ['R' char(183) 'Q' char(8308)]}, ...
                'Value', 'log(R)', ...
                'Tooltip', ['Preprocessing applied before FFT:' newline ...
                            '  log(R) — log-scale; equalises fringe visibility across Q (default)' newline ...
                            '  log(R' char(183) 'Q' char(8308) ') — Fresnel-corrected log' newline ...
                            '  R — raw linear reflectivity' newline ...
                            '  R' char(183) 'Q' char(8308) ' — Fresnel-corrected linear']);
            ddRFPreprocess.Layout.Row = 2; ddRFPreprocess.Layout.Column = 4;
            lblRFPeakThr = uilabel(ctrlGL, 'Text', 'Peak thr.:', 'FontWeight', 'bold', ...
                'Tooltip', ['Minimum peak prominence as a fraction of the strongest peak.' newline ...
                            'Lower = more peaks detected.  0.05 = 5% of max.']);
            lblRFPeakThr.Layout.Row = 2; lblRFPeakThr.Layout.Column = 5;
            efRFPeakThr = uieditfield(ctrlGL, 'numeric', ...
                'Value', 0.05, 'Limits', [0.001 1], ...
                'Tooltip', 'Minimum prominence threshold (fraction of max peak). Lower → more peaks.');
            efRFPeakThr.Layout.Row = 2; efRFPeakThr.Layout.Column = 6;

            % Row 3: wavelength controls (XRR) or empty (neutron)
            efRFWavelength = [];
            if ~isNeutronDS
                row3GL = uigridlayout(ctrlGL, [1 6], ...
                    'ColumnWidth', {55, 80, 55, '1x', 20, 100}, ...
                    'Padding', [0 0 0 0], 'ColumnSpacing', 4, 'RowSpacing', 0);
                row3GL.Layout.Row = 3; row3GL.Layout.Column = [1 6];
                uilabel(row3GL, 'Text', [char(955) ' (' char(197) '):'], 'FontSize', 10);
                efRFWavelength = uieditfield(row3GL, 'numeric', 'Value', wl_A, 'Limits', [0 Inf], ...
                    'Tooltip', 'X-ray wavelength in Å for 2θ → Q conversion');
                efRFWavelength.Layout.Row = 1; efRFWavelength.Layout.Column = 2;
                lblRFSrc2 = uilabel(row3GL, 'Text', 'Source:', 'FontSize', 10, ...
                    'HorizontalAlignment', 'right');
                lblRFSrc2.Layout.Row = 1; lblRFSrc2.Layout.Column = 3;
                ddRFSource = uidropdown(row3GL, ...
                    'Items', XRAY_SOURCES(:,1)', ...
                    'Value', XRAY_SOURCES{1,1}, 'FontSize', 9, ...
                    'Tooltip', 'Select X-ray source to auto-fill wavelength', ...
                    'ValueChangedFcn', @(s,~) syncWavelengthFromSource( ...
                        s.Value, XRAY_SOURCES, efRFWavelength));
                ddRFSource.Layout.Row = 1; ddRFSource.Layout.Column = 4;
                rfSrcMatch = find(abs([XRAY_SOURCES{:,2}] - wl_A) < 1e-4, 1);
                if ~isempty(rfSrcMatch)
                    ddRFSource.Value = XRAY_SOURCES{rfSrcMatch, 1};
                end
            end

            % ── Row 2: Compute button ────────────────────────────────
            btnRFCompute = uibutton(rfGL, 'Text', 'Compute FFT', ...
                'ButtonPushedFcn', @doReflFFT, ...
                'BackgroundColor', BTN_ACCENT, 'FontColor', BTN_FG);
            btnRFCompute.Layout.Row = 2;

            % ── Row 3: FFT plot ──────────────────────────────────────
            rfAxPanel = uipanel(rfGL, 'BorderType', 'none');
            rfAxPanel.Layout.Row = 3;
            rfAx = axes(rfAxPanel);

            % ── Row 4: Superlattice summary panel ────────────────────
            slPanel = uipanel(rfGL, 'Title', 'Superlattice Analysis', 'FontSize', 11);
            slPanel.Layout.Row = 4;
            slGL = uigridlayout(slPanel, [3 2], ...
                'ColumnWidth', {'1x', '1x'}, ...
                'RowHeight', {20, 18, 18}, ...
                'Padding', [6 2 6 2], 'ColumnSpacing', 12, 'RowSpacing', 2);
            lblSLStatus = uilabel(slGL, 'Text', 'No superlattice pattern detected', ...
                'FontWeight', 'bold', 'FontColor', [0.4 0.4 0.4]);
            lblSLStatus.Layout.Row = 1; lblSLStatus.Layout.Column = [1 2];
            lblSLBilayer = uilabel(slGL, 'Text', '', 'FontSize', 10);
            lblSLBilayer.Layout.Row = 2; lblSLBilayer.Layout.Column = 1;
            lblSLTotal = uilabel(slGL, 'Text', '', 'FontSize', 10);
            lblSLTotal.Layout.Row = 2; lblSLTotal.Layout.Column = 2;
            lblSLSublayers = uilabel(slGL, 'Text', '', 'FontSize', 10);
            lblSLSublayers.Layout.Row = 3; lblSLSublayers.Layout.Column = [1 2];

            % ── Row 5: Peak results table ────────────────────────────
            rfTblPanel = uipanel(rfGL, 'Title', 'Detected Thickness Peaks', 'FontSize', 11);
            rfTblPanel.Layout.Row = 5;
            rfTblGL = uigridlayout(rfTblPanel, [1 1], 'Padding', [4 4 4 4]);
            rfPeakTable = uitable(rfTblGL, ...
                'ColumnName',  {'#', 'Thickness (nm)', 'Amplitude', 'Rel (%)', 'Interpretation'}, ...
                'ColumnWidth', {30, 110, 80, 60, 120}, ...
                'Data',        {}, ...
                'RowName',     {});

            % Auto-compute on open
            doReflFFT([], []);

            % ────────────────────────────────────────────────────────
            function doReflFFT(~, ~)
                xMin = efRFMin.Value;
                xMax = efRFMax.Value;
                if xMin >= xMax
                    rfPeakTable.Data = {};
                    title(rfAx, 'Error: min must be less than max');
                    return;
                end

                mask = xAll >= xMin & xAll <= xMax;
                if sum(mask) < 10
                    rfPeakTable.Data = {};
                    title(rfAx, 'Too few points in range (need >= 10)');
                    return;
                end
                x_sel = xAll(mask);
                R_sel = yAll(mask);

                % Convert x to Q (Å⁻¹)
                if isNeutronDS
                    Q = x_sel;
                else
                    curWL = efRFWavelength.Value;
                    if isnan(curWL) || curWL <= 0
                        rfPeakTable.Data = {};
                        title(rfAx, 'Wavelength required for XRR mode');
                        return;
                    end
                    Q = (4 * pi / curWL) .* sin(x_sel / 2 * pi / 180);
                end

                % ── Preprocessing ────────────────────────────────────
                prepMode = ddRFPreprocess.Value;
                useQ4    = contains(prepMode, 'Q');
                useLog   = startsWith(prepMode, 'log');

                R_proc = R_sel;
                if useQ4
                    Q_safe = max(Q, 1e-6);
                    R_proc = R_proc .* Q_safe.^4;
                end
                if useLog
                    R_proc = log10(max(R_proc, 1e-30));
                end

                % ── Interpolate to uniform Q grid ─────────────────────
                nPts      = numel(Q);
                Q_uniform = linspace(min(Q), max(Q), nPts);
                R_uniform = interp1(Q, R_proc, Q_uniform, 'pchip');

                p_trend   = polyfit(Q_uniform(:), R_uniform(:), 1);
                R_uniform = R_uniform - polyval(p_trend, Q_uniform);

                % ── Apply window function ─────────────────────────────
                N = numel(R_uniform);
                switch ddRFWindow.Value
                    case 'Hann'
                        w = 0.5 * (1 - cos(2*pi*(0:N-1)/(N-1)));
                    case 'Blackman'
                        w = 0.42 - 0.5*cos(2*pi*(0:N-1)/(N-1)) + ...
                            0.08*cos(4*pi*(0:N-1)/(N-1));
                    otherwise
                        w = ones(1, N);
                end
                R_windowed = R_uniform(:)' .* w;

                % ── Zero-padded FFT ────────────────────────────────────
                N_fft = 2^nextpow2(4 * N);
                F     = abs(fft(R_windowed, N_fft));
                F     = F(1:N_fft/2);

                dQ           = Q_uniform(2) - Q_uniform(1);
                thickness_A  = 2*pi*(0:N_fft/2-1) / (N_fft * dQ);
                thickness_nm = thickness_A / 10;

                % ── Restrict search range ──────────────────────────────
                searchMin = 4;
                maxT_nm   = efRFMaxThick.Value;
                searchMax = find(thickness_nm <= maxT_nm, 1, 'last');
                if isempty(searchMax) || searchMax < searchMin + 1
                    searchMax = numel(F);
                end
                F_search = F(searchMin:searchMax);
                t_search = thickness_nm(searchMin:searchMax);

                % ── Multi-peak detection ───────────────────────────────
                nS = numel(F_search);
                isLocalMax = false(1, nS);
                for ki = 2:nS-1
                    isLocalMax(ki) = F_search(ki) > F_search(ki-1) && ...
                                     F_search(ki) > F_search(ki+1);
                end
                maxIdxRel = find(isLocalMax);
                if isempty(maxIdxRel)
                    [~, maxIdxRel] = max(F_search);
                end

                pkAmps   = F_search(maxIdxRel);
                pkThick  = t_search(maxIdxRel);
                pkAbsIdx = maxIdxRel + searchMin - 1; %#ok<NASGU>

                % Filter by prominence
                prominences = zeros(size(pkAmps));
                for pi2 = 1:numel(pkAmps)
                    idx      = maxIdxRel(pi2);
                    leftMin  = min(F_search(1:idx));
                    rightMin = min(F_search(idx:end));
                    prominences(pi2) = pkAmps(pi2) - max(leftMin, rightMin);
                end
                promThresh = efRFPeakThr.Value * max(prominences);
                keep     = prominences > promThresh;
                pkAmps   = pkAmps(keep);
                pkThick  = pkThick(keep);
                prominences = prominences(keep); %#ok<NASGU>

                [pkAmps, sortOrd] = sort(pkAmps, 'descend');
                pkThick = pkThick(sortOrd);

                maxPeaks = 20;
                if numel(pkAmps) > maxPeaks
                    pkAmps  = pkAmps(1:maxPeaks);
                    pkThick = pkThick(1:maxPeaks);
                end

                % ── Superlattice detection ─────────────────────────────
                nPk           = numel(pkThick);
                interpLabels  = cell(nPk, 1);
                for hi = 1:nPk, interpLabels{hi} = ''; end

                slDetected         = false;
                slLambda_nm        = NaN;
                slTotal_nm         = NaN;
                slNRepeats         = NaN;
                slSubA_nm          = NaN;
                slSubB_nm          = NaN;
                slSuppressedOrders = [];

                if nPk >= 2
                    [tAsc, ~]   = sort(pkThick, 'ascend');
                    nCandidates = min(5, nPk);
                    bestScore   = 0;
                    bestLambda  = NaN;
                    harmTol     = 0.08;

                    for ci = 1:nCandidates
                        Lambda_cand = tAsc(ci);
                        score = 0;
                        for pk = 1:nPk
                            ratio = pkThick(pk) / Lambda_cand;
                            nr    = round(ratio);
                            if nr >= 1 && abs(ratio - nr) / nr < harmTol
                                score = score + 1;
                            end
                        end
                        if score > bestScore
                            bestScore  = score;
                            bestLambda = Lambda_cand;
                        end
                    end

                    if bestScore >= 3
                        slDetected  = true;
                        slLambda_nm = bestLambda;

                        nMax = 1;
                        for pk = 1:nPk
                            ratio = pkThick(pk) / slLambda_nm;
                            nr    = round(ratio);
                            if nr >= 1 && abs(ratio - nr) / nr < harmTol
                                if nr > nMax, nMax = nr; end
                            end
                        end

                        nSub = 0;
                        for pk = 1:nPk
                            t = pkThick(pk);
                            if t > 1.15 * slLambda_nm && t < 1.85 * slLambda_nm
                                ratio = t / slLambda_nm;
                                nr    = round(ratio);
                                if ~(nr == 2 && abs(ratio - 2) / 2 < harmTol)
                                    nSub = nSub + 1;
                                end
                            end
                        end

                        if nSub > 0
                            slNRepeats = nSub + 2;
                        else
                            slNRepeats = nMax;
                        end
                        slTotal_nm = slNRepeats * slLambda_nm;

                        for ord = 2:min(6, max(nMax, 3))
                            expectedT = ord * slLambda_nm;
                            found = false;
                            for pk = 1:nPk
                                if abs(pkThick(pk) - expectedT) / expectedT < harmTol
                                    found = true;
                                    break;
                                end
                            end
                            if ~found
                                slSuppressedOrders(end+1) = ord; %#ok<AGROW>
                            end
                        end

                        if ~isempty(slSuppressedOrders)
                            firstMissing = slSuppressedOrders(1);
                            slSubA_nm    = slLambda_nm / firstMissing;
                            slSubB_nm    = slLambda_nm - slSubA_nm;
                        end

                        bilayerPeakAssigned = false;
                        for pk = 1:nPk
                            t     = pkThick(pk);
                            ratio = t / slLambda_nm;
                            nr    = round(ratio);
                            isSLHarm = (nr >= 1) && (abs(ratio - nr) / nr < harmTol);

                            if isSLHarm && nr == 1 && ~bilayerPeakAssigned
                                interpLabels{pk}    = ['Bilayer ' char(923)];
                                bilayerPeakAssigned = true;
                            elseif isSLHarm && nr >= 2
                                interpLabels{pk} = sprintf('SL order %d', nr);
                            elseif t > 1.15 * slLambda_nm && t < 1.85 * slLambda_nm
                                ratio2 = t / slLambda_nm;
                                nr2    = round(ratio2);
                                if ~(nr2 == 2 && abs(ratio2 - 2) / 2 < harmTol)
                                    interpLabels{pk} = 'Satellite';
                                end
                            else
                                interpLabels{pk} = 'Independent';
                            end
                        end
                    end
                end

                % ── Update superlattice summary ────────────────────────
                if slDetected
                    lblSLStatus.Text      = sprintf(['Superlattice detected  ' char(8212) ...
                        '  [A/B]%s%d'], char(215), slNRepeats);
                    lblSLStatus.FontColor = [0.10 0.45 0.10];
                    lblSLBilayer.Text     = sprintf(['Bilayer period ' char(923) ' = %.2f nm'], ...
                        slLambda_nm);
                    lblSLTotal.Text       = sprintf('Total thickness D = %.1f nm  (%d repeats)', ...
                        slTotal_nm, slNRepeats);
                    if ~isnan(slSubA_nm)
                        lblSLSublayers.Text = sprintf( ...
                            ['Estimated sublayers: d_A ' char(8776) ' %.2f nm,  ' ...
                             'd_B ' char(8776) ' %.2f nm  ' ...
                             '(suppressed order %d)'], ...
                            slSubA_nm, slSubB_nm, slSuppressedOrders(1));
                    else
                        lblSLSublayers.Text = 'd_A, d_B indeterminate (no suppressed orders)';
                    end
                else
                    lblSLStatus.Text      = 'No superlattice pattern detected';
                    lblSLStatus.FontColor = [0.4 0.4 0.4];
                    lblSLBilayer.Text     = '';
                    lblSLTotal.Text       = '';
                    lblSLSublayers.Text   = '';
                end

                % ── Plot FFT spectrum with peak markers ────────────────
                cla(rfAx);
                plot(rfAx, t_search, F_search, '-', ...
                    'Color', [0.20 0.45 0.55], 'LineWidth', 1.2);
                hold(rfAx, 'on');

                COL_BILAYER = [0.12 0.47 0.71];
                COL_SLHARM  = [0.85 0.15 0.15];
                COL_SAT     = [0.00 0.68 0.75];
                COL_INDEP   = [0.90 0.50 0.00];
                COL_DEFAULT = [0.85 0.15 0.15];

                peakColors = repmat(COL_DEFAULT, nPk, 1);
                for ci = 1:nPk
                    lbl = interpLabels{ci};
                    if startsWith(lbl, 'Bilayer')
                        peakColors(ci,:) = COL_BILAYER;
                    elseif startsWith(lbl, 'SL order')
                        peakColors(ci,:) = COL_SLHARM;
                    elseif strcmp(lbl, 'Satellite')
                        peakColors(ci,:) = COL_SAT;
                    elseif strcmp(lbl, 'Independent')
                        peakColors(ci,:) = COL_INDEP;
                    end
                end

                for mi = 1:nPk
                    plot(rfAx, pkThick(mi), pkAmps(mi), 'v', ...
                        'MarkerSize', 10, 'MarkerFaceColor', peakColors(mi,:), ...
                        'MarkerEdgeColor', peakColors(mi,:));
                    if startsWith(interpLabels{mi}, 'Bilayer')
                        lblTxt = sprintf('%s\n%.1f nm', char(923), pkThick(mi));
                        text(rfAx, pkThick(mi), pkAmps(mi) * 1.06, lblTxt, ...
                            'HorizontalAlignment', 'center', 'FontSize', 8, ...
                            'FontWeight', 'bold', 'Color', peakColors(mi,:));
                    else
                        text(rfAx, pkThick(mi), pkAmps(mi) * 1.06, ...
                            sprintf('%.1f', pkThick(mi)), ...
                            'HorizontalAlignment', 'center', 'FontSize', 8, ...
                            'Color', peakColors(mi,:));
                    end
                end
                hold(rfAx, 'off');
                xlabel(rfAx, 'Film thickness (nm)');
                ylabel(rfAx, 'FFT magnitude');
                grid(rfAx, 'on');  box(rfAx, 'on');
                xlim(rfAx, [0 maxT_nm]);
                if nPk >= 1
                    title(rfAx, sprintf('%d peaks detected  —  strongest: %.1f nm', ...
                        nPk, pkThick(1)));
                else
                    title(rfAx, 'No peaks detected');
                end

                % ── Fill peak results table ────────────────────────────
                relPct  = 100 * pkAmps / max(pkAmps);
                tblData = cell(nPk, 5);
                for ti = 1:nPk
                    tblData{ti,1} = ti;
                    tblData{ti,2} = round(pkThick(ti), 2);
                    tblData{ti,3} = round(pkAmps(ti), 4);
                    tblData{ti,4} = round(relPct(ti), 1);
                    tblData{ti,5} = interpLabels{ti};
                end
                rfPeakTable.Data = tblData;

                % ── Build and return result ────────────────────────────
                rfResult.thicknesses_nm = pkThick(:);
                rfResult.amplitudes     = pkAmps(:);
                rfResult.harmonicLabels = interpLabels;
                rfResult.Q_range        = [min(Q) max(Q)];
                rfResult.preprocess     = prepMode;
                rfResult.fft_magnitude  = F_search(:);
                rfResult.thickness_axis = t_search(:);
                rfResult.isNeutron      = isNeutronDS;
                if ~isNeutronDS && ~isempty(efRFWavelength)
                    rfResult.wavelength_A = efRFWavelength.Value;
                end
                rfResult.superlattice.detected           = slDetected;
                rfResult.superlattice.bilayerPeriod_nm   = slLambda_nm;
                rfResult.superlattice.totalThickness_nm  = slTotal_nm;
                rfResult.superlattice.nRepeats           = slNRepeats;
                rfResult.superlattice.sublayerA_nm       = slSubA_nm;
                rfResult.superlattice.sublayerB_nm       = slSubB_nm;
                rfResult.superlattice.suppressedOrders   = slSuppressedOrders;
                result = rfResult;
            end

        end  % reflectivityFFT

        % ════════════════════════════════════════════════════════════════
        %  WILLIAMSON-HALL STRAIN ANALYSIS
        % ════════════════════════════════════════════════════════════════

        function result = williamsonHall(ds, wavelength_A, kFactor, instBroadening_deg, options)
        %WILLIAMSONHALL  Williamson-Hall analysis: βcosθ vs 4sinθ.
        %
        %   Linear fit: βcosθ = Kλ/D + 4εsinθ
        %   Intercept → crystallite size D.  Slope → microstrain ε.
        %
        %   Syntax:
        %       result = boson.peakTools.williamsonHall(ds, wavelength_A, kFactor, instBroadening_deg)
        %       result = boson.peakTools.williamsonHall(..., Name, Value)
        %
        %   Inputs:
        %       ds                  — dataset struct with .peaks
        %       wavelength_A        — X-ray wavelength in Ångströms
        %       kFactor             — Scherrer shape factor (typically 0.9)
        %       instBroadening_deg  — instrument broadening in degrees (subtracted in quadrature)
        %
        %   Options:
        %       ParentFig  — figure for uialert
        %       StatusFcn  — status message callback
        %
        %   Outputs:
        %       result — struct with .D_nm, .epsilon, .R2, .slope, .intercept,
        %                .xWH, .yWH, .K, .wavelength_A, .instBroadening_deg
        %                Empty [] if insufficient peaks.
        %
        %   Example:
        %       r = boson.peakTools.williamsonHall(ds, 1.5406, 0.9, 0);

            arguments
                ds                  struct
                wavelength_A        double
                kFactor             double
                instBroadening_deg  double
                options.ParentFig               = []
                options.StatusFcn  function_handle = @(~) []
            end

            result = [];

            DEG2RAD  = pi / 180;
            K        = kFactor;
            inst_rad = instBroadening_deg * DEG2RAD;

            validIdx = [];
            for pki = 1:numel(ds.peaks)
                pk      = ds.peaks(pki);
                isFitted = strcmp(pk.status,'fitted') || strcmp(pk.status,'fitted(global)');
                hasFWHM  = ~isnan(pk.fwhm) && pk.fwhm > 0;
                if isFitted && hasFWHM
                    beta_meas = pk.fwhm * DEG2RAD;
                    beta_sq   = beta_meas^2 - inst_rad^2;
                    if beta_sq > 0
                        validIdx(end+1) = pki; %#ok<AGROW>
                    end
                end
            end
            if numel(validIdx) < 3
                if ~isempty(options.ParentFig) && isvalid(options.ParentFig)
                    uialert(options.ParentFig, ...
                        sprintf('Williamson-Hall needs %s 3 fitted peaks with valid FWHM.\nCurrently have %d.', ...
                            char(8805), numel(validIdx)), ...
                        'Insufficient peaks');
                end
                return;
            end

            % ── Compute W-H data ─────────────────────────────────────
            nWH        = numel(validIdx);
            sinTh      = zeros(nWH, 1);
            betaCos    = zeros(nWH, 1);
            peakLabels = cell(nWH, 1);
            for wi = 1:nWH
                pk        = ds.peaks(validIdx(wi));
                theta_rad = (pk.center / 2) * DEG2RAD;
                beta_meas = pk.fwhm * DEG2RAD;
                beta_corr = sqrt(beta_meas^2 - inst_rad^2);
                sinTh(wi)   = sin(theta_rad);
                betaCos(wi) = beta_corr * cos(theta_rad);
                peakLabels{wi} = sprintf('%.2f%s', pk.center, char(176));
            end
            xWH = 4 * sinTh;
            yWH = betaCos;

            % ── Linear fit: yWH = slope·xWH + intercept ──────────────
            p         = polyfit(xWH, yWH, 1);
            slope     = p(1);
            intercept = p(2);

            if intercept > 0
                D_nm = (K * wavelength_A * 0.1) / intercept;
            else
                D_nm = NaN;
            end
            epsilon = slope;

            yFit   = polyval(p, xWH);
            SS_res = sum((yWH - yFit).^2);
            SS_tot = sum((yWH - mean(yWH)).^2);
            R2     = 1 - SS_res / SS_tot;

            % ── Plot ──────────────────────────────────────────────────
            whFig = figure('Name', 'Williamson-Hall Plot', ...
                'NumberTitle', 'off', 'Position', [300 220 540 400]);
            whAx = axes(whFig);
            plot(whAx, xWH, yWH, 'ko', 'MarkerSize', 8, 'MarkerFaceColor', [0.2 0.5 0.8]);
            hold(whAx, 'on');
            xFitLine = linspace(0, max(xWH)*1.15, 100);
            yFitLine = polyval(p, xFitLine);
            plot(whAx, xFitLine, yFitLine, 'r-', 'LineWidth', 1.5);
            hold(whAx, 'off');

            xlabel(whAx, ['4' char(183) 'sin(' char(952) ')']);
            ylabel(whAx, [char(946) char(183) 'cos(' char(952) ')  (rad)']);
            if ~isnan(D_nm)
                title(whAx, sprintf('D = %.1f nm,  %s = %.2e,  R%s = %.4f', ...
                    D_nm, char(949), epsilon, char(178), R2));
            else
                title(whAx, sprintf('%s = %.2e,  R%s = %.4f  (negative intercept)', ...
                    char(949), epsilon, char(178), R2));
            end
            grid(whAx, 'on');  box(whAx, 'on');
            legend(whAx, 'Peak data', sprintf('%s%scos%s = %.2e%s4sin%s + %.4e', ...
                char(946), char(183), char(952), epsilon, char(183), char(952), intercept), ...
                'Location', 'best');

            for li = 1:nWH
                text(whAx, xWH(li), yWH(li), ['  ' peakLabels{li}], 'FontSize', 8);
            end

            result = struct( ...
                'D_nm',               D_nm, ...
                'epsilon',            epsilon, ...
                'R2',                 R2, ...
                'slope',              slope, ...
                'intercept',          intercept, ...
                'xWH',                xWH, ...
                'yWH',                yWH, ...
                'K',                  K, ...
                'wavelength_A',       wavelength_A, ...
                'instBroadening_deg', instBroadening_deg);

            options.StatusFcn(sprintf('Williamson-Hall: D=%.1f nm, %s=%.2e', ...
                D_nm, char(949), epsilon));
        end  % williamsonHall

    end  % methods (Static)
end  % classdef peakTools


% ════════════════════════════════════════════════════════════════════════
%  File-level helpers (private to this file)
% ════════════════════════════════════════════════════════════════════════

% ════════════════════════════════════════════════════════════════════════
%  File-level helper functions (private to this file)
%  Note: MATLAB permits only one classdef per .m file.  These functions
%  are called as ptResolveData(), ptBuildDisplayMask(), etc. within the
%  static methods above via the local aliases set at the top of each method.
% ════════════════════════════════════════════════════════════════════════

function d = ptResolveData(ds)
%PTRESOLVEDATA  Return corrected data if available, else raw data.
    if ~isempty(ds.corrData)
        d = ds.corrData;
    else
        d = ds.data;
    end
end

function dmask = ptBuildDisplayMask(ds)
%PTBUILDDISPLAYMASK  Logical mask aligned to corrected/displayed data.
    if ~isfield(ds, 'mask') || isempty(ds.mask) || all(ds.mask)
        d     = ptResolveData(ds);
        dmask = true(size(d.time));
        return;
    end
    if ~isempty(ds.corrData)
        nRaw  = numel(ds.data.time);
        keepM = true(nRaw, 1);
        if ~isdatetime(ds.data.time)
            tVM     = double(ds.data.time);
            trimMin = ptGetField(ds, 'xTrimMin', NaN);
            trimMax = ptGetField(ds, 'xTrimMax', NaN);
            if ~isnan(trimMin), keepM = keepM & tVM >= trimMin; end
            if ~isnan(trimMax), keepM = keepM & tVM <= trimMax; end
        end
        dmask = ds.mask(keepM);
    else
        dmask = ds.mask;
    end
end

function v = ptGetField(s, name, default)
%PTGETFIELD  Return s.name if it exists, else default.
    if isfield(s, name)
        v = s.(name);
    else
        v = default;
    end
end

function v = ptTernary(cond, a, b)
%PTTERNARY  Return a if cond is true, else b.
    if cond, v = a; else, v = b; end
end

function tf = ptIsNeutronParser(pName)
%PTISNEUTRONPARSER  True when pName is an NCNR neutron reflectometry parser.
    tf = ismember(pName, {'importNCNRDat', 'importNCNRRefl', 'importNCNRPNR'});
end

function src = ptXraySources()
%PTXRAYSOURCES  Standard X-ray source table: {name, wavelength_A}.
    src = { ...
        ['Cu K' char(945) '1 (1.5406 ' char(197) ')'],   1.5406; ...
        ['Cu K' char(945) '2 (1.5444 ' char(197) ')'],   1.5444; ...
        ['Cu K' char(945) ' avg (1.5418 ' char(197) ')'],1.5418; ...
        ['Mo K' char(945) '1 (0.7093 ' char(197) ')'],   0.7093; ...
        ['Co K' char(945) '1 (1.7889 ' char(197) ')'],   1.7889; ...
        ['Cr K' char(945) '1 (2.2909 ' char(197) ')'],   2.2909; ...
        ['Fe K' char(945) '1 (1.9373 ' char(197) ')'],   1.9373; ...
        ['Ag K' char(945) '1 (0.5594 ' char(197) ')'],   0.5594; ...
        'Custom',                                          NaN};
end

function syncWavelengthFromSource(srcName, XRAY_SOURCES, efWavelength)
%SYNCWAVELENGTHFROMSOURCE  Update wavelength field when source dropdown changes.
    idx = find(strcmp(XRAY_SOURCES(:,1), srcName), 1);
    if ~isempty(idx) && ~isnan(XRAY_SOURCES{idx,2})
        efWavelength.Value = XRAY_SOURCES{idx,2};
    end
end
