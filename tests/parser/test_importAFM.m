function test_importAFM()
%TEST_IMPORTAFM  Smoke tests for the Bruker NanoScope AFM parser.
%   Creates a synthetic .spm file with a valid NanoScope header and binary
%   image data, then verifies importAFM reads it correctly.

    fprintf('\n  test_importAFM\n');
    fprintf('   AFM / NanoScope .spm parser tests\n\n');

    tmpDir = fullfile(tempdir, sprintf('afm_test_%s', datestr(now, 'yyyymmdd_HHMMSS')));
    mkdir(tmpDir);
    cleanup = onCleanup(@() rmdir(tmpDir, 's'));

    nPass = 0;
    nFail = 0;

    % ── TEST 1: Parse synthetic .spm file ────────────────────────────────
    fprintf('  TEST 1: Parse synthetic .spm file\n');
    try
        spmPath = createSyntheticSPM(tmpDir, 64, 64, 2, 500, 'nm');
        data = parser.importAFM(spmPath);
        assert(~isempty(data), 'Data should not be empty');
        assert(isfield(data, 'time'), 'Missing .time');
        assert(isfield(data, 'values'), 'Missing .values');
        assert(isfield(data, 'metadata'), 'Missing .metadata');
        assert(numel(data.time) == 64, 'Expected 64 rows, got %d', numel(data.time));
        fprintf('    PASS\n\n');
        nPass = nPass + 1;
    catch ME
        fprintf('    FAIL: %s\n\n', ME.message);
        nFail = nFail + 1;
    end

    % ── TEST 2: Image data struct is valid ───────────────────────────────
    fprintf('  TEST 2: Image data struct fields\n');
    try
        ps = data.metadata.parserSpecific;
        assert(ps.isImage, 'isImage should be true');
        img = ps.imageData;
        assert(img.height == 64, 'Height should be 64');
        assert(img.width == 64, 'Width should be 64');
        assert(img.bitDepth == 16, 'BitDepth should be 16');
        assert(img.numChannels == 1, 'NumChannels should be 1');
        assert(img.numFrames == 1, 'NumFrames should be 1');
        assert(isempty(img.frames), 'Frames should be empty');
        assert(img.calibrated, 'Should be calibrated');
        fprintf('    Pixels: %d x %d, %.2f %s/px\n', img.width, img.height, img.pixelSize, img.pixelUnit);
        fprintf('    PASS\n\n');
        nPass = nPass + 1;
    catch ME
        fprintf('    FAIL: %s\n\n', ME.message);
        nFail = nFail + 1;
    end

    % ── TEST 3: Pixel values are physically scaled ───────────────────────
    fprintf('  TEST 3: Z scale calibration\n');
    try
        pixels = data.metadata.parserSpecific.imageData.pixels;
        % The synthetic file uses int16 ramp * zScale
        assert(isa(pixels, 'double'), 'Pixels should be double (calibrated)');
        zRange = max(pixels(:)) - min(pixels(:));
        assert(zRange > 0, 'Z range should be positive');
        fprintf('    Z range: %.4f %s\n', zRange, data.metadata.parserSpecific.zUnit);
        fprintf('    PASS\n\n');
        nPass = nPass + 1;
    catch ME
        fprintf('    FAIL: %s\n\n', ME.message);
        nFail = nFail + 1;
    end

    % ── TEST 4: Channel names parsed ─────────────────────────────────────
    fprintf('  TEST 4: Channel names\n');
    try
        allCh = data.metadata.parserSpecific.allChannels;
        assert(~isempty(allCh), 'Should have at least one channel');
        assert(strcmp(data.metadata.parserSpecific.channelName, 'Height'), ...
            'First channel should be Height, got %s', data.metadata.parserSpecific.channelName);
        fprintf('    Channels: %s\n', strjoin(allCh, ', '));
        fprintf('    PASS\n\n');
        nPass = nPass + 1;
    catch ME
        fprintf('    FAIL: %s\n\n', ME.message);
        nFail = nFail + 1;
    end

    % ── TEST 5: Scan size metadata ───────────────────────────────────────
    fprintf('  TEST 5: Scan size metadata\n');
    try
        ss = data.metadata.parserSpecific.scanSize;
        su = data.metadata.parserSpecific.scanUnit;
        assert(ss(1) == 500, 'Scan width should be 500, got %.1f', ss(1));
        assert(strcmp(su, 'nm'), 'Scan unit should be nm, got %s', su);
        fprintf('    Scan: %.0f x %.0f %s\n', ss(1), ss(2), su);
        fprintf('    PASS\n\n');
        nPass = nPass + 1;
    catch ME
        fprintf('    FAIL: %s\n\n', ME.message);
        nFail = nFail + 1;
    end

    % ── TEST 6: resolveParser dispatch ───────────────────────────────────
    fprintf('  TEST 6: resolveParser dispatch for .spm\n');
    try
        result = parser.resolveParser(spmPath);
        assert(strcmp(result.name, 'importAFM'), ...
            'Expected importAFM, got %s', result.name);
        fprintf('    PASS\n\n');
        nPass = nPass + 1;
    catch ME
        fprintf('    FAIL: %s\n\n', ME.message);
        nFail = nFail + 1;
    end

    % ── TEST 7: Verbose mode ─────────────────────────────────────────────
    fprintf('  TEST 7: Verbose output\n');
    try
        data2 = parser.importAFM(spmPath, Verbose=true);
        assert(~isempty(data2), 'Verbose parse should succeed');
        fprintf('    PASS\n\n');
        nPass = nPass + 1;
    catch ME
        fprintf('    FAIL: %s\n\n', ME.message);
        nFail = nFail + 1;
    end

    % ── Summary ──────────────────────────────────────────────────────────
    fprintf('  ────────────────────────────────────────\n');
    fprintf('  test_importAFM: %d passed, %d failed\n', nPass, nFail);
    fprintf('  ────────────────────────────────────────\n\n');

    if nFail > 0
        error('test_importAFM:failed', '%d test(s) failed.', nFail);
    end
end


function spmPath = createSyntheticSPM(tmpDir, W, H, bytesPerPx, scanSizeNm, scanUnit)
%CREATESYNHETICSPM  Write a minimal valid NanoScope .spm file.
    spmPath = fullfile(tmpDir, 'synthetic_afm.spm');

    % Binary image data: simple ramp
    if bytesPerPx == 2
        rawImg = int16(linspace(-1000, 1000, W * H));
        dtype = 'int16';
    else
        rawImg = int32(linspace(-100000, 100000, W * H));
        dtype = 'int32';
    end

    % Build NanoScope header
    headerLines = { ...
        '\*File list', ...
        '\Version: 0x09400202', ...
        '', ...
        '\*Scanner list', ...
        ['\Scan Size: ' num2str(scanSizeNm) ' ' scanUnit], ...
        '\Scan rate: 1.00 Hz', ...
        '\Tip voltage: 0.000 V', ...
        '', ...
        '\*Ciao image list', ...
        ['\Samps/line: ' num2str(W)], ...
        ['\Number of lines: ' num2str(H)], ...
        ['\Bytes/pixel: ' num2str(bytesPerPx)], ...
        '\@2:Image Data: S [Height] "Height"', ...
        '\@2:Z scale: V [Sens. Zsens] (0.001000 V/LSB) 10.000 nm', ...
        '\Aspect Ratio: 1:1', ...
        '', ...
        '\*File list end'};

    % Write header, then compute data offset
    headerText = strjoin(headerLines, newline);
    headerBytes = numel(uint8(headerText)) + 1;  % +1 for trailing newline

    % Update header with correct data offset
    dataOffset = headerBytes;
    headerLines = [headerLines(1:11), ...
        {['\Data offset: ' num2str(dataOffset)]}, ...
        {['\Data length: ' num2str(W * H * bytesPerPx)]}, ...
        headerLines(12:end)];
    headerText = strjoin(headerLines, newline);

    % Recalculate with the added lines
    headerBytes = numel(uint8(headerText)) + 1;
    % Update data offset to match actual header size
    headerLines{12} = ['\Data offset: ' num2str(headerBytes)];
    headerText = strjoin(headerLines, newline);
    headerBytes = numel(uint8(headerText)) + 1;
    headerLines{12} = ['\Data offset: ' num2str(headerBytes)];
    headerText = strjoin(headerLines, newline);

    % Write file
    fid = fopen(spmPath, 'w');
    fprintf(fid, '%s\n', headerText);
    fwrite(fid, rawImg, dtype);
    fclose(fid);
end
