function [data, parserName] = guiImport(fp)
%GUIIMPORT  Dispatch to the correct parser with GUI-specific parameters.
%
%   [data, parserName] = bosonPlotter.guiImport(fp)
%
%   Uses centralized resolveParser for extension→parser mapping, then
%   calls each parser with GUI-appropriate options (e.g. 'all' channels
%   for magnetometry, 'counts' for XRDML).

    resolveResult = parser.resolveParser(fp);
    parserName = resolveResult.name;

    switch parserName
        case 'importRigaku_raw'
            data = parser.importRigaku_raw(fp);

        case 'importXRDML'
            data = parser.importXRDML(fp, Intensity='counts');

        case 'importBruker'
            data = parser.importBruker(fp);

        case 'importExcel'
            data = parser.importExcel(fp);

        case 'importCSV'
            data = parser.importCSV(fp);

        case 'importSIMS'
            data = parser.importSIMS(fp);

        case 'importNCNRRefl'
            data = parser.importNCNRRefl(fp);

        case 'importNCNRPNR'
            data = parser.importNCNRPNR(fp);

        case 'importNCNRDat'
            data = parser.importNCNRDat(fp);

        case 'importRefl1dDat'
            data = parser.importRefl1dDat(fp);

        case 'importQDVSM'
            try
                data = parser.importQDVSM(fp, 'Verbose', false, 'YAxis', 'all');
            catch ME
                if contains(ME.message,'[Data]','IgnoreCase',true)
                    data = parser.importPPMS(fp, 'YAxis', 'all');
                    parserName = 'importPPMS';
                else
                    rethrow(ME);
                end
            end

        case 'importPPMS'
            data = parser.importPPMS(fp, 'YAxis', 'all');

        case 'importLakeShore'
            data = parser.importLakeShore(fp, 'YAxis', 'all');

        case 'importMPMS'
            data = parser.importMPMS(fp, 'YAxis', 'all');

        case 'importImage'
            data = parser.importImage(fp);

        case 'importBCF'
            data = parser.importBCF(fp);

        case 'importDM3'
            data = parser.importDM3(fp);

        case 'importDM4'
            data = parser.importDM4(fp);

        case 'importAFM'
            data = parser.importAFM(fp);

        otherwise
            [~, ~, ext] = fileparts(fp);
            error('BosonPlotter:unknownExt', ...
                ['No parser for extension "%s" (resolved as "%s").\n' ...
                 'Supported: .raw, .xrdml, .brml, .xlsx/.xls/.xlsm/.xlsb/.ods, ' ...
                 '.csv/.tsv/.txt, .refl, .pnr, .datA/B/C/D, .dat, ' ...
                 '.jpg/.jpeg/.png/.bmp/.gif, .bcf, .dm3, .dm4'], ...
                lower(ext), parserName);
    end
end
