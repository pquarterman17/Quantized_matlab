function exportHDF5(appData, fig, logGUIErrorFcn)
%EXPORTHDF5  Export the active dataset to HDF5 via a browse-and-save dialog.
%
%   bosonPlotter.exportHDF5(appData, fig, logGUIErrorFcn)

    if isempty(appData.datasets) || appData.activeIdx < 1
        bosonPlotter.quietAlert(fig, 'Load a file first.', 'No data');
        return;
    end
    ds = appData.datasets{appData.activeIdx};
    [~, fn, ~] = fileparts(ds.filepath);
    defName    = fullfile(fileparts(ds.filepath), [fn, '.h5']);
    [fname, fpath] = uiputfile( ...
        {'*.h5','HDF5 files (*.h5)'; '*.hdf5','HDF5 files (*.hdf5)'}, ...
        'Export to HDF5 as...', defName);
    if isequal(fname, 0), return; end
    outPath = fullfile(fpath, fname);
    try
        utilities.exportHDF5(ds.data, outPath, ...
            'CorrData',    ds.corrData, ...
            'Corrections', struct('xOff', ds.xOff, 'yOff', ds.yOff, ...
                                  'bgSlope', ds.bgSlope, 'bgInt', ds.bgInt), ...
            'IncludePeaks', ~isempty(ds.peaks), ...
            'Peaks',        ds.peaks);
        bosonPlotter.quietAlert(fig, sprintf('Saved:\n%s', outPath), 'HDF5 Exported');
    catch ME
        fprintf(2, '\n[BosonPlotter] HDF5 export error: %s\n', ME.message);
        for si = 1:numel(ME.stack)
            fprintf(2, '  at %s  (line %d)\n', ME.stack(si).name, ME.stack(si).line);
        end
        logGUIErrorFcn('Export error', ME.message, ME);
        bosonPlotter.quietAlert(fig, ME.message, 'Export error');
    end
end
