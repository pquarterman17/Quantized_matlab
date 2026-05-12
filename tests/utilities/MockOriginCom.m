classdef MockOriginCom < handle
%MOCKORIGINCOM  Record-and-replay mock for Origin.Application COM bridge.
%
%   Used by test_toOrigin to verify that utilities.toOrigin issues the
%   correct LabTalk command sequence and uses the correct PutWorksheet
%   range syntax — without requiring OriginPro to be installed.
%
%   The mock records every Execute() and PutWorksheet() call into a
%   .Calls cell array.  Tests then assert on call ordering and arguments.

    properties
        Visible           = int32(0)
        Calls             cell
        PutResult         logical = true
        ActiveBookName    char = ''
        ActiveSheetName   char = ''
    end

    methods
        function obj = MockOriginCom()
            obj.Calls = {};
        end

        function result = Execute(obj, cmd)
        %EXECUTE  Record a LabTalk command, simulate key commands.
            obj.Calls{end+1} = {'Execute', cmd}; %#ok<*AGROW>
            result = 0;

            tok = regexp(cmd, 'newbook\s+name:="([^"]+)"', 'tokens', 'once');
            if ~isempty(tok)
                obj.ActiveBookName = tok{1};
                obj.ActiveSheetName = 'Sheet1';
            end

            tok = regexp(cmd, 'wks\.name\$\s*=\s*"([^"]+)"', 'tokens', 'once');
            if ~isempty(tok)
                obj.ActiveSheetName = tok{1};
            end
        end

        function r = PutWorksheet(obj, range, mat, r0, c0)
            obj.Calls{end+1} = {'PutWorksheet', range, size(mat), r0, c0};
            r = obj.PutResult;
        end

        function release(obj)
            obj.Calls{end+1} = {'release'};
        end

        % ── Test helpers ──────────────────────────────────────────────

        function idx = findCall(obj, methodName, pattern)
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
