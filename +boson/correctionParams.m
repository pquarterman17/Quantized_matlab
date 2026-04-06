function params = correctionParams(ds, uiValues)
%CORRECTIONPARAMS  Build a correction params struct from dataset + UI values.
%
%   params = boson.correctionParams(ds, uiValues)
%
%   Constructs the params struct expected by boson.applyCorrections
%   from a dataset struct and a struct of current UI widget values.
%
%   Inputs:
%       ds          Dataset struct from appData.datasets{idx}
%       uiValues    Struct with fields read from GUI widgets:
%                     .xOff, .yOff, .bgSlope, .bgInt — correction values
%                     .xTrimMin, .xTrimMax — crop range (NaN = no trim)
%                     .smoothEnabled, .smoothWindow, .smoothMethod
%                     .normMethod, .derivativeMode
%                     .fieldUnit, .momentUnit — magnetometry units
%                     .sampleMass, .sampleVolume — sample geometry
%
%   Output:
%       params      Struct suitable for boson.applyCorrections
%
%   See also: boson.applyCorrections

arguments
    ds       struct
    uiValues struct
end

params = struct();

% Core correction values
params.xOff       = uiValues.xOff;
params.yOff       = uiValues.yOff;
params.bgSlope    = uiValues.bgSlope;
params.bgInt      = uiValues.bgInt;

% Polynomial background (from dataset, not UI)
if isfield(ds, 'bgPoly')
    params.bgPoly = ds.bgPoly;
end

% Trim range
params.xTrimMin = uiValues.xTrimMin;
params.xTrimMax = uiValues.xTrimMax;

% Smoothing
params.smoothEnabled = uiValues.smoothEnabled;
params.smoothWindow  = uiValues.smoothWindow;
params.smoothMethod  = uiValues.smoothMethod;

% Normalization and derivative
params.normMethod     = uiValues.normMethod;
params.derivativeMode = uiValues.derivativeMode;

% Parser type flags
parserName = '';
if isfield(ds, 'parserName'), parserName = ds.parserName; end
params.isNeutron = ismember(parserName, ...
    {'importNCNRRefl', 'importNCNRPNR', 'importNCNRDat'});
params.isMag = ismember(parserName, ...
    {'importQDVSM', 'importPPMS', 'importMPMS', 'importLakeShore'});

% Magnetometry parameters
if params.isMag
    params.fieldUnit    = uiValues.fieldUnit;
    params.momentUnit   = uiValues.momentUnit;
    if isfield(uiValues, 'sampleMass'),   params.sampleMass   = uiValues.sampleMass;   end
    if isfield(uiValues, 'sampleVolume'), params.sampleVolume = uiValues.sampleVolume; end
end

end
