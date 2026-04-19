function asymData = computeAsymmetryForExport(ds, appData, callbacks)
%COMPUTEASYMMETRYFOREXPORT  Compute spin asymmetry for CSV export.
%
% Syntax
%   asymData = bosonPlotter.computeAsymmetryForExport(ds, appData, callbacks)
%
% Behaviour
%   Returns a struct with .headers and .values when the active dataset
%   is neutron data with a paired ++ / −− partner; returns an empty
%   struct otherwise.  The linear asymmetry (R++ − R−−)/(R++ + R−−) and
%   its propagated error are always computed.  When both partners
%   carry a "theory" or "model" column, an Asymmetry_theory column is
%   appended.
%
% Inputs
%   ds        - Active dataset struct (reads data, parserName, corrData)
%   appData   - bosonPlotter.AppState handle (reads datasets / activeIdx)
%   callbacks - Struct of function handles:
%                 .findPolarizationPairs(datasets) -> pairMap cell array
%
% Output
%   asymData  - struct with fields .headers (cell) and .values (matrix)

    asymData = struct('headers', {{}}, 'values', []);

    if ~isfield(ds, 'parserName') || ~isNeutronParser(ds.parserName)
        return;
    end
    if ~isfield(ds.data.metadata, 'parserSpecific') || ...
       ~isfield(ds.data.metadata.parserSpecific, 'polarization')
        return;
    end
    pol = ds.data.metadata.parserSpecific.polarization;
    if ~strcmp(pol, '++') && ~strcmp(pol, '--')
        return;
    end

    % Find paired dataset
    pairMap = callbacks.findPolarizationPairs(appData.datasets);
    myIdx = find(cellfun(@(c) ~isempty(c) && any(c == appData.activeIdx), pairMap), 1);
    if isempty(myIdx), return; end
    pair = pairMap{myIdx};
    idxPP = pair(1);  idxMM = pair(2);

    dsPP = appData.datasets{idxPP};
    dsMM = appData.datasets{idxMM};
    primaryPP = guiTernary(~isempty(dsPP.corrData), dsPP.corrData, dsPP.data);
    primaryMM = guiTernary(~isempty(dsMM.corrData), dsMM.corrData, dsMM.data);

    iRPP = find(strcmp(primaryPP.labels, 'R'), 1);
    iRMM = find(strcmp(primaryMM.labels, 'R'), 1);
    if isempty(iRPP) || isempty(iRMM), return; end

    RPP = primaryPP.values(:, iRPP);
    RMM = primaryMM.values(:, iRMM);

    idRPP = find(strcmp(primaryPP.labels, 'dR'), 1);
    idRMM = find(strcmp(primaryMM.labels, 'dR'), 1);
    dRPP = guiTernary(~isempty(idRPP), primaryPP.values(:, idRPP), zeros(size(RPP)));
    dRMM = guiTernary(~isempty(idRMM), primaryMM.values(:, idRMM), zeros(size(RMM)));

    % Linear asymmetry: (R++ - R--) / (R++ + R--)
    valid = RPP > 0 & RMM > 0 & ~isnan(RPP) & ~isnan(RMM);
    asymVal = NaN(size(RPP));
    asymErr = NaN(size(RPP));
    sumR = RPP + RMM;
    asymVal(valid) = (RPP(valid) - RMM(valid)) ./ sumR(valid);
    dA_dRPP = 2 * RMM(valid) ./ (sumR(valid).^2);
    dA_dRMM = -2 * RPP(valid) ./ (sumR(valid).^2);
    asymErr(valid) = sqrt((dA_dRPP .* dRPP(valid)).^2 + (dA_dRMM .* dRMM(valid)).^2);

    headers = {'Asymmetry', 'dAsymmetry'};
    vals = [asymVal, asymErr];

    % Theory asymmetry (if both datasets have theory columns)
    iThPP = find(strcmpi(primaryPP.labels, 'theory'), 1);
    if isempty(iThPP), iThPP = find(strcmpi(primaryPP.labels, 'model'), 1); end
    iThMM = find(strcmpi(primaryMM.labels, 'theory'), 1);
    if isempty(iThMM), iThMM = find(strcmpi(primaryMM.labels, 'model'), 1); end

    if ~isempty(iThPP) && ~isempty(iThMM)
        thPP = primaryPP.values(:, iThPP);
        thMM = primaryMM.values(:, iThMM);
        validTh = thPP > 0 & thMM > 0 & ~isnan(thPP) & ~isnan(thMM);
        asymTheory = NaN(size(thPP));
        sumTh = thPP + thMM;
        asymTheory(validTh) = (thPP(validTh) - thMM(validTh)) ./ sumTh(validTh);
        headers{end+1} = 'Asymmetry_theory';
        vals = [vals, asymTheory];
    end

    asymData.headers = headers;
    asymData.values  = vals;
end

% ════════════════════════════════════════════════════════════════════════
% Local helpers (duplicated from BosonPlotter.m module-level scope)
% ════════════════════════════════════════════════════════════════════════

function v = guiTernary(cond, a, b)
    if cond, v = a; else, v = b; end
end

function tf = isNeutronParser(pName)
    tf = ismember(pName, {'importNCNRDat', 'importNCNRRefl', 'importNCNRPNR'});
end
