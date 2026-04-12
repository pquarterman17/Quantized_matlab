function result = importCIF(filePath)
%IMPORTCIF  Parse a CIF (Crystallographic Information File) into a MATLAB struct.
%
%   Syntax
%   ------
%   result = calc.importCIF(filePath)
%
%   Inputs
%   ------
%   filePath — path to a .cif file (char or string)
%
%   Outputs
%   -------
%   result — struct with fields:
%     .blockName   — string; data block identifier (after 'data_')
%     .tags        — dictionary of tag→value string (all simple key-values)
%     .loops       — cell array of loop structs, each with:
%                      .tags  — cell array of tag name strings
%                      .data  — cell matrix {nRows × nCols}
%     .cellParams  — struct with .a .b .c .alpha .beta .gamma (numeric)
%     .spaceGroup  — string (from _symmetry_space_group_name_H-M or alt)
%     .formula     — string (from _chemical_formula_sum)
%     .atomSites   — struct array with .label .symbol .x .y .z .occupancy
%
%   Examples
%   --------
%   result = calc.importCIF('data/cif/SrTiO3.cif');
%   disp(result.cellParams.a)         % lattice parameter a in Angstroms
%   disp(result.spaceGroup)           % e.g. 'Pm-3m'
%   disp(result.atomSites(1).label)   % e.g. 'Sr1'

% ════════════════════════════════════════════════════════════════════

arguments
    filePath (1,1) string
end

filePath = char(filePath);

% ── Open file ────────────────────────────────────────────────────────
fid = fopen(filePath, 'r');
if fid == -1
    error('calc:importCIF:fileNotFound', ...
        'Cannot open file: %s', filePath);
end
cleanupObj = onCleanup(@() fclose(fid));

% ── Read all lines ───────────────────────────────────────────────────
lines = {};
while true
    line = fgetl(fid);
    if ~ischar(line)
        break
    end
    lines{end+1} = line; %#ok<AGROW>
end

% ── Initialise output ────────────────────────────────────────────────
result.blockName  = '';
result.tags       = dictionary(string.empty, string.empty);
result.loops      = {};
result.cellParams = struct('a',NaN,'b',NaN,'c',NaN, ...
                           'alpha',NaN,'beta',NaN,'gamma',NaN);
result.spaceGroup = '';
result.formula    = '';
result.atomSites  = struct('label',{},'symbol',{},'x',{},'y',{},'z',{},'occupancy',{});

% ── Parse lines ──────────────────────────────────────────────────────
nLines = numel(lines);
i = 1;

while i <= nLines
    raw = lines{i};

    % Strip inline comment (but not inside quoted strings — safe for CIF
    % since # only introduces comments when at the start of a token)
    commentPos = findCommentPos(raw);
    if commentPos > 0
        raw = raw(1:commentPos-1);
    end
    line = strtrim(raw);

    % Skip blank lines and comment-only lines
    if isempty(line) || line(1) == '#'
        i = i + 1;
        continue
    end

    % ── data_ block header ───────────────────────────────────────────
    if strncmpi(line, 'data_', 5)
        result.blockName = strtrim(line(6:end));
        i = i + 1;
        continue
    end

    % ── loop_ ────────────────────────────────────────────────────────
    if strcmpi(line, 'loop_')
        [loopStruct, i] = parseLoop(lines, i+1, nLines);
        result.loops{end+1} = loopStruct;
        % Store atom_site loop for later extraction
        continue
    end

    % ── Simple tag-value pair ─────────────────────────────────────────
    if line(1) == '_'
        [tag, value, i] = parseTagValue(lines, i, nLines);
        result.tags(lower(tag)) = value;
        i = i + 1;
        continue
    end

    i = i + 1;
end

% ── Post-process: cell parameters ────────────────────────────────────
cellTagMap = { ...
    '_cell_length_a',    'a';   ...
    '_cell_length_b',    'b';   ...
    '_cell_length_c',    'c';   ...
    '_cell_angle_alpha', 'alpha'; ...
    '_cell_angle_beta',  'beta';  ...
    '_cell_angle_gamma', 'gamma'; ...
};
for ti = 1:size(cellTagMap,1)
    tag   = cellTagMap{ti,1};
    field = cellTagMap{ti,2};
    if isKey(result.tags, tag)
        result.cellParams.(field) = stripUncertainty(result.tags(tag));
    end
end

% ── Post-process: space group ─────────────────────────────────────────
sgTags = {'_symmetry_space_group_name_h-m', '_space_group_name_h-m_alt'};
for ti = 1:numel(sgTags)
    if isKey(result.tags, sgTags{ti})
        result.spaceGroup = strtrim(result.tags(sgTags{ti}));
        break
    end
end

% ── Post-process: chemical formula ───────────────────────────────────
if isKey(result.tags, '_chemical_formula_sum')
    result.formula = strtrim(result.tags('_chemical_formula_sum'));
end

% ── Post-process: atom sites from loops ──────────────────────────────
result.atomSites = extractAtomSites(result.loops);

end

% ════════════════════════════════════════════════════════════════════
% Local helpers
% ════════════════════════════════════════════════════════════════════

function pos = findCommentPos(line)
%FINDCOMMENTPOS  Return index of first # that is not inside a quoted string.
%   Returns 0 if no bare # found.
    inSingle = false;
    inDouble = false;
    for k = 1:numel(line)
        ch = line(k);
        if ch == '''' && ~inDouble
            inSingle = ~inSingle;
        elseif ch == '"' && ~inSingle
            inDouble = ~inDouble;
        elseif ch == '#' && ~inSingle && ~inDouble
            pos = k;
            return
        end
    end
    pos = 0;
end

% ────────────────────────────────────────────────────────────────────

function val = stripUncertainty(str)
%STRIPUNCERTAINTY  Remove parenthesized uncertainty and convert to double.
%   '5.4309(2)' → 5.4309,  '3.905' → 3.905,  '?' → NaN
    str = strtrim(str);
    if strcmp(str,'?') || strcmp(str,'.')
        val = NaN;
        return
    end
    str = regexprep(str, '\([^)]*\)', '');   % remove (...) suffix
    val = str2double(str);
end

% ────────────────────────────────────────────────────────────────────

function [tag, value, i] = parseTagValue(lines, i, nLines)
%PARSETAGVALUE  Parse a '_tag value' pair; handles multi-line text blocks.
    line = strtrim(lines{i});
    % Split on first whitespace
    parts = regexp(line, '^(\S+)\s*(.*)', 'tokens', 'once');
    if isempty(parts)
        tag   = line;
        value = '';
        return
    end
    tag   = lower(strtrim(parts{1}));
    value = strtrim(parts{2});

    if isempty(value)
        % Value is on the next line — could be a semicolon text block or
        % a plain token on the following line
        if i+1 <= nLines
            nextLine = strtrim(lines{i+1});
            if ~isempty(nextLine) && nextLine(1) == ';'
                % Multi-line text block: read until next ';' at line start
                [value, i] = readSemicolonBlock(lines, i+1, nLines);
            else
                i = i + 1;
                line2 = strtrim(lines{i});
                commentPos = findCommentPos(line2);
                if commentPos > 0
                    line2 = strtrim(line2(1:commentPos-1));
                end
                value = extractSingleValue(line2);
            end
        end
    elseif ~isempty(value) && value(1) == ';'
        % Inline semicolon block start (unusual but valid)
        [value, i] = readSemicolonBlock(lines, i, nLines);
    else
        value = extractSingleValue(value);
    end
end

% ────────────────────────────────────────────────────────────────────

function [text, i] = readSemicolonBlock(lines, i, nLines)
%READSEMICOLONBLOCK  Read a CIF semicolon-delimited multi-line text field.
%   On entry, lines{i} starts with ';'. Returns concatenated text.
    % Skip the opening ';' line (content after ';' on same line is discarded per CIF spec)
    i = i + 1;
    textParts = {};
    while i <= nLines
        line = lines{i};
        if ~isempty(strtrim(line)) && strtrim(line(1)) == ';'
            break  % closing semicolon
        end
        textParts{end+1} = line; %#ok<AGROW>
        i = i + 1;
    end
    text = strjoin(textParts, ' ');
    text = strtrim(text);
    % i now points at closing ';' line; caller will do i+1 after return
    % But parseTagValue caller does i+1, so back off one
    i = i - 1;
end

% ────────────────────────────────────────────────────────────────────

function val = extractSingleValue(token)
%EXTRACTSINGLEVALUE  Strip surrounding quotes from a CIF value string.
%   Handles quoted strings that may contain spaces (e.g. 'O3 Sr Ti').
    token = strtrim(token);
    if isempty(token)
        val = '';
        return
    end
    % If starts with a quote, find the matching closing quote
    if token(1) == ''''
        closeIdx = find(token(2:end) == '''', 1, 'last') + 1;
        if ~isempty(closeIdx)
            val = token(2:closeIdx-1);
        else
            val = token(2:end);  % no closing quote — take everything
        end
    elseif token(1) == '"'
        closeIdx = find(token(2:end) == '"', 1, 'last') + 1;
        if ~isempty(closeIdx)
            val = token(2:closeIdx-1);
        else
            val = token(2:end);
        end
    else
        % Unquoted: take only the first whitespace-delimited token
        parts = strsplit(token);
        val = parts{1};
    end
end

% ────────────────────────────────────────────────────────────────────

function [loopStruct, i] = parseLoop(lines, i, nLines)
%PARSELOOP  Parse a CIF loop_ block starting at line i (first tag line).
    loopTags = {};
    loopData = {};

    % Collect tag names (lines starting with '_')
    while i <= nLines
        line = strtrim(lines{i});
        % Strip comment
        cp = findCommentPos(line);
        if cp > 0; line = strtrim(line(1:cp-1)); end
        if isempty(line)
            i = i + 1;
            continue
        end
        if line(1) == '_'
            loopTags{end+1} = lower(strtrim(line)); %#ok<AGROW>
            i = i + 1;
        else
            break  % reached data rows
        end
    end

    nCols = numel(loopTags);
    if nCols == 0
        loopStruct.tags = {};
        loopStruct.data = {};
        return
    end

    % Collect data tokens until next '_tag', 'loop_', 'data_', or EOF
    tokens = {};
    while i <= nLines
        line = lines{i};
        cp = findCommentPos(line);
        if cp > 0; line = line(1:cp-1); end
        trimmed = strtrim(line);

        if isempty(trimmed)
            i = i + 1;
            continue
        end

        % Stop conditions
        firstToken = regexp(trimmed, '^\S+', 'match', 'once');
        if strcmpi(firstToken, 'loop_') || ...
           strcmpi(firstToken, 'save_') || ...
           strncmpi(firstToken, 'data_', 5)
            break
        end
        if firstToken(1) == '_'
            break
        end

        % Handle semicolon text block
        if trimmed(1) == ';'
            [blockText, i] = readSemicolonBlock(lines, i, nLines);
            tokens{end+1} = blockText; %#ok<AGROW>
            i = i + 1;
            continue
        end

        % Tokenise the line respecting quotes
        lineTokens = tokeniseCIFLine(trimmed);
        for t = 1:numel(lineTokens)
            tokens{end+1} = lineTokens{t}; %#ok<AGROW>
        end
        i = i + 1;
    end

    % Arrange tokens into rows
    nTokens = numel(tokens);
    nRows = floor(nTokens / nCols);
    loopData = cell(nRows, nCols);
    for r = 1:nRows
        for c = 1:nCols
            idx = (r-1)*nCols + c;
            if idx <= nTokens
                loopData{r,c} = tokens{idx};
            else
                loopData{r,c} = '';
            end
        end
    end

    loopStruct.tags = loopTags;
    loopStruct.data = loopData;
end

% ────────────────────────────────────────────────────────────────────

function tokens = tokeniseCIFLine(line)
%TOKENISECIFLINE  Split a CIF data line into tokens, respecting quotes.
    tokens = {};
    n = numel(line);
    k = 1;
    while k <= n
        ch = line(k);
        % Skip whitespace
        if ch == ' ' || ch == char(9)
            k = k + 1;
            continue
        end
        % Quoted string
        if ch == '''' || ch == '"'
            quote = ch;
            k = k + 1;
            start = k;
            while k <= n && line(k) ~= quote
                k = k + 1;
            end
            tokens{end+1} = line(start:k-1); %#ok<AGROW>
            k = k + 1;  % skip closing quote
        else
            % Unquoted token
            start = k;
            while k <= n && line(k) ~= ' ' && line(k) ~= char(9)
                k = k + 1;
            end
            tokens{end+1} = line(start:k-1); %#ok<AGROW>
        end
    end
end

% ────────────────────────────────────────────────────────────────────

function atomSites = extractAtomSites(loops)
%EXTRACTATOMSITES  Find the _atom_site_* loop and return a struct array.
    atomSites = struct('label',{},'symbol',{},'x',{},'y',{},'z',{},'occupancy',{});

    % Tag names to look for (lowercase)
    wantLabel    = '_atom_site_label';
    wantSymbol   = '_atom_site_type_symbol';
    wantX        = '_atom_site_fract_x';
    wantY        = '_atom_site_fract_y';
    wantZ        = '_atom_site_fract_z';
    wantOcc      = '_atom_site_occupancy';

    for li = 1:numel(loops)
        lp = loops{li};
        if isempty(lp.tags)
            continue
        end
        % Check if this loop contains atom_site tags
        hasAtom = any(strncmp(lp.tags, '_atom_site_', 11));
        if ~hasAtom
            continue
        end

        % Map tag → column index
        colLabel = findCol(lp.tags, wantLabel);
        colSym   = findCol(lp.tags, wantSymbol);
        colX     = findCol(lp.tags, wantX);
        colY     = findCol(lp.tags, wantY);
        colZ     = findCol(lp.tags, wantZ);
        colOcc   = findCol(lp.tags, wantOcc);

        nRows = size(lp.data, 1);
        for r = 1:nRows
            s.label     = getCell(lp.data, r, colLabel);
            s.symbol    = getCell(lp.data, r, colSym);
            s.x         = stripUncertainty(getCell(lp.data, r, colX));
            s.y         = stripUncertainty(getCell(lp.data, r, colY));
            s.z         = stripUncertainty(getCell(lp.data, r, colZ));
            s.occupancy = stripUncertainty(getCell(lp.data, r, colOcc));
            atomSites(end+1) = s; %#ok<AGROW>
        end
        break  % only process first atom_site loop
    end
end

% ────────────────────────────────────────────────────────────────────

function idx = findCol(tags, name)
%FINDCOL  Return column index of tag in cell array, or 0 if absent.
    idx = find(strcmp(tags, name), 1);
    if isempty(idx)
        idx = 0;
    end
end

% ────────────────────────────────────────────────────────────────────

function val = getCell(data, row, col)
%GETCELL  Safely retrieve a cell value; returns '' if col==0 or out of range.
    if col == 0 || row > size(data,1) || col > size(data,2)
        val = '';
    else
        val = data{row, col};
    end
end
