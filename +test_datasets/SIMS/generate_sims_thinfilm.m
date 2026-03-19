function fp = generate_sims_thinfilm()
%GENERATE_SIMS_THINFILM  Create a realistic synthetic SIMS depth profile CSV.
%
%   fp = generate_sims_thinfilm()
%
%   Writes 'sims_thinfilm_stack.csv' into tests/fixtures/ using the vendor
%   multi-row header format (Eurofins EAG style).  The profile models a
%   4-layer thin-film stack on a Si substrate:
%
%     Surface → 0 nm
%     Layer 4 (TaN cap)       :   0 –  40 nm   (high Ta, N; surface H/C/F)
%     Layer 3 (HfO₂ high-k)  :  40 –  80 nm   (high Hf, O)
%     Layer 2 (Al₂O₃)        :  80 – 120 nm   (high Al, O)
%     Layer 1 (Ta barrier)    : 120 – 160 nm   (high Ta)
%     Si substrate            : 160+ nm        (high Si)
%
%   8 elements: H, C, O, F, N, Al->, Si->, Ta->
%   273 depth points per element with per-element depth offsets and ~5%
%   multiplicative noise (seeded RNG for reproducibility).
%
%   The file is idempotent — calling this function always overwrites
%   the fixture with identical content (deterministic via rng(42)).
%
%   See also PARSER.IMPORTSIMS

    rng(42);
    nPts = 273;

    % Per-element depth vectors (vendor instruments have small offsets)
    depthOffsets = [0.27, 0.32, 0.37, 0.48, 0.53, 0.03, 0.11, 0.46];
    depths = cell(1, 8);
    for ei = 1:8
        depths{ei} = linspace(depthOffsets(ei), 200 + depthOffsets(ei), nPts)';
    end

    % erfc-based layer builder
    layer = @(z, top, bot, w) 0.5 * (erfc((z - bot) ./ w) - erfc((z - top) ./ w));

    % --- H: surface contamination peak, then background ---
    zH = depths{1};
    H = 5e22 * exp(-zH / 5) + 2e19 * ones(size(zH));

    % --- C: surface contamination, slight enrichment in TaN cap ---
    zC = depths{2};
    C = 1e20 * exp(-zC / 3) ...
      + 3e19 * layer(zC, 0, 40, 4) ...
      + 5e17 * ones(size(zC));

    % --- O: high in HfO₂ (40-80) and Al₂O₃ (80-120), low elsewhere ---
    zO = depths{3};
    O = 4.5e22 * layer(zO, 40, 80, 3) ...
      + 3.8e22 * layer(zO, 80, 120, 3) ...
      + 1e19  * ones(size(zO));

    % --- F: surface contaminant, minor incorporation in HfO₂ ---
    zF = depths{4};
    F = 2e19 * exp(-zF / 6) ...
      + 8e18 * layer(zF, 40, 80, 4) ...
      + 5e16 * ones(size(zF));

    % --- N: high in TaN cap (0-40), otherwise low ---
    zN = depths{5};
    N = 2.5e22 * layer(zN, 0, 40, 3) ...
      + 3e17  * ones(size(zN));

    % --- Al: high in Al₂O₃ layer (80-120) ---
    zAl = depths{6};
    Al = 3.2e22 * layer(zAl, 80, 120, 3) ...
       + 1e17  * ones(size(zAl));

    % --- Si: substrate (160+), traces elsewhere ---
    zSi = depths{7};
    Si = 5e22  * 0.5 .* erfc(-(zSi - 160) ./ 4) ...
       + 2e18  * ones(size(zSi));

    % --- Ta: TaN cap (0-40) + Ta barrier (120-160) ---
    zTa = depths{8};
    Ta = 3.5e22 * layer(zTa, 0, 40, 3) ...
       + 3.0e22 * layer(zTa, 120, 160, 3) ...
       + 5e17  * ones(size(zTa));

    % Add multiplicative Poisson-like noise (~5% relative)
    concs = {H, C, O, F, N, Al, Si, Ta};
    for ei = 1:8
        noise = 1 + 0.05 * randn(nPts, 1);
        noise(noise < 0.5) = 0.5;
        concs{ei} = concs{ei} .* noise;
    end

    % ── Write CSV ──────────────────────────────────────────────────────
    fixtureDir = fileparts(mfilename('fullpath'));
    fp = fullfile(fixtureDir, 'sims_thinfilm_stack.csv');
    fid = fopen(fp, 'w');
    assert(fid ~= -1, 'Cannot create fixture file: %s', fp);
    cleanObj = onCleanup(@() fclose(fid)); %#ok<NASGU>

    % Vendor metadata block
    fprintf(fid, 'Eurofins EAG Materials Science, LLC\n');
    fprintf(fid, ':Sample 2829\n');
    fprintf(fid, '2/17/2026\n');
    fprintf(fid, 'Drawn Curves,8\n');
    fprintf(fid, 'Num of Cycles,%d\n', nPts);
    fprintf(fid, '\n');

    % Three-row column header block
    fprintf(fid, 'H,,C,,O,,F,,N,,AL->,,Si->,,Ta->\n');
    fprintf(fid, 'Depth,CONC.,Depth,CONC.,Depth,CONC.,Depth,CONC.,Depth,CONC.,Depth,CONC.,Depth,CONC.,Depth,CONC.\n');
    fprintf(fid, '(nm),(atoms/cc),(nm),(atoms/cc),(nm),(atoms/cc),(nm),(atoms/cc),(nm),(atoms/cc),(nm),(arb. units),(nm),(arb. units),(nm),(arb. units)\n');
    fprintf(fid, '\n');

    % Data rows
    for ri = 1:nPts
        parts = cell(1, 8);
        for ei = 1:8
            parts{ei} = sprintf('%.5g,%.4E', depths{ei}(ri), concs{ei}(ri));
        end
        fprintf(fid, '%s\n', strjoin(parts, ','));
    end

    rng('default');
end
