function test_bosonPlotterSize
%TEST_BOSONPLOTTERSIZE  Ratchet test: BosonPlotter.m must not grow.
%
%   MASTERPLAN W5 #22 targets BosonPlotter.m < 6,000 lines (revised
%   2026-05-01 from the original < 8,000 milestone, which was reached
%   2026-04-26). Without an enforcement gate, new features tend to land
%   inside the monolith as fast as extractions pull lines out, and the
%   target never arrives. This test freezes the current size (plus a
%   small buffer for in-flight edits) and fails any change that pushes
%   above the cap.
%
%   The ceiling is meant to be ratcheted **downward** as extractions
%   land. Never raise it to accommodate growth — that defeats the
%   purpose. If a feature legitimately cannot fit under the cap,
%   extract something else first, or move the new feature into
%   +bosonPlotter/ (the preferred path for any new code).
%
%   Also checks the nested-function count against the parser ceiling
%   (see global rule matlab-gui-complexity.md — hard stop at 344).
%
%   Run standalone:  run tests/gui/test_bosonPlotterSize
%   Run via group :  runAllTests(Group="gui")

    thisDir = fileparts(mfilename('fullpath'));
    rootDir = fileparts(fileparts(thisDir));
    if ~contains(path, rootDir), addpath(rootDir); end

    passed = 0;
    failed = 0;
    failures = {};

    bpPath = fullfile(rootDir, 'BosonPlotter.m');

    % ════════════════════════════════════════════════════════════════════
    %  TEST 1: Line-count ratchet
    % ════════════════════════════════════════════════════════════════════
    % Current: 7,085 lines (2026-05-17). History: 8,931 (start of W5 #22)
    % → 8,400 (2026-04-26 pre-extractions) → 7,641 (2026-04-26 post 3
    % UI-construction extractions, -759 / -9%) → 7,658 (one-off edits
    % since) → 7,350 (2026-05-15 buildPlotControlsPanel extraction, -117)
    % → 7,111 (2026-05-16 extract guiImport/export/resample/watch, -239)
    % → 7,106 (2026-05-16 figDoc forwarder consolidation, -5)
    % → 7,085 (2026-05-17 dispatcher consolidation: onOverlayOp/
    %          onCopyPlotOp/inline onCreateInset, −4 slots/−26 lines).
    % Goal revised 2026-05-01 from <8,000 (achieved) to <6,000
    % (requires another -1,085 lines / -15%).
    % Ceiling carries a small buffer (~20 lines) so one in-flight edit
    % won't fail the build before an extraction commit lands. Ratchet
    % DOWN whenever an extraction lowers the baseline.
    LINE_CEILING = 7105;

    fprintf('\n== TEST 1: BosonPlotter.m line-count ratchet ==\n');
    try
        fid = fopen(bpPath, 'r');
        assert(fid > 0, 'could not open %s', bpPath);
        c = onCleanup(@() fclose(fid)); %#ok<NASGU>
        nLines = 0;
        while ~feof(fid)
            fgetl(fid);
            nLines = nLines + 1;
        end

        check(sprintf('BosonPlotter.m line count %d <= %d (ceiling)', ...
                      nLines, LINE_CEILING), ...
              nLines <= LINE_CEILING);

        if nLines > LINE_CEILING
            fprintf(['\n  !! BosonPlotter.m grew past its ceiling.\n' ...
                     '     Do NOT raise LINE_CEILING to make this pass.\n' ...
                     '     Instead, move new code into +bosonPlotter/ ' ...
                     'or extract an\n     existing nested function ' ...
                     'and ratchet the ceiling downward.\n' ...
                     '     See MASTERPLAN W5 #22 and CLAUDE.md ' ...
                     '"GUI Development Notes".\n']);
        elseif LINE_CEILING - nLines > 100
            fprintf(['  NOTE: %d lines of slack below ceiling; ' ...
                     'ratchet LINE_CEILING down to %d on next commit.\n'], ...
                    LINE_CEILING - nLines, nLines + 20);
        end
    catch ME
        recordCrash('TEST 1', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 2: Nested-function count vs. parser ceiling
    % ════════════════════════════════════════════════════════════════════
    % MATLAB's parser refuses to load the file past ~344 total nested
    % functions. The global rule in matlab-gui-complexity.md says warn
    % at 335, hard-stop at 340. We assert <= 283 here (current: 279 after
    % 2026-05-17 dispatcher consolidation) so the test fails loudly
    % long before the parser does.
    NESTED_FN_CEILING = 283;

    fprintf('\n== TEST 2: Nested-function count vs. parser ceiling ==\n');
    try
        src = fileread(bpPath);
        lines = splitlines(src);
        topLevel   = sum(startsWith(lines, '    function '));
        doublyNest = sum(startsWith(lines, '        function '));
        total      = topLevel + doublyNest;

        check(sprintf(['BosonPlotter.m nested fns: %d top-level + ' ...
                       '%d doubly-nested = %d <= %d'], ...
                      topLevel, doublyNest, total, NESTED_FN_CEILING), ...
              total <= NESTED_FN_CEILING);

        check('no new doubly-nested functions were introduced', ...
              doublyNest == 0);

        if total > NESTED_FN_CEILING
            fprintf(['\n  !! Nested-function count crossed the soft ' ...
                     'ceiling.\n     Extract a callback before adding ' ...
                     'more. Parser hard cap is 344.\n']);
        end
    catch ME
        recordCrash('TEST 2', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  Summary
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n%s\n', repmat('=', 1, 68));
    fprintf('  test_bosonPlotterSize: %d passed, %d failed\n', passed, failed);
    if failed > 0
        fprintf('\n  Failures:\n');
        for i = 1:numel(failures)
            fprintf('    - %s\n', failures{i});
        end
        error('test_bosonPlotterSize:failed', '%d test(s) failed', failed);
    end
    fprintf('%s\n', repmat('=', 1, 68));

    % ── Nested helpers ─────────────────────────────────────────────
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
