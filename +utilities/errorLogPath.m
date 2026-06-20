function p = errorLogPath()
%ERRORLOGPATH  Absolute path of the toolbox error log (gui_bug_log.txt).
%
%   p = utilities.errorLogPath()
%
%   Single source of truth for where utilities.logError appends entries, so
%   user-facing messages ("see <path>") and the logger never drift apart.
%   The file lives at the toolbox root, alongside the +utilities package.

    p = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'gui_bug_log.txt');
end
