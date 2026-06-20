classdef MockWorksheet < handle
%MOCKWORKSHEET  Minimal mock of an Origin Worksheet COM object.
%
%   Returned by MockOriginCom.FindWorksheet so test_toOrigin can verify that
%   utilities.toOrigin writes data through the worksheet object (SetData)
%   rather than the PutWorksheet range-name path.  Records every SetData call.

    properties
        Name      char = ''
        SetResult logical = true   % what SetData returns (mirror PutResult)
        Calls     cell
    end

    methods
        function obj = MockWorksheet(name, setResult)
            obj.Calls = {};
            if nargin >= 1 && ~isempty(name),  obj.Name      = char(name); end
            if nargin >= 2 && ~isempty(setResult), obj.SetResult = logical(setResult); end
        end

        function r = SetData(obj, data, r1, c1)
        %SETDATA  Record the write (shape + start cell) and return SetResult.
            if nargin < 3, r1 = 0; end
            if nargin < 4, c1 = 0; end
            obj.Calls{end+1} = {'SetData', size(data), r1, c1}; %#ok<*AGROW>
            r = obj.SetResult;
        end

        function n = countCalls(obj, methodName)
        %COUNTCALLS  Number of recorded calls to methodName.
            n = 0;
            for i = 1:numel(obj.Calls)
                if strcmp(obj.Calls{i}{1}, methodName), n = n + 1; end
            end
        end
    end
end
