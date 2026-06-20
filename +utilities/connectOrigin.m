function [origin, progId] = connectOrigin()
%CONNECTORIGIN  Connect to OriginPro via COM, preferring the running instance.
%
%   origin            = utilities.connectOrigin()
%   [origin, progId]  = utilities.connectOrigin()
%
%   progId is the ProgID that succeeded ('' on failure) — callers log it so a
%   fallback to 'Origin.Application' (a possibly-separate instance) is visible.
%
%   Tries the ProgIDs in order:
%     1. 'Origin.ApplicationSI' — Single Instance.  Attaches to the OriginPro
%        the user already has open (or launches one if none is running).  This
%        is OriginLab's recommended ProgID for interactive automation, so the
%        data lands in the window the user is looking at.
%     2. 'Origin.Application'   — fallback.  Always usable but may spawn a
%        SEPARATE (often hidden) instance, which is why it is not tried first.
%
%   Returns the COM handle, or [] when OriginPro is not installed / COM fails.
%
%   See also UTILITIES.TOORIGIN, BOSONPLOTTER.SENDTOORIGIN.

    origin  = [];
    progId  = '';
    progIds = {'Origin.ApplicationSI', 'Origin.Application'};
    for k = 1:numel(progIds)
        try
            origin = actxserver(progIds{k});
            progId = progIds{k};
            return;
        catch
            origin = [];
        end
    end
end
