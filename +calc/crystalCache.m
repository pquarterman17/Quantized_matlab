function result = crystalCache(action, opts)
%CRYSTALCACHE  Local crystal structure database backed by a .mat file.
%
%   Syntax
%   ------
%   entries = calc.crystalCache('list')
%   entries = calc.crystalCache('search', Query='SrTiO3')
%   calc.crystalCache('add',    Entry=s)
%   calc.crystalCache('import', FilePath='data/cif/STO.cif')
%   calc.crystalCache('remove', Name='SrTiO3')
%   calc.crystalCache('rebuild')
%   entry   = calc.crystalCache('get', Name='SrTiO3')
%
%   Actions
%   -------
%   'list'    — return all entries as struct array
%   'search'  — case-insensitive substring match on name/formula/spaceGroup
%   'add'     — add a manually constructed entry (requires .name, .formula,
%               .a, .b, .c, .alpha, .beta, .gamma, .spaceGroup)
%   'import'  — parse a CIF file via calc.importCIF and add to cache
%   'remove'  — delete entry by name (exact, case-insensitive)
%   'rebuild' — clear cache and reimport every .cif in data/cif/
%   'get'     — return one entry by name (exact, case-insensitive)
%
%   Storage
%   -------
%   Cache file: <toolboxRoot>/data/crystal_cache.mat
%   MAT variable: 'crystalDB' — struct array with fields:
%     .name, .formula, .a, .b, .c, .alpha, .beta, .gamma,
%     .spaceGroup, .atomSites, .source, .dateAdded
%
%   Examples
%   --------
%   % Import a CIF and query it
%   calc.crystalCache('import', FilePath='data/cif/STO.cif');
%   e = calc.crystalCache('get', Name='SrTiO3');
%   disp(e.a)
%
%   % Search by formula substring
%   hits = calc.crystalCache('search', Query='Ti');
%   disp({hits.name})

% ════════════════════════════════════════════════════════════════════

arguments
    action (1,1) string
    opts.Query    (1,1) string  = ""
    opts.Entry    (1,1) struct  = struct()
    opts.FilePath (1,1) string  = ""
    opts.Name     (1,1) string  = ""
end

% ── Cache file location ───────────────────────────────────────────────
toolboxRoot = fileparts(fileparts(mfilename('fullpath')));
dataDir     = fullfile(toolboxRoot, 'data');
cacheFile   = fullfile(dataDir, 'crystal_cache.mat');

% ── Persistent handle for invalidation ───────────────────────────────
persistent cachedDB cachedMtime

% Ensure data/ directory exists
if ~isfolder(dataDir)
    mkdir(dataDir);
end

% ── Dispatch ──────────────────────────────────────────────────────────
switch lower(char(action))

    case 'list'
        db = loadDB(cacheFile, cachedDB, cachedMtime);
        [cachedDB, cachedMtime] = updateCache(db, cacheFile);
        result = db;

    case 'search'
        db    = loadDB(cacheFile, cachedDB, cachedMtime);
        [cachedDB, cachedMtime] = updateCache(db, cacheFile);
        query = lower(char(opts.Query));
        if isempty(query)
            result = db;
            return
        end
        keep  = false(1, numel(db));
        for k = 1:numel(db)
            keep(k) = contains(lower(db(k).name),       query) || ...
                      contains(lower(db(k).formula),    query) || ...
                      contains(lower(db(k).spaceGroup), query);
        end
        result = db(keep);

    case 'add'
        entry = opts.Entry;
        validateEntry(entry);
        db = loadDB(cacheFile, cachedDB, cachedMtime);
        db = removeByName(db, entry.name);
        entry = normaliseEntry(entry, 'manual');
        db(end+1) = entry;
        [cachedDB, cachedMtime] = saveDB(db, cacheFile);
        result = entry;

    case 'import'
        fp = char(opts.FilePath);
        if isempty(fp)
            error('calc:crystalCache:missingArg', ...
                'FilePath must be specified for ''import'' action.');
        end
        cif    = calc.importCIF(fp);
        entry  = cifToEntry(cif, fp);
        db     = loadDB(cacheFile, cachedDB, cachedMtime);
        db     = removeByName(db, entry.name);
        db(end+1) = entry;
        [cachedDB, cachedMtime] = saveDB(db, cacheFile);
        result = entry;

    case 'remove'
        nm = char(opts.Name);
        if isempty(nm)
            error('calc:crystalCache:missingArg', ...
                'Name must be specified for ''remove'' action.');
        end
        db = loadDB(cacheFile, cachedDB, cachedMtime);
        db = removeByName(db, nm);
        [cachedDB, cachedMtime] = saveDB(db, cacheFile);
        result = db;

    case 'rebuild'
        cifDir = fullfile(dataDir, 'cif');
        if ~isfolder(cifDir)
            mkdir(cifDir);
        end
        listing = dir(fullfile(cifDir, '*.cif'));
        db = emptyDB();
        for k = 1:numel(listing)
            fp = fullfile(listing(k).folder, listing(k).name);
            try
                cif   = calc.importCIF(fp);
                entry = cifToEntry(cif, fp);
                db(end+1) = entry; %#ok<AGROW>
            catch ME
                warning('calc:crystalCache:importFailed', ...
                    'Skipping %s: %s', listing(k).name, ME.message);
            end
        end
        [cachedDB, cachedMtime] = saveDB(db, cacheFile);
        result = db;

    case 'get'
        nm = char(opts.Name);
        if isempty(nm)
            error('calc:crystalCache:missingArg', ...
                'Name must be specified for ''get'' action.');
        end
        db = loadDB(cacheFile, cachedDB, cachedMtime);
        [cachedDB, cachedMtime] = updateCache(db, cacheFile);
        idx = findByName(db, nm);
        if isempty(idx)
            error('calc:crystalCache:notFound', ...
                'No entry named "%s" in crystal cache.', nm);
        end
        result = db(idx(1));

    otherwise
        error('calc:crystalCache:unknownAction', ...
            'Unknown action "%s". Valid: list, search, add, import, remove, rebuild, get.', ...
            action);
end

end

% ════════════════════════════════════════════════════════════════════
% Local helpers
% ════════════════════════════════════════════════════════════════════

function db = loadDB(cacheFile, cachedDB, cachedMtime)
%LOADDB  Load crystal database from .mat file, using persistent cache when fresh.
    if ~isfile(cacheFile)
        db = emptyDB();
        return
    end
    info = dir(cacheFile);
    currentMtime = info.datenum;
    if ~isempty(cachedDB) && ~isempty(cachedMtime) && currentMtime == cachedMtime
        db = cachedDB;
        return
    end
    try
        S  = load(cacheFile, 'crystalDB');
        db = S.crystalDB;
    catch
        db = emptyDB();
    end
end

% ────────────────────────────────────────────────────────────────────

function [newCachedDB, newMtime] = saveDB(db, cacheFile)
%SAVEDB  Write the database to disk and return updated cache state.
    crystalDB = db; %#ok<NASGU>
    try
        save(cacheFile, 'crystalDB');
    catch ME
        warning('calc:crystalCache:saveFailed', ...
            'Could not save crystal cache: %s', ME.message);
    end
    if isfile(cacheFile)
        info     = dir(cacheFile);
        newMtime = info.datenum;
    else
        newMtime = [];
    end
    newCachedDB = db;
end

% ────────────────────────────────────────────────────────────────────

function [newCachedDB, newMtime] = updateCache(db, cacheFile)
%UPDATECACHE  Refresh persistent pointers after a read (no disk write).
    newCachedDB = db;
    if isfile(cacheFile)
        info     = dir(cacheFile);
        newMtime = info.datenum;
    else
        newMtime = [];
    end
end

% ────────────────────────────────────────────────────────────────────

function db = emptyDB()
%EMPTYDB  Return an empty struct array with the canonical schema.
    db = struct( ...
        'name',       {}, ...
        'formula',    {}, ...
        'a',          {}, ...
        'b',          {}, ...
        'c',          {}, ...
        'alpha',      {}, ...
        'beta',       {}, ...
        'gamma',      {}, ...
        'spaceGroup', {}, ...
        'atomSites',  {}, ...
        'source',     {}, ...
        'dateAdded',  {} );
end

% ────────────────────────────────────────────────────────────────────

function entry = normaliseEntry(entry, source)
%NORMALISEENTRY  Ensure all required fields exist with correct types.
    requiredFields = {'name','formula','a','b','c','alpha','beta','gamma', ...
                      'spaceGroup','atomSites','source','dateAdded'};
    defaults.name       = '';
    defaults.formula    = '';
    defaults.a          = NaN;
    defaults.b          = NaN;
    defaults.c          = NaN;
    defaults.alpha      = NaN;
    defaults.beta       = NaN;
    defaults.gamma      = NaN;
    defaults.spaceGroup = '';
    defaults.atomSites  = struct('label',{},'symbol',{},'x',{},'y',{},'z',{},'occupancy',{});
    defaults.source     = source;
    defaults.dateAdded  = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));

    for fi = 1:numel(requiredFields)
        f = requiredFields{fi};
        if ~isfield(entry, f)
            entry.(f) = defaults.(f);
        end
    end
    % Overwrite source and dateAdded if they are empty
    if isempty(entry.source)
        entry.source = source;
    end
    if isempty(entry.dateAdded)
        entry.dateAdded = defaults.dateAdded;
    end
end

% ────────────────────────────────────────────────────────────────────

function validateEntry(entry)
%VALIDATEENTRY  Error if required fields for a manual 'add' are missing.
    required = {'name','a','b','c','alpha','beta','gamma','spaceGroup'};
    for k = 1:numel(required)
        f = required{k};
        if ~isfield(entry, f)
            error('calc:crystalCache:invalidEntry', ...
                'Entry is missing required field: %s', f);
        end
    end
    if ~isfield(entry, 'formula')
        entry.formula = ''; %#ok<NASGU>  (validated below via normaliseEntry)
    end
end

% ────────────────────────────────────────────────────────────────────

function entry = cifToEntry(cif, source)
%CIFTOENTRY  Convert a parsed CIF struct to a cache entry struct.
    entry.name       = cif.blockName;
    entry.formula    = cif.formula;
    entry.a          = cif.cellParams.a;
    entry.b          = cif.cellParams.b;
    entry.c          = cif.cellParams.c;
    entry.alpha      = cif.cellParams.alpha;
    entry.beta       = cif.cellParams.beta;
    entry.gamma      = cif.cellParams.gamma;
    entry.spaceGroup = cif.spaceGroup;
    entry.atomSites  = cif.atomSites;
    entry            = normaliseEntry(entry, source);
end

% ────────────────────────────────────────────────────────────────────

function idx = findByName(db, name)
%FINDBYNAME  Return indices of entries matching name (case-insensitive).
    idx = find(strcmpi({db.name}, name));
end

% ────────────────────────────────────────────────────────────────────

function db = removeByName(db, name)
%REMOVEBYNAME  Delete all entries matching name (case-insensitive).
    if isempty(db)
        return
    end
    keep = ~strcmpi({db.name}, name);
    db   = db(keep);
end
