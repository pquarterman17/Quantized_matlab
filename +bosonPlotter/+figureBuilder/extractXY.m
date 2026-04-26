function [xv, yv, xLbl, yLbl] = extractXY(ds, yChannel)
%EXTRACTXY  Pull (x, y, labels) from a dataset for a given Y channel name.
%   Uses corrData when present, otherwise data. Returns empty vectors if
%   the channel is not found. xLbl / yLbl come from metadata + the
%   channel name respectively.
    if isfield(ds, 'corrData') && ~isempty(ds.corrData) && ...
            isfield(ds.corrData, 'time') && ~isempty(ds.corrData.time)
        d = ds.corrData;
    else
        d = ds.data;
    end
    xv = []; yv = []; xLbl = ''; yLbl = '';
    yi = find(strcmp(d.labels, yChannel), 1);
    if isempty(yi), return; end
    xv = double(d.time);
    yv = d.values(:, yi);
    valid = ~isnan(xv) & ~isnan(yv);
    xv = xv(valid);  yv = yv(valid);
    yLbl = yChannel;
    if isfield(d.metadata, 'x_column_name') && ~isempty(d.metadata.x_column_name)
        xLbl = d.metadata.x_column_name;
    else
        xLbl = 'X';
    end
end
