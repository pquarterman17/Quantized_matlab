function test_toOrigin
%TEST_TOORIGIN  Headless tests for utilities.toOrigin via mock COM injection.
%
%   Run standalone:  cd tests/utilities; run test_toOrigin
%   Run from root:   run tests/utilities/test_toOrigin
%   Or via group:    runAllTests(Group="utilities")

    thisDir = fileparts(mfilename('fullpath'));
    rootDir = fileparts(fileparts(thisDir));
    if ~contains(path, rootDir), addpath(rootDir); end
    if ~contains(path, thisDir), addpath(thisDir); end

    passed   = 0;
    failed   = 0;
    failures = {};

    % ════════════════════════════════════════════════════════════════════
    %  TEST 1: Happy path — call sequence and qualified PutWorksheet path
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 1: happy path call sequence ==\n');
    try
        mock = MockOriginCom();
        data = makeData(10, 3);

        ok = utilities.toOrigin(data, ...
            'BookName', 'TestBook', ...
            'SheetName', 'TestSheet', ...
            'OriginObj', mock);

        check('toOrigin returned true', ok == true);

        newbookIdx  = mock.findCall('Execute', 'newbook name:="TestBook"');
        renameIdx   = mock.findCall('Execute', 'wks\.name\$\s*=\s*"TestSheet"');
        activateIdx = mock.findCall('Execute', 'win -a TestBook');
        putIdx      = mock.findCall('PutWorksheet');

        check('newbook name:="TestBook" was issued', newbookIdx > 0);
        check('wks.name$ rename was issued',         renameIdx > 0);
        check('win -a activation was issued',        activateIdx > 0);
        check('PutWorksheet was called',             putIdx > 0);

        check('newbook BEFORE rename',        newbookIdx  < renameIdx);
        check('rename BEFORE PutWorksheet',   renameIdx   < putIdx);
        check('activate BEFORE rename',       activateIdx < renameIdx);

        putCall = mock.Calls{putIdx};
        check('PutWorksheet range is [TestBook]TestSheet!', ...
            strcmp(putCall{2}, '[TestBook]TestSheet!'));

        check('PutWorksheet matrix shape is 10x4', isequal(putCall{3}, [10 4]));
    catch ME
        recordCrash('TEST 1', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 2: Column count via wks.nCols
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 2: wks.nCols sizing ==\n');
    try
        mock = MockOriginCom();
        data = makeData(5, 4);
        utilities.toOrigin(data, 'OriginObj', mock, ...
            'BookName', 'B', 'SheetName', 'S');

        nColsIdx  = mock.findCall('Execute', 'wks\.nCols\s*=\s*5');
        addcolIdx = mock.findCall('Execute', 'wks\.addcol');

        check('wks.nCols = 5 was issued',                  nColsIdx > 0);
        check('wks.addcol was NOT issued (broken syntax)', addcolIdx == 0);
    catch ME
        recordCrash('TEST 2', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 3: yErr column designation
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 3: error column -> yErr designation ==\n');
    try
        mock = MockOriginCom();
        data = struct();
        data.time   = (1:5).';
        data.values = rand(5, 2);
        data.labels = {'Moment', 'M. Std. Err.'};
        data.units  = {'emu', 'emu'};
        data.metadata = struct('source', 'm.dat');

        utilities.toOrigin(data, 'OriginObj', mock, ...
            'BookName', 'B', 'SheetName', 'S');

        yIdx    = mock.findCall('Execute', 'wks\.col2\.type\s*=\s*1');
        yErrIdx = mock.findCall('Execute', 'wks\.col3\.type\s*=\s*3');

        check('col2 designated as Y (type 1)',     yIdx > 0);
        check('col3 designated as yErr (type 3)',  yErrIdx > 0);
    catch ME
        recordCrash('TEST 3', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 4: Name sanitization (special chars -> underscores)
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 4: name sanitization ==\n');
    try
        mock = MockOriginCom();
        data = makeData(3, 1);
        utilities.toOrigin(data, 'OriginObj', mock, ...
            'BookName', 'My Book!', 'SheetName', 'Scan #1');

        newbookIdx = mock.findCall('Execute', 'newbook name:="My_Book_"');
        renameIdx  = mock.findCall('Execute', 'wks\.name\$\s*=\s*"Scan__1"');

        check('book name sanitized to My_Book_', newbookIdx > 0);
        check('sheet name sanitized to Scan__1', renameIdx > 0);

        putIdx  = mock.findCall('PutWorksheet');
        putCall = mock.Calls{putIdx};
        check('PutWorksheet uses sanitized [Book]Sheet!', ...
            strcmp(putCall{2}, '[My_Book_]Scan__1!'));
    catch ME
        recordCrash('TEST 4', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 5: PutWorksheet failure -> warning + fallback attempts
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 5: PutWorksheet failure path ==\n');
    try
        mock = MockOriginCom();
        mock.PutResult = false;
        data = makeData(4, 1);

        lastwarn('');
        warnState = warning('off', 'toOrigin:putWorksheetFailed');
        cleanup = onCleanup(@() warning(warnState)); %#ok<NASGU>

        utilities.toOrigin(data, 'OriginObj', mock, ...
            'BookName', 'FailBook', 'SheetName', 'FailSheet');

        [warnMsg, warnId] = lastwarn();

        nPut = sum(cellfun(@(c) strcmp(c{1}, 'PutWorksheet'), mock.Calls));
        check('PutWorksheet called 3 times (qualified + sheet + Sheet1 fallback)', nPut == 3);

        putIdxs    = find(cellfun(@(c) strcmp(c{1}, 'PutWorksheet'), mock.Calls));
        firstCall  = mock.Calls{putIdxs(1)};
        secondCall = mock.Calls{putIdxs(2)};
        thirdCall  = mock.Calls{putIdxs(3)};
        check('1st PutWorksheet uses qualified path', ...
            strcmp(firstCall{2}, '[FailBook]FailSheet!'));
        check('2nd PutWorksheet uses bare sheet name', ...
            strcmp(secondCall{2}, 'FailSheet'));
        check('3rd PutWorksheet uses [Book]Sheet1! fallback', ...
            strcmp(thirdCall{2}, '[FailBook]Sheet1!'));

        check('toOrigin:putWorksheetFailed warning was raised', ...
            strcmp(warnId, 'toOrigin:putWorksheetFailed'));
    catch ME
        recordCrash('TEST 5', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 6: utilities.logError writes structured entries
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 6: utilities.logError ==\n');
    try
        tmpLog = [tempname '.txt'];
        if exist(tmpLog, 'file'), delete(tmpLog); end

        utilities.logError('test:simple', 'a basic message', [], 'LogFile', tmpLog);

        try
            error('test:withME', 'planned failure');
        catch ME
            utilities.logError('test:withME', 'detailed failure', ME, 'LogFile', tmpLog);
        end

        check('log file was created', exist(tmpLog, 'file') == 2);

        txt = fileread(tmpLog);
        check('log contains the simple title',     contains(txt, 'test:simple'));
        check('log contains the simple message',   contains(txt, 'a basic message'));
        check('log contains the ME identifier',    contains(txt, 'test:withME'));
        check('log contains a Stack: section',     contains(txt, 'Stack:'));
        check('log contains the timestamp marker', contains(txt, '====='));

        delete(tmpLog);

        threw = false;
        try
            utilities.logError('test:badpath', 'msg', [], ...
                'LogFile', 'Z:/definitely/does/not/exist/log.txt');
        catch
            threw = true;
        end
        check('logError swallows bad path errors', ~threw);
    catch ME
        recordCrash('TEST 6', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 7: Bad input struct -> warning, no COM call
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 7: bad input struct rejected before COM ==\n');
    try
        mock = MockOriginCom();
        badData = struct('foo', 1, 'bar', 2);

        lastwarn('');
        warnState = warning('off', 'toOrigin:badStruct');
        cleanup = onCleanup(@() warning(warnState)); %#ok<NASGU>
        ok = utilities.toOrigin(badData, 'OriginObj', mock);

        [~, warnId] = lastwarn();
        check('toOrigin returned false on bad input', ok == false);
        check('toOrigin:badStruct warning raised',    strcmp(warnId, 'toOrigin:badStruct'));
        check('no Execute call was issued',           isempty(mock.Calls));
    catch ME
        recordCrash('TEST 7', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 8: Sheet name truncated to 31 chars
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 8: sheet name truncation to 31 chars ==\n');
    try
        mock = MockOriginCom();
        data = makeData(3, 1);
        longSheet = 'MTRL_159_BLKT_slot07_refl1d_script_refl';
        truncSheet = longSheet(1:31);

        utilities.toOrigin(data, 'OriginObj', mock, ...
            'BookName', 'TFT', 'SheetName', longSheet);

        renameIdx = mock.findCall('Execute', ...
            sprintf('wks\\.name\\$\\s*=\\s*"%s"', truncSheet));
        check('sheet name truncated to 31 chars', renameIdx > 0);

        putIdx  = mock.findCall('PutWorksheet');
        putCall = mock.Calls{putIdx};
        check('PutWorksheet uses truncated sheet name', ...
            strcmp(putCall{2}, sprintf('[TFT]%s!', truncSheet)));
    catch ME
        recordCrash('TEST 8', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  Summary
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n%s\n', repmat('=', 1, 68));
    fprintf('  test_toOrigin: %d passed, %d failed\n', passed, failed);
    if failed > 0
        fprintf('\n  Failures:\n');
        for i = 1:numel(failures)
            fprintf('    - %s\n', failures{i});
        end
        error('test_toOrigin:failed', '%d test(s) failed', failed);
    end
    fprintf('%s\n', repmat('=', 1, 68));

    function check(label, cond)
        if cond
            passed = passed + 1;
            fprintf('  PASS  %s\n', label);
        else
            failed = failed + 1;
            failures{end+1} = label; %#ok<AGROW>
            fprintf('  FAIL  %s\n', label);
        end
    end

    function recordCrash(testName, ME)
        failed = failed + 1;
        failures{end+1} = sprintf('%s crashed: %s', testName, ME.message); %#ok<AGROW>
        fprintf('  CRASH %s: %s\n', testName, ME.message);
    end
end


function d = makeData(nRows, nYCols)
    d = struct();
    d.time   = (1:nRows).';
    d.values = rand(nRows, nYCols);
    d.labels = arrayfun(@(k) sprintf('chan%d', k), 1:nYCols, 'UniformOutput', false);
    d.units  = repmat({'arb'}, 1, nYCols);
    d.metadata = struct('source', 'mock_file.dat', ...
                        'xColumnName', 'Field', ...
                        'xColumnUnit', 'Oe');
end
