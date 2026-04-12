function tbl = synonymTable()
%SYNONYMTABLE  Return synonym groups for column name fuzzy matching.
%
%   Syntax:
%       tbl = templates.synonymTable()
%
%   Output:
%       tbl — N×1 cell array; each element is a cell array of equivalent
%             terms.  The first element of each group is the canonical form
%             that normalizeNames() maps everything else to.
%
%   Purpose:
%       Allows "Temp", "Temperature", and "T" to match the same template
%       column entry.  Called by TemplateEngine.normalizeNames (via the
%       package-level local function).
%
%   Example:
%       tbl = templates.synonymTable();
%       % tbl{1} = {'temperature', 'temp', 't'}
%
%   See also templates.TemplateEngine

    tbl = {
        {'temperature',   'temp',          't'}
        {'field',         'magnetic field', 'h', 'applied field', 'b', 'bfield'}
        {'moment',        'magnetization',  'm', 'mag', 'magnetic moment'}
        {'resistance',    'resistivity',    'res', 'r', 'impedance'}
        {'time',          'timestamp',      'elapsed', 'elapsed time', 'time stamp'}
        {'angle',         '2theta',         'two theta', 'twotheta', 'tth', '2th'}
        {'intensity',     'counts',         'cps', 'signal', 'count', 'det'}
        {'voltage',       'v',              'potential', 'emf', 'bias'}
        {'current',       'i',              'amps', 'ampere', 'amperes'}
        {'frequency',     'freq',           'f', 'hz'}
        {'susceptibility','chi',            'ac susceptibility', 'ac moment', 'xp', 'xs'}
        {'pressure',      'p',              'torr', 'mbar', 'mpa', 'kpa', 'pa'}
        {'std',           'stderr',         'std err', 'std error', 'error', 'sigma', 'uncertainty'}
        {'ac',            'ac'}   % kept single-element so 'ac' still normalises
        {'ch1',           'channel 1',      'channel1'}
        {'ch2',           'channel 2',      'channel2'}
    };
end
