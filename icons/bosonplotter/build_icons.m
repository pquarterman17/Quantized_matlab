function build_icons()
%BUILD_ICONS  Re-fetch the BosonPlotter toolbar icons from Lucide.
%   The PNGs in this directory are rasterized from the Lucide icon set
%   (https://lucide.dev, MIT license) at 24x24 px in colour #333338.
%   They are fetched as SVG from the Iconify API and rasterized by a
%   small Node script — there is no native MATLAB SVG renderer.
%
%   Run only when the icon set changes. PNGs are checked into git.
%
%   Requires:  Node.js >= 18 ; npm install @resvg/resvg-js
%
%   Filenames mirror the action.id used in BosonPlotter.m's tbActions
%   registry, so the toolbar code resolves icons via `<id>.png` directly.
%
%       cursor.png         <- crosshair
%       autoscale.png      <- maximize-2
%       clearOverlays.png  <- eraser
%       grid.png           <- grid-3x3
%       legend.png         <- list
%       copy.png           <- clipboard-copy
%       save.png           <- save
%       zoomIn.png         <- zoom-in
%       zoomOut.png        <- zoom-out
%       pan.png            <- move
%       figBuilder.png     <- layout-template
%       export.png         <- file-spreadsheet
%       animate.png        <- play
%       workspace.png      <- table
%       undo.png           <- undo-2
%       redo.png           <- redo-2
%       watchFile.png      <- eye
%       stop.png           <- square   (icon shown on the animate button while running)
%
%   Run:  run icons/bosonplotter/build_icons

outDir = fileparts(mfilename('fullpath'));

[status, ~] = system('node --version');
if status ~= 0
    error('build_icons:noNode', ...
        ['Node.js was not found on PATH. Install Node 18+ from https://nodejs.org\n' ...
         'then rerun build_icons. The PNGs are checked into git, so this is\n' ...
         'only required when changing icon source/colour/size.']);
end

tmpDir = fullfile(tempdir, 'lucide-render');
if ~isfolder(tmpDir)
    mkdir(tmpDir);
end
scriptPath = fullfile(tmpDir, 'render-bosonplotter.mjs');
fid = fopen(scriptPath, 'w');
fprintf(fid, '%s', renderScript());
fclose(fid);

if ispc
    cdPrefix = sprintf('cd /d "%s" && ', tmpDir);
    devNull  = 'nul';
else
    cdPrefix = sprintf('cd "%s" && ', tmpDir);
    devNull  = '/dev/null';
end

if ~isfolder(fullfile(tmpDir, 'node_modules', '@resvg', 'resvg-js'))
    fprintf('Installing @resvg/resvg-js into %s ...\n', tmpDir);
    cmd = [cdPrefix sprintf('npm init -y >%s && npm install --no-audit --no-fund --silent @resvg/resvg-js', devNull)];
    [status, out] = system(cmd);
    if status ~= 0
        error('build_icons:npmInstall', 'npm install failed:\n%s', out);
    end
end

cmd = [cdPrefix sprintf('node render-bosonplotter.mjs "%s"', strrep(outDir, '\', '/'))];
[status, out] = system(cmd);
if status ~= 0
    error('build_icons:render', 'render failed:\n%s', out);
end
disp(out);
end

% ────────────────────────────────────────────────────────────────────────
function s = renderScript()
%RENDERSCRIPT  Inline ESM Node script that fetches Lucide SVGs and
%   rasterizes them via @resvg/resvg-js.
lines = {
    "import { Resvg } from '@resvg/resvg-js';"
    "import fs from 'node:fs';"
    "import path from 'node:path';"
    ""
    "const outDir = process.argv[2];"
    "if (!outDir) { console.error('usage: node render-bosonplotter.mjs <outDir>'); process.exit(1); }"
    ""
    "const color = '#333338';"
    "const sizePx = 24;"
    ""
    "const icons = ["
    "  ['crosshair',        'cursor.png'],"
    "  ['maximize-2',       'autoscale.png'],"
    "  ['eraser',           'clearOverlays.png'],"
    "  ['grid-3x3',         'grid.png'],"
    "  ['list',             'legend.png'],"
    "  ['clipboard-copy',   'copy.png'],"
    "  ['save',             'save.png'],"
    "  ['zoom-in',          'zoomIn.png'],"
    "  ['zoom-out',         'zoomOut.png'],"
    "  ['move',             'pan.png'],"
    "  ['layout-template',  'figBuilder.png'],"
    "  ['file-spreadsheet', 'export.png'],"
    "  ['play',             'animate.png'],"
    "  ['table',            'workspace.png'],"
    "  ['undo-2',           'undo.png'],"
    "  ['redo-2',           'redo.png'],"
    "  ['eye',              'watchFile.png'],"
    "  ['square',           'stop.png'],"
    "];"
    ""
    "for (const [iconName, filename] of icons) {"
    "  const url = `https://api.iconify.design/lucide/${iconName}.svg?color=${encodeURIComponent(color)}`;"
    "  const res = await fetch(url);"
    "  if (!res.ok) { console.error(`fetch failed for ${iconName}: ${res.status}`); process.exit(2); }"
    "  const svg = await res.text();"
    "  const resvg = new Resvg(svg, { fitTo: { mode: 'width', value: sizePx }, background: 'rgba(0,0,0,0)' });"
    "  const pngBuffer = resvg.render().asPng();"
    "  fs.writeFileSync(path.join(outDir, filename), pngBuffer);"
    "  console.log(`  ${filename.padEnd(20)} <- lucide:${iconName}  (${pngBuffer.length} bytes)`);"
    "}"
    ""
    "console.log(`\nWrote ${icons.length} icons to ${outDir}`);"
    };
s = char(strjoin(string(lines), newline));
end
