classdef datasetGroups < handle
%DATASETGROUPS  Manage named groups of datasets for batch operations.
%
%   grp = bosonPlotter.datasetGroups()
%   grp.createGroup('Temperature Series')
%   grp.addToGroup('Temperature Series', [1 2 3 4 5])
%   grp.createGroup('Field Sweeps', [6 7 8])
%   indices = grp.getGroup('Temperature Series')
%
%   Organises dataset indices into named groups for batch operations
%   (export all, apply same fit, compare).  Groups are ordered and
%   indices refer to positions in the BosonPlotter dataset list.
%
%   Methods:
%       createGroup(name)             — create empty group
%       createGroup(name, indices)    — create group with initial members
%       deleteGroup(name)             — remove a group
%       renameGroup(oldName, newName) — rename a group
%       addToGroup(name, indices)     — add dataset indices to a group
%       removeFromGroup(name, indices)— remove dataset indices from group
%       getGroup(name)                — return indices in a group
%       getGroupNames()               — return cell array of group names
%       nGroups()                     — number of groups
%       hasGroup(name)                — logical, does group exist?
%       getAll()                      — return struct array of all groups
%       moveToGroup(indices, fromName, toName) — move between groups
%       toStruct()                    — serialise for saving
%       fromStruct(s)                 — restore from saved struct
%
%   Example:
%       grp = bosonPlotter.datasetGroups();
%       grp.createGroup('M(H) curves', [1 2 3]);
%       grp.createGroup('XRD scans', [4 5]);
%       names = grp.getGroupNames();  % {'M(H) curves', 'XRD scans'}
%       idx = grp.getGroup('M(H) curves');  % [1 2 3]

    properties (Access = private)
        names   cell = {}     % {1×N} group names
        members cell = {}     % {1×N} each cell contains a row vector of indices
    end

    methods
        function obj = datasetGroups()
            obj.names = {};
            obj.members = {};
        end

        function createGroup(obj, name, indices)
            arguments
                obj
                name (1,1) string
                indices (1,:) double = []
            end
            if obj.hasGroup(name)
                error('bosonPlotter:datasetGroups:exists', ...
                    'Group "%s" already exists.', name);
            end
            obj.names{end+1} = char(name);
            obj.members{end+1} = unique(round(indices));
        end

        function deleteGroup(obj, name)
            idx = obj.findGroup(name);
            obj.names(idx) = [];
            obj.members(idx) = [];
        end

        function renameGroup(obj, oldName, newName)
            arguments
                obj
                oldName (1,1) string
                newName (1,1) string
            end
            idx = obj.findGroup(oldName);
            if obj.hasGroup(newName)
                error('bosonPlotter:datasetGroups:exists', ...
                    'Group "%s" already exists.', newName);
            end
            obj.names{idx} = char(newName);
        end

        function addToGroup(obj, name, indices)
            idx = obj.findGroup(name);
            obj.members{idx} = unique([obj.members{idx}, round(indices)]);
        end

        function removeFromGroup(obj, name, indices)
            idx = obj.findGroup(name);
            obj.members{idx} = setdiff(obj.members{idx}, round(indices));
        end

        function indices = getGroup(obj, name)
            idx = obj.findGroup(name);
            indices = obj.members{idx};
        end

        function names = getGroupNames(obj)
            names = obj.names;
        end

        function n = nGroups(obj)
            n = numel(obj.names);
        end

        function tf = hasGroup(obj, name)
            tf = any(strcmp(obj.names, char(name)));
        end

        function groups = getAll(obj)
            %GETALL  Return struct array with .name and .indices fields.
            n = numel(obj.names);
            if n == 0
                groups = struct('name', {}, 'indices', {});
                return;
            end
            groups = struct('name', obj.names, 'indices', obj.members);
        end

        function moveToGroup(obj, indices, fromName, toName)
            obj.removeFromGroup(fromName, indices);
            obj.addToGroup(toName, indices);
        end

        function s = toStruct(obj)
            %TOSTRUCT  Serialise for saving to .mat file.
            s.names = obj.names;
            s.members = obj.members;
        end

        function fromStruct(obj, s)
            %FROMSTRUCT  Restore from a saved struct.
            if isfield(s, 'names') && isfield(s, 'members')
                obj.names = s.names;
                obj.members = s.members;
            end
        end
    end

    methods (Access = private)
        function idx = findGroup(obj, name)
            idx = find(strcmp(obj.names, char(name)), 1);
            if isempty(idx)
                error('bosonPlotter:datasetGroups:notFound', ...
                    'Group "%s" not found.', name);
            end
        end
    end
end
