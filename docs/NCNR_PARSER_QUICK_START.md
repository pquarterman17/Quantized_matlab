# NCNR Parser Quick Start Guide

## Installation

The parser is already part of the toolbox. Just run once:
```matlab
setupToolbox
```

## Basic Usage

### Load a Single File
```matlab
% Load the R++ (non-spin-flip) channel
data = parser.importNCNRDat('+test_datasets/NCNR/PNR_SF/S11_Si_YIG_Co_mult_domain_abinitio-1-refl.datA');

% Inspect the loaded data
disp(data.labels);              % {'Q', 'dQ', 'R', 'dR', 'theory', 'fresnel'}
disp(size(data.values));        % 94 × 5 data matrix
disp(data.metadata);            % Metadata including polarization state
```

### Auto-Detect File Type
```matlab
% Let importAuto figure out which parser to use
data = parser.importAuto('S11_Si_YIG_Co_mult_domain_abinitio-1-refl.datA');
```

## Plotting Examples

### Plot Single Reflectivity Curve
```matlab
data = parser.importNCNRDat('sample.datA');

figure;
errorbar(data.time, data.values(:, 2), data.values(:, 3), 'o');
xlabel('Q (Å⁻¹)');
ylabel('Reflectivity R');
title('Neutron Reflectivity');
grid on;

% Add theory curve
hold on;
plot(data.time, data.values(:, 4), '-r', 'DisplayName', 'Theory');
legend;
```

### Compare All 4 Polarizations
```matlab
basePath = '+test_datasets/NCNR/PNR_SF/S11_Si_YIG_Co_mult_domain_abinitio-1-refl';

% Load all 4 channels
datA = parser.importNCNRDat([basePath '.datA']);
datB = parser.importNCNRDat([basePath '.datB']);
datC = parser.importNCNRDat([basePath '.datC']);
datD = parser.importNCNRDat([basePath '.datD']);

% Plot all together
figure;
subplot(2, 2, 1); plot(datA.time, datA.values(:, 2)); title('R++ (NSF)'); grid on;
subplot(2, 2, 2); plot(datB.time, datB.values(:, 2)); title('R+- (SF)'); grid on;
subplot(2, 2, 3); plot(datC.time, datC.values(:, 2)); title('R-+ (SF)'); grid on;
subplot(2, 2, 4); plot(datD.time, datD.values(:, 2)); title('R-- (NSF)'); grid on;

% Compare Q ranges
fprintf('Q ranges:\n');
fprintf('  A/D: %.5f–%.5f Å⁻¹\n', min(datA.time), max(datA.time));
fprintf('  B/C: %.5f–%.5f Å⁻¹\n', min(datB.time), max(datB.time));
```

### Plot on Log Scale
```matlab
data = parser.importNCNRDat('sample.datA');

loglog(data.time, data.values(:, 2), 'o', 'DisplayName', 'Measured');
hold on;
loglog(data.time, data.values(:, 4), '-', 'DisplayName', 'Theory');
xlabel('Q (Å⁻¹)');
ylabel('Reflectivity R');
legend;
grid on;
```

## Data Access Patterns

### Extract Individual Columns
```matlab
data = parser.importNCNRDat('sample.datA');

Q     = data.time;           % [94×1] Q vector
dQ    = data.values(:, 1);   % [94×1] Q uncertainty
R     = data.values(:, 2);   % [94×1] Measured reflectivity
dR    = data.values(:, 3);   % [94×1] Reflectivity uncertainty
theory = data.values(:, 4);  % [94×1] Fitted theory
fresnel = data.values(:, 5); % [94×1] Fresnel background
```

### Access Metadata
```matlab
data = parser.importNCNRDat('sample.datA');

% Get polarization state
pol = data.metadata.parserSpecific.polarization;  % '++', '+-', '-+', '--'

% Get measurement parameters
intensity = data.metadata.parserSpecific.intensity;      % ~0.86
background = data.metadata.parserSpecific.background;   % 0

% Get file source
source_file = data.metadata.filename;  % Full path

% Get parser info
parser_name = data.metadata.parserSpecific;  % 'NCNR reflectometer'
```

## Understanding Spin Projections

NCNR uses polarized neutrons with 4 measurable channels:

| Extension | Polarization | Meaning | Typical Magnitude |
|-----------|--------------|---------|-------------------|
| `.datA` | `++` | Spin-up incident, up detected (NSF) | ~0.86 (large) |
| `.datB` | `+-` | Spin-up incident, down detected (SF) | ~-0.003 (small, can be negative) |
| `.datC` | `-+` | Spin-down incident, up detected (SF) | ~-0.003 (small, can be negative) |
| `.datD` | `--` | Spin-down incident, down detected (NSF) | ~0.86 (large) |

**NSF** (non-spin-flip): Large reflectivity, mostly positive, >0.8
**SF** (spin-flip): Small reflectivity, can be negative, ~0.003

## Batch Processing

### Load Multiple Files in a Loop
```matlab
basePath = '+test_datasets/NCNR/PNR_SF/S11_Si_YIG_Co_mult_domain_abinitio-1-refl';
channels = {'datA', 'datB', 'datC', 'datD'};

results = struct();
for i = 1:numel(channels)
    filepath = [basePath '.' channels{i}];
    results.(channels{i}) = parser.importNCNRDat(filepath);

    % Print summary
    pol = results.(channels{i}).metadata.parserSpecific.polarization;
    R_mean = mean(results.(channels{i}).values(:, 2), 'omitnan');
    fprintf('%s (%s): mean R = %.6f\n', channels{i}, pol, R_mean);
end
```

### Compare Theory vs Experiment
```matlab
data = parser.importNCNRDat('sample.datA');

% Calculate chi-squared
R_exp = data.values(:, 2);
R_theory = data.values(:, 4);
dR = data.values(:, 3);

chi2 = sum(((R_exp - R_theory) ./ dR).^2) / (numel(R_exp) - 1);
fprintf('Chi-squared: %.4f\n', chi2);
```

## Tips & Tricks

### Q-dependent Uncertainty
Some files have constant dQ, others have Q-dependent dQ. The parser preserves both:
```matlab
data = parser.importNCNRDat('sample.datA');
dQ = data.values(:, 1);  % Vary with Q or constant
plot(data.time, dQ);     % See the pattern
```

### Handling Missing Data
If any rows contain NaN values, you can filter them:
```matlab
data = parser.importNCNRDat('sample.datA');
R = data.values(:, 2);

% Keep only valid rows
valid = ~isnan(R);
Q_clean = data.time(valid);
R_clean = R(valid);
```

### Using the Plotting Package
The toolbox includes plotting helpers:
```matlab
data = parser.importNCNRDat('sample.datA');

th = styles.default();  % Get default theme
fig = figure;
plot(data.time, data.values(:, 2), 'Color', plotting.lineColors(1, th));
plotting.formatAxes(gca, th, 'XLabel', 'Q (Å⁻¹)', 'YLabel', 'Reflectivity');
plotting.saveFigure(fig, 'reflectivity.pdf');
```

## Troubleshooting

### File Not Found
```matlab
% Make sure you're using the right path
file = '+test_datasets/NCNR/PNR_SF/S11_Si_YIG_Co_mult_domain_abinitio-1-refl.datA';
data = parser.importNCNRDat(file);
```

### Wrong Polarization
The extension determines polarization—always use the correct one:
- `.datA` → `R++` (use for non-spin-flip analysis)
- `.datB` → `R+-` (use for spin-flip analysis)
- `.datC` → `-+` (use for spin-flip analysis)
- `.datD` → `R--` (use for non-spin-flip analysis)

### Import Error
If `importNCNRDat` not found, run:
```matlab
setupToolbox  % Adds +parser to path
```

## See Also

- `NCNR_PARSER_VERIFICATION_REPORT.md` — Full technical report
- `+parser/importNCNRDat.m` — Source code
- `+parser/importAuto.m` — Auto-detection and dispatch
- `Boson` — Interactive import GUI (can use importNCNRDat indirectly)

---

**Questions?** Check the verification report or examine the parser source code.
