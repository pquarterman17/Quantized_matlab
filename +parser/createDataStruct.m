function data = createDataStruct(timeVec, valuesMatrix, varargin)
%CREATEDATASTRUCT  Build the standard toolbox data struct.
%
%   data = createDataStruct(timeVec, valuesMatrix, ...
%               'labels', labels, 'units', units, 'metadata', meta)
%
%   All name-value pairs are optional.
%
%   OUTPUT fields:
%       .time     - [Nx1] x-axis / independent variable
%       .values   - [NxM] data matrix  (N samples, M channels)
%       .labels   - {1xM} channel name strings
%       .units    - {1xM} unit strings
%       .metadata - struct of import metadata

    p = inputParser();
    p.addParameter('labels',   {});
    p.addParameter('units',    {});
    p.addParameter('metadata', struct());
    p.parse(varargin{:});

    M      = size(valuesMatrix, 2);
    labels = p.Results.labels;
    units  = p.Results.units;

    if isempty(labels)
        labels = arrayfun(@(k) sprintf('ch%d', k), 1:M, 'UniformOutput', false);
    end
    if isempty(units)
        units = repmat({''}, 1, M);
    end

    data.time     = timeVec;
    data.values   = valuesMatrix;
    data.labels   = labels;
    data.units    = units;
    data.metadata = p.Results.metadata;
end
