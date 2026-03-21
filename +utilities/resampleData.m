function dataOut = resampleData(dataIn, options)
%RESAMPLEDATA  Resample a data struct onto a new x-grid.
%
%   dataOut = utilities.resampleData(dataIn, NPoints=500)
%   dataOut = utilities.resampleData(dataIn, Step=0.01)
%   dataOut = utilities.resampleData(dataIn, Grid=newX)
%   dataOut = utilities.resampleData(dataIn, MatchDataset=otherData)
%
%   Interpolates all value columns of a unified data struct onto a new
%   x-grid (time axis).  Useful for comparing datasets measured on
%   different grids, or for uniform resampling before FFT.
%
%   Inputs:
%       dataIn — unified data struct with .time, .values, .labels, .units, .metadata
%
%   Options (specify exactly one grid mode):
%       NPoints      — resample to N uniformly spaced points (default: 500)
%       Step         — resample with uniform step size in x-units
%       Grid         — [M×1] custom x-grid vector
%       MatchDataset — another data struct; use its .time as the grid
%       Method       — interpolation method: 'linear' | 'pchip' | 'spline' | 'makima'
%                      (default: 'makima')
%       Extrapolate  — allow extrapolation beyond input range (default: false)
%                      If false, out-of-range values are NaN.
%
%   Output:
%       dataOut — new data struct with resampled .time and .values
%                 (.labels, .units, .metadata preserved from input)
%
%   Examples:
%       % Uniform 1000-point resampling
%       d2 = utilities.resampleData(data, NPoints=1000);
%
%       % Match another dataset's grid for subtraction
%       dA = utilities.resampleData(dataA, MatchDataset=dataB);
%       diff = dA.values - dataB.values;
%
%       % Custom grid with cubic spline
%       xNew = linspace(10, 80, 500)';
%       d2 = utilities.resampleData(data, Grid=xNew, Method='spline');
%
%   See also utilities.datasetAlgebra, interp1

arguments
    dataIn         struct
    options.NPoints      double = []
    options.Step         double = []
    options.Grid         (:,1) double = []
    options.MatchDataset        = []
    options.Method  (1,1) string {mustBeMember(options.Method, ...
        ["linear","pchip","spline","makima"])} = "makima"
    options.Extrapolate (1,1) logical = false
end

% Validate input struct
if ~isfield(dataIn, 'time') || ~isfield(dataIn, 'values')
    error('utilities:resampleData:badStruct', ...
        'Input must be a data struct with .time and .values fields.');
end

xOld = dataIn.time(:);
yOld = dataIn.values;
N = numel(xOld);

if N < 2
    error('utilities:resampleData:tooFew', 'Need at least 2 data points.');
end

% ════════════════════════════════════════════════════════════════════════
% Determine new x-grid
% ════════════════════════════════════════════════════════════════════════

nModes = ~isempty(options.NPoints) + ~isempty(options.Step) + ...
    ~isempty(options.Grid) + ~isempty(options.MatchDataset);

if nModes == 0
    % Default: 500 uniform points
    xNew = linspace(min(xOld), max(xOld), 500)';
elseif nModes > 1
    error('utilities:resampleData:multiMode', ...
        'Specify only one of: NPoints, Step, Grid, MatchDataset.');
elseif ~isempty(options.NPoints)
    xNew = linspace(min(xOld), max(xOld), options.NPoints)';
elseif ~isempty(options.Step)
    xNew = (min(xOld) : options.Step : max(xOld))';
elseif ~isempty(options.Grid)
    xNew = options.Grid(:);
elseif ~isempty(options.MatchDataset)
    ref = options.MatchDataset;
    if isstruct(ref) && isfield(ref, 'time')
        xNew = ref.time(:);
    else
        error('utilities:resampleData:badRef', ...
            'MatchDataset must be a data struct with .time field.');
    end
end

% ════════════════════════════════════════════════════════════════════════
% Interpolate
% ════════════════════════════════════════════════════════════════════════

method = char(options.Method);
nCols = size(yOld, 2);
yNew = zeros(numel(xNew), nCols);

if options.Extrapolate
    extrapVal = 'extrap';
else
    extrapVal = NaN;
end

for c = 1:nCols
    yNew(:, c) = interp1(xOld, yOld(:, c), xNew, method, extrapVal);
end

% ════════════════════════════════════════════════════════════════════════
% Build output struct (preserve metadata)
% ════════════════════════════════════════════════════════════════════════

dataOut = dataIn;
dataOut.time   = xNew;
dataOut.values = yNew;

% Update metadata to note resampling
if isfield(dataOut, 'metadata')
    dataOut.metadata.resampled = true;
    dataOut.metadata.resampleMethod = method;
    dataOut.metadata.resamplePoints = numel(xNew);
end

end
