function build_icons()
%BUILD_ICONS  Generate 24x24 PNG icons for the FermiViewer transform toolbar.
%   Run once (or whenever the icon design changes). Writes RGBA PNGs to
%   the same directory as this script. All drawing is done on a pixel
%   canvas with manual anti-aliasing so the icons do not depend on
%   capturing a rendered figure.
%
%   Icons produced:
%       rot_cw.png       rotate 90 deg clockwise (curved arrow)
%       rot_ccw.png      rotate 90 deg counter-clockwise
%       flip_h.png       horizontal flip (left-right mirror)
%       flip_v.png       vertical flip (top-bottom mirror)
%       zoom.png         magnifier with plus
%       fit.png          reset/fit-to-window (four corner arrows)
%       reset_all.png    reset all transforms (circular arrow)
%       crop.png         crop selection (L-brackets)
%
%   Run:  run icons/fermiviewer/build_icons

outDir = fileparts(mfilename('fullpath'));
sz     = 24;                 % 24x24 px
fg     = [0.20 0.20 0.22];   % foreground (near-black)
accent = [0.20 0.55 0.85];   % blue accent for the + in zoom

write_icon(outDir, 'rot_cw.png',    draw_rot_cw(sz, fg));
write_icon(outDir, 'rot_ccw.png',   draw_rot_ccw(sz, fg));
write_icon(outDir, 'flip_h.png',    draw_flip_h(sz, fg));
write_icon(outDir, 'flip_v.png',    draw_flip_v(sz, fg));
write_icon(outDir, 'zoom.png',      draw_zoom(sz, fg, accent));
write_icon(outDir, 'fit.png',       draw_fit(sz, fg));
write_icon(outDir, 'reset_all.png', draw_reset_all(sz, fg));
write_icon(outDir, 'crop.png',      draw_crop(sz, fg));

fprintf('Wrote 8 icons to %s\n', outDir);
end

% ────────────────────────────────────────────────────────────────────────
function write_icon(outDir, name, rgba)
    p = fullfile(outDir, name);
    imwrite(rgba(:,:,1:3), p, 'Alpha', rgba(:,:,4));
end

function rgba = blank(sz)
    rgba = zeros(sz, sz, 4, 'uint8');
end

function rgba = paint(rgba, mask, color)
    mr = double(rgba(:,:,1)) / 255;
    mg = double(rgba(:,:,2)) / 255;
    mb = double(rgba(:,:,3)) / 255;
    ma = double(rgba(:,:,4)) / 255;
    % Over-compositing: new color paints over with alpha = mask
    a = mask;
    outA = a + ma .* (1 - a);
    outR = (color(1).*a + mr.*ma.*(1-a)) ./ max(outA, eps);
    outG = (color(2).*a + mg.*ma.*(1-a)) ./ max(outA, eps);
    outB = (color(3).*a + mb.*ma.*(1-a)) ./ max(outA, eps);
    rgba(:,:,1) = uint8(round(outR * 255));
    rgba(:,:,2) = uint8(round(outG * 255));
    rgba(:,:,3) = uint8(round(outB * 255));
    rgba(:,:,4) = uint8(round(outA * 255));
end

function m = disk_mask(sz, cx, cy, r)
    [X, Y] = meshgrid(1:sz, 1:sz);
    m = max(0, min(1, r + 0.5 - sqrt((X-cx).^2 + (Y-cy).^2)));
end

function m = line_mask(sz, x1, y1, x2, y2, thickness)
    [X, Y] = meshgrid(1:sz, 1:sz);
    px = x2 - x1; py = y2 - y1;
    L2 = px*px + py*py;
    if L2 == 0
        d = sqrt((X-x1).^2 + (Y-y1).^2);
    else
        t = ((X - x1)*px + (Y - y1)*py) / L2;
        t = max(0, min(1, t));
        projX = x1 + t*px;
        projY = y1 + t*py;
        d = sqrt((X - projX).^2 + (Y - projY).^2);
    end
    m = max(0, min(1, thickness/2 + 0.5 - d));
end

function m = arc_mask(sz, cx, cy, r, a1, a2, thickness)
    [X, Y] = meshgrid(1:sz, 1:sz);
    dx = X - cx; dy = Y - cy;
    dist = sqrt(dx.^2 + dy.^2);
    ang = atan2(-dy, dx);
    ang = mod(ang, 2*pi);
    a1n = mod(a1, 2*pi);
    a2n = mod(a2, 2*pi);
    if a2n >= a1n
        inArc = ang >= a1n & ang <= a2n;
    else
        inArc = ang >= a1n | ang <= a2n;
    end
    m = max(0, min(1, thickness/2 + 0.5 - abs(dist - r)));
    m(~inArc) = 0;
end

function m = tri_mask(sz, v)
    [X, Y] = meshgrid(1:sz, 1:sz);
    s1 = side_val(v(1,1), v(1,2), v(2,1), v(2,2), X, Y);
    s2 = side_val(v(2,1), v(2,2), v(3,1), v(3,2), X, Y);
    s3 = side_val(v(3,1), v(3,2), v(1,1), v(1,2), X, Y);
    inside = (s1 >= 0 & s2 >= 0 & s3 >= 0) | (s1 <= 0 & s2 <= 0 & s3 <= 0);
    m = double(inside);
end

function s = side_val(ax, ay, bx, by, px, py)
    s = (px - ax).*(by - ay) - (py - ay).*(bx - ax);
end

function m = tri_outline(sz, v, th)
    m = max(max(line_mask(sz, v(1,1), v(1,2), v(2,1), v(2,2), th), ...
                line_mask(sz, v(2,1), v(2,2), v(3,1), v(3,2), th)), ...
                line_mask(sz, v(3,1), v(3,2), v(1,1), v(1,2), th));
end

function m = arrow_mask(sz, x1, y1, x2, y2, shaftTh, headSz)
    m = line_mask(sz, x1, y1, x2, y2, shaftTh);
    dx = x2 - x1; dy = y2 - y1;
    L = sqrt(dx*dx + dy*dy);
    if L < 1e-3; return; end
    ux = dx/L; uy = dy/L;
    px = -uy; py = ux;
    tip   = [x2, y2];
    baseC = [x2 - ux*headSz, y2 - uy*headSz];
    left  = baseC + [px, py]*headSz*0.6;
    right = baseC - [px, py]*headSz*0.6;
    m = max(m, tri_mask(sz, [tip; left; right]));
end

% ── Individual icon designs ─────────────────────────────────────────────
function rgba = draw_rot_cw(sz, fg)
    rgba = blank(sz);
    cx = sz/2 + 0.5; cy = sz/2 + 0.5;
    r  = sz*0.34;
    % Visual CW arc on screen: math CCW (because y is flipped in atan2).
    % Arc sweeps from right side (a1=0 + small gap) CCW in math
    % = on screen: top -> left -> bottom  (that is CCW visually).
    % We want CW visually, so sweep from left (pi) CCW (math) to -pi/2
    % which on screen means top -> right -> bottom (CW visually).
    rgba = paint(rgba, arc_mask(sz, cx, cy, r, 3*pi/2 + 0.1, pi, 1.9), fg);
    % Arrow head at bottom tip
    tipX = cx; tipY = cy + r + 0.8;
    arrow = tri_mask(sz, [tipX, tipY + 2.4;
                          tipX - 2.6, tipY - 1.0;
                          tipX + 2.6, tipY - 1.0]);
    rgba = paint(rgba, arrow, fg);
end

function rgba = draw_rot_ccw(sz, fg)
    rgba = blank(sz);
    cx = sz/2 + 0.5; cy = sz/2 + 0.5;
    r  = sz*0.34;
    rgba = paint(rgba, arc_mask(sz, cx, cy, r, 0, 3*pi/2 - 0.1, 1.9), fg);
    tipX = cx; tipY = cy + r + 0.8;
    arrow = tri_mask(sz, [tipX, tipY + 2.4;
                          tipX - 2.6, tipY - 1.0;
                          tipX + 2.6, tipY - 1.0]);
    rgba = paint(rgba, arrow, fg);
end

function rgba = draw_flip_h(sz, fg)
    rgba = blank(sz);
    cx = sz/2 + 0.5;
    % Dashed vertical mirror line
    for y = 2.5:3:sz-1.5
        rgba = paint(rgba, line_mask(sz, cx, y, cx, y + 1.6, 1.4), fg);
    end
    th = 1.6;
    vL = [4, 5; 4, sz-4; cx-3, sz/2+0.5];
    rgba = paint(rgba, tri_outline(sz, vL, th), fg);
    vR = [sz-3, 5; sz-3, sz-4; cx+3, sz/2+0.5];
    rgba = paint(rgba, tri_outline(sz, vR, th), fg);
end

function rgba = draw_flip_v(sz, fg)
    rgba = blank(sz);
    cy = sz/2 + 0.5;
    for x = 2.5:3:sz-1.5
        rgba = paint(rgba, line_mask(sz, x, cy, x + 1.6, cy, 1.4), fg);
    end
    th = 1.6;
    vT = [5, 4; sz-4, 4; sz/2+0.5, cy-3];
    rgba = paint(rgba, tri_outline(sz, vT, th), fg);
    vB = [5, sz-3; sz-4, sz-3; sz/2+0.5, cy+3];
    rgba = paint(rgba, tri_outline(sz, vB, th), fg);
end

function rgba = draw_zoom(sz, fg, accent)
    rgba = blank(sz);
    cx = sz*0.42; cy = sz*0.42; r = sz*0.28;
    outer = disk_mask(sz, cx, cy, r);
    inner = disk_mask(sz, cx, cy, r - 2.2);
    ring = max(0, outer - inner);
    rgba = paint(rgba, ring, fg);
    hx1 = cx + r*0.70; hy1 = cy + r*0.70;
    hx2 = sz - 3;       hy2 = sz - 3;
    rgba = paint(rgba, line_mask(sz, hx1, hy1, hx2, hy2, 2.4), fg);
    rgba = paint(rgba, line_mask(sz, cx - 3, cy, cx + 3, cy, 1.6), accent);
    rgba = paint(rgba, line_mask(sz, cx, cy - 3, cx, cy + 3, 1.6), accent);
end

function rgba = draw_fit(sz, fg)
    rgba = blank(sz);
    th = 1.6;
    off = 3;
    len = 5;
    rgba = paint(rgba, line_mask(sz, off, off, off+len, off, th), fg);
    rgba = paint(rgba, line_mask(sz, off, off, off, off+len, th), fg);
    rgba = paint(rgba, line_mask(sz, sz-off, off, sz-off-len, off, th), fg);
    rgba = paint(rgba, line_mask(sz, sz-off, off, sz-off, off+len, th), fg);
    rgba = paint(rgba, line_mask(sz, off, sz-off, off+len, sz-off, th), fg);
    rgba = paint(rgba, line_mask(sz, off, sz-off, off, sz-off-len, th), fg);
    rgba = paint(rgba, line_mask(sz, sz-off, sz-off, sz-off-len, sz-off, th), fg);
    rgba = paint(rgba, line_mask(sz, sz-off, sz-off, sz-off, sz-off-len, th), fg);
    cx = sz/2 + 0.5; cy = sz/2 + 0.5;
    rgba = paint(rgba, arrow_mask(sz, off+1.5, off+1.5, cx-2, cy-2, 1.4, 2.0), fg);
    rgba = paint(rgba, arrow_mask(sz, sz-off-1.5, off+1.5, cx+2, cy-2, 1.4, 2.0), fg);
    rgba = paint(rgba, arrow_mask(sz, off+1.5, sz-off-1.5, cx-2, cy+2, 1.4, 2.0), fg);
    rgba = paint(rgba, arrow_mask(sz, sz-off-1.5, sz-off-1.5, cx+2, cy+2, 1.4, 2.0), fg);
end

function rgba = draw_reset_all(sz, fg)
    rgba = blank(sz);
    cx = sz/2 + 0.5; cy = sz/2 + 0.5;
    r  = sz*0.32;
    % ~11/12 of a circle with an arrow
    rgba = paint(rgba, arc_mask(sz, cx, cy, r, -pi/5, 3*pi/2 + 0.2, 1.9), fg);
    aAng = -pi/5;
    tipX = cx + r*cos(aAng);
    tipY = cy - r*sin(aAng);
    tx = -sin(aAng); ty = -cos(aAng);
    hs = 3.0;
    px = -ty; py = tx;
    left  = [tipX - tx*hs + px*hs*0.7, tipY - ty*hs + py*hs*0.7];
    right = [tipX - tx*hs - px*hs*0.7, tipY - ty*hs - py*hs*0.7];
    rgba = paint(rgba, tri_mask(sz, [tipX, tipY; left; right]), fg);
end

function rgba = draw_crop(sz, fg)
    rgba = blank(sz);
    th = 1.8;
    rgba = paint(rgba, line_mask(sz, 4, 7, sz-3, 7, th), fg);
    rgba = paint(rgba, line_mask(sz, 7, 4, 7, sz-3, th), fg);
    rgba = paint(rgba, line_mask(sz, sz-7, 4, sz-7, sz-3, th), fg);
    rgba = paint(rgba, line_mask(sz, 4, sz-7, sz-3, sz-7, th), fg);
end
