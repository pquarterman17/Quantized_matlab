function createSIMSFixture()
%CREATESIMSIXTURE  Generate synthetic SIMS fixture files for parser and GUI testing.
%
%   Creates sims_synthetic.xlsx and sims_synthetic.csv in the same directory
%   as this script.  The layout mirrors a common vendor SIMS export format:
%
%     Row  1 : lab / instrument info line
%     Row  2 : sample ID
%     Row  3 : date
%     Row  4 : "Drawn Curves", <N>
%     Row  5 : "Num of Cycles", <M>
%     Row  6 : blank separator
%     Row  7 : element names (H,  ,C,  ,O,  ,F,  ,N,  ,AL->,  ,Si->,  ,Ta->, )
%     Row  8 : column kind  (Depth, CONC., Depth, CONC., ...)
%     Row  9 : units        ((nm),(atoms/cc),(nm),(atoms/cc),...,(nm),(arb. units),...)
%     Row 10 : blank separator
%     Row 11+ : data (16 columns, each element owns one Depth + one CONC. column)
%
%   Physical scenario: 20 nm TaN film on a Si substrate.
%     H  — exponential surface contamination, decaying into bulk
%     C  — sharp surface spike, then low background
%     O  — surface spike + interface peak at ~20 nm
%     F  — trace, slight surface enrichment
%     N  — sigmoid box profile for the TaN layer (2-22 nm)
%     Al -> — film-related signal (arb. units), present in film, absent in substrate
%     Si -> — substrate signal (arb. units), rises sharply at ~22 nm
%     Ta -> — film signal (arb. units), drops at ~22 nm

    thisDir = fileparts(mfilename('fullpath'));
    nPts    = 50;   % cycles / depth points per element

    % ── Per-element depth vectors (slightly different start & step) ─────────
    % Real SIMS instruments measure each element at slightly different depths
    % because cycle time and sputtering rate drift between elements.
    depthH  = linspace(0.269,  25.10, nPts)';
    depthC  = linspace(0.317,  25.15, nPts)';
    depthO  = linspace(0.374,  25.20, nPts)';
    depthF  = linspace(0.479,  25.30, nPts)';
    depthN  = linspace(0.527,  25.35, nPts)';
    depthAl = linspace(0.033,  24.80, nPts)';
    depthSi = linspace(0.107,  24.90, nPts)';
    depthTa = linspace(0.456,  25.05, nPts)';

    % ── Concentration / signal profiles ─────────────────────────────────────
    % H: exponential surface decay + flat bulk background
    H_conc  = 5.0e21 .* exp(-depthH  ./ 3.0) + 8e20;

    % C: sharp monolayer-like spike at surface
    C_conc  = 3.5e20 .* exp(-depthC  ./ 0.6) + 2e18;

    % O: surface spike + interface accumulation at 20 nm
    O_conc  = 3.8e22 .* exp(-depthO  ./ 1.2) ...
            + 4.0e20 .* exp(-((depthO - 20.0).^2) ./ 2.0) ...
            + 1e18;

    % F: trace with slight surface enrichment
    F_conc  = 1.2e19 .* exp(-depthF  ./ 2.5) + 4e17;

    % N: sigmoid box profile — rises at 2 nm, falls at 22 nm (TaN layer)
    sig_on  = 1 ./ (1 + exp(-(depthN  -  2.0) ./ 0.5));
    sig_off = 1 ./ (1 + exp( (depthN  - 22.0) ./ 1.0));
    N_conc  = 8.5e20 .* sig_on .* sig_off + 2e17;

    % Al->  (arb. units): moderate level inside film, drops at substrate
    Al_on   = 1 ./ (1 + exp(-(depthAl -  1.0) ./ 0.4));
    Al_off  = 1 ./ (1 + exp( (depthAl - 22.0) ./ 1.2));
    Al_conc = 42.0 .* Al_on .* Al_off + 0.4;

    % Si->  (arb. units): substrate, rises sharply at ~22 nm
    Si_conc = 98.0 ./ (1 + exp(-(depthSi - 22.0) ./ 1.0)) + 0.1;

    % Ta->  (arb. units): film signal, decays at substrate
    Ta_conc = 88.0 ./ (1 + exp( (depthTa - 22.0) ./ 1.5)) + 0.3;

    % ── Assemble 16-column matrix ────────────────────────────────────────────
    dataMat = [depthH, H_conc, depthC, C_conc, depthO, O_conc, depthF, F_conc, ...
               depthN, N_conc, depthAl, Al_conc, depthSi, Si_conc, depthTa, Ta_conc];

    % ── Write XLSX ───────────────────────────────────────────────────────────
    xlsxFile = fullfile(thisDir, 'sims_synthetic.xlsx');

    emptyRow = {'','','','','','','','','','','','','','','',''};

    headerBlock = {
        'SIMS Test Lab Corp.','','','','','','','','','','','','','','','';
        ':Sample SYNTH-001 (Synthetic TaN/Si)','','','','','','','','','','','','','','','';
        datestr(now,'mm/dd/yyyy'),'','','','','','','','','','','','','','','';
        'Drawn Curves', 8,'','','','','','','','','','','','','','';
        'Num of Cycles', nPts,'','','','','','','','','','','','','','';
        emptyRow{:};
        'H','','C','','O','','F','','N','','AL->','','Si->','','Ta->','';
        'Depth','CONC.','Depth','CONC.','Depth','CONC.','Depth','CONC.','Depth','CONC.','Depth','CONC.','Depth','CONC.','Depth','CONC.';
        '(nm)','(atoms/cc)','(nm)','(atoms/cc)','(nm)','(atoms/cc)','(nm)','(atoms/cc)','(nm)','(atoms/cc)','(nm)','(arb. units)','(nm)','(arb. units)','(nm)','(arb. units)';
        emptyRow{:};
    };

    fullCell = [headerBlock; num2cell(dataMat)];
    writecell(fullCell, xlsxFile, 'Sheet', 1);

    % Add a "Plots" sheet (empty — many vendor SIMS exports include a second
    % tab with instrument-generated plots that can be ignored by the parser)
    writecell({'Plots sheet — for display only (ignored by parser)'}, ...
              xlsxFile, 'Sheet', 'Plots');

    fprintf('Written XLSX: %s\n', xlsxFile);

    % ── Write CSV ────────────────────────────────────────────────────────────
    csvFile = fullfile(thisDir, 'sims_synthetic.csv');
    fid = fopen(csvFile, 'w');
    assert(fid ~= -1, 'Cannot create: %s', csvFile);
    cleanFid = onCleanup(@() fclose(fid));

    fprintf(fid, 'SIMS Test Lab Corp.\n');
    fprintf(fid, ':Sample SYNTH-001 (Synthetic TaN/Si)\n');
    fprintf(fid, '%s\n', datestr(now,'mm/dd/yyyy'));
    fprintf(fid, 'Drawn Curves,%d\n', 8);
    fprintf(fid, 'Num of Cycles,%d\n', nPts);
    fprintf(fid, '\n');
    fprintf(fid, 'H,,C,,O,,F,,N,,AL->,,Si->,,Ta->\n');
    fprintf(fid, 'Depth,CONC.,Depth,CONC.,Depth,CONC.,Depth,CONC.,Depth,CONC.,Depth,CONC.,Depth,CONC.,Depth,CONC.\n');
    fprintf(fid, '(nm),(atoms/cc),(nm),(atoms/cc),(nm),(atoms/cc),(nm),(atoms/cc),(nm),(atoms/cc),(nm),(arb. units),(nm),(arb. units),(nm),(arb. units)\n');
    fprintf(fid, '\n');
    for k = 1:nPts
        fprintf(fid, '%.5f,%.6g,%.5f,%.6g,%.5f,%.6g,%.5f,%.6g,%.5f,%.6g,%.5f,%.6g,%.5f,%.6g,%.5f,%.6g\n', ...
                dataMat(k,:));
    end

    fprintf('Written CSV : %s\n', csvFile);
    fprintf('Done. Load either file in dataImportGUI to test SIMS plotting.\n');
end
