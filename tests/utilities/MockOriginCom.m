classdef MockOriginCom < handle
%MOCKORIGINCOM  Record-and-replay mock for Origin.Application COM bridge.
%
%   Used by test_toOrigin to verify that utilities.toOrigin issues the
%   correct LabTalk command sequence and uses the correct PutWorksheet
%   range syntax — without requiring OriginPro to be installed.
%
%   The mock records every Execute() and PutWorksheet() call into a
%   .Calls cell array.  Tests then assert on call ordering and arguments.
%
%   Behavior modeled:
%   - Visible property accepts int32 assignment (no-op)
%   - Execute(cmd) records the command and, if it parses as a `newbook`,
%     adds a corresponding page to the WorksheetPages collection so that
%     production code reading back the actual book name still works.
%   - PutWorksheet(range, mat, r0, c0) records the call and returns
%     .PutResult (default true) so failure paths can be exercised.
%   - release() records the call (no-op).
%
%   See also tests/utilities/MockWorksheetPages, tests/utilities/test_toOrigin.

    properties
        Visible           = int32(0)            % settable, ignored
        WorksheetPages    MockWorksheetPages    % collection of mock pages
        Calls             cell                  % {{name, args...}, ...}
        PutResult         logical = true        % what PutWorksheet returns
    end

    methods
        function obj = MockOriginCom()
            obj.WorksheetPages = MockWorksheetPages();
            obj.Calls          = {};
        end

        function Execute(obj, cmd)
        %EXECUTE  Record a LabTalk command and react to newbook commands.
            obj.Calls{end+1} = {'Execute', cmd}; %#ok<*AGROW>

            % Detect `newbook bk:="X"` and add a corresponding page so that
            % the production code's WorksheetPages.Item(end-1).Name lookup
            % returns a sane value.
            tok = regexp(cmd, 'newbook\s+bk:="([^"]+)"', 'tokens', 'once');
            if ~isempty(tok)
                obj.WorksheetPages.add(tok{1});
            end
        end

        function r = PutWorksheet(obj, range, mat, r0, c0)
        %PUTWORKSHEET  Record a data write and return the configured result.
            obj.Calls{end+1} = {'PutWorksheet', range, size(mat), r0, c0};
            r = obj.PutResult;
        end

        function release(obj)
        %RELEASE  Record a release call.  Production code never calls this
        %on injected mocks (lifecycle is owned by the caller), but we
        %implement it for safety.
            obj.Calls{end+1} = {'release'};
        end

        % ── Test helpers ──────────────────────────────────────────────

        function idx = findCall(obj, methodName, pattern)
        %FINDCALL  Return the index of the first call matching method+pattern.
        %   idx = mock.findCall('Execute', 'newbook bk:=')
        %   idx = mock.findCall('PutWorksheet')   % pattern optional
            for i = 1:numel(obj.Calls)
                c = obj.Calls{i};
                if ~strcmp(c{1}, methodName), continue; end
                if nargin < 3 || isempty(pattern)
                    idx = i; return;
                end
                if numel(c) >= 2 && ischar(c{2}) && ...
                   ~isempty(regexp(c{2}, pattern, 'once'))
                    idx = i; return;
                end
            end
            idx = 0;
        end
    end
end
