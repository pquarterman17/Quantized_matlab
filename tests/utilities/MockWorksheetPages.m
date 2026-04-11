classdef MockWorksheetPages < handle
%MOCKWORKSHEETPAGES  Mock for Origin's WorksheetPages collection.
%
%   Provides .Count and .Item(idx) so that utilities.toOrigin can read back
%   the actual short name of the most recently created workbook during
%   tests.  Origin's real Pages collection is 0-indexed via Item(); this
%   mock follows the same convention.

    properties
        Pages   cell      % cell array of struct('Name', name)
        Count   double = 0
    end

    methods
        function obj = MockWorksheetPages()
            obj.Pages = {};
        end

        function add(obj, name)
        %ADD  Append a page with the given short name.
            obj.Pages{end+1} = struct('Name', name); %#ok<AGROW>
            obj.Count = numel(obj.Pages);
        end

        function p = Item(obj, idx)
        %ITEM  Return the page at zero-based index idx (Origin convention).
            p = obj.Pages{double(idx) + 1};
        end
    end
end
