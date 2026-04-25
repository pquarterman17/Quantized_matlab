function onAsymmetryToggle(appData, ui, callbacks)
%ONASYMMETRYTOGGLE  Handle the spin-asymmetry checkbox state change.
%
% Syntax
%   bosonPlotter.onAsymmetryToggle(appData, ui, callbacks)
%
% Asymmetry calculations require DAT files (not PNR), so toggling the
% checkbox swaps PNR-dataset visibility and forces linear-Y scale.
% Toggling off restores both. The "previous Y scale" is cached on
% appData.asymmetryPrevLogY so the linear-mode flip is reversible.
%
% Inputs
%   appData   - bosonPlotter.AppState handle (mutates datasets[].hiddenForAsymmetry,
%               asymmetryPrevLogY)
%   ui        - widget struct with:
%                 .cbCalculateAsymmetry  (logical)
%                 .ddScaleY              (sets Value to 'Log' / 'Linear')
%   callbacks - struct with:
%                 .onPlot()  — re-render after toggling state

    if ui.cbCalculateAsymmetry.Value
        % Enabled: cache prior log state and force linear scale
        if ~isprop(appData, 'asymmetryPrevLogY')
            appData.asymmetryPrevLogY = strcmp(ui.ddScaleY.Value, 'Log');
        end
        ui.ddScaleY.Value = 'Linear';

        for i = 1:numel(appData.datasets)
            if strcmp(appData.datasets{i}.parserName, 'importNCNRPNR')
                if ~isfield(appData.datasets{i}, 'hiddenForAsymmetry')
                    appData.datasets{i}.hiddenForAsymmetry = false;
                end
                appData.datasets{i}.hiddenForAsymmetry = true;
            end
        end
    else
        % Disabled: restore PNR visibility and prior Y-scale
        for i = 1:numel(appData.datasets)
            if isfield(appData.datasets{i}, 'hiddenForAsymmetry') && ...
                    appData.datasets{i}.hiddenForAsymmetry
                appData.datasets{i}.hiddenForAsymmetry = false;
            end
        end

        if isprop(appData, 'asymmetryPrevLogY')
            if appData.asymmetryPrevLogY
                ui.ddScaleY.Value = 'Log';
            else
                ui.ddScaleY.Value = 'Linear';
            end
        end
    end

    callbacks.onPlot();
end
