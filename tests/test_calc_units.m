%TEST_CALC_UNITS  Tests for calc.constants, calc.unitConvert, and calc.elementData.
%
%   Run standalone:  cd tests; run test_calc_units
%   Run from root:   run tests/test_calc_units

clear; clc;

% Ensure toolbox is on the path
thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(thisDir);
if ~contains(path, rootDir)
    addpath(rootDir);
end

fprintf('\n=== test_calc_units ===\n');
passed = 0;
failed = 0;

% ════════════════════════════════════════════════════════════════════
%  CONSTANTS
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- calc.constants ---\n');

C = calc.constants();

% Verify struct has expected fields
fields = {'h','hbar','c','e','kB','NA','mu0','eps0','muB','r_e','m_e','R','F','Phi0'};
for k = 1:numel(fields)
    if isfield(C, fields{k})
        passed = passed + 1;
        fprintf('  PASS: constants has %s\n', fields{k});
    else
        failed = failed + 1;
        fprintf('  FAIL: constants missing %s\n', fields{k});
    end
end

% Spot-check values
vals = {C.c, 2.99792458e8, 1e-2, 'c value';
        C.e, 1.602176634e-19, 1e-28, 'e value';
        C.NA, 6.02214076e23, 1e14, 'NA value';
        C.kB, 1.380649e-23, 1e-32, 'kB value'};
for k = 1:size(vals, 1)
    if abs(vals{k,1} - vals{k,2}) <= vals{k,3}
        passed = passed + 1;
        fprintf('  PASS: %s = %g\n', vals{k,4}, vals{k,1});
    else
        failed = failed + 1;
        fprintf('  FAIL: %s = %g (expected %g)\n', vals{k,4}, vals{k,1}, vals{k,2});
    end
end

% Verify persistent caching
C2 = calc.constants();
if isequal(C, C2)
    passed = passed + 1; fprintf('  PASS: constants cached\n');
else
    failed = failed + 1; fprintf('  FAIL: constants not cached\n');
end

% ════════════════════════════════════════════════════════════════════
%  UNIT CONVERSION — Simple scaling
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- calc.unitConvert: simple scaling ---\n');

convTests = {
    1,     'm',     'cm',    100,     1e-6,  'm to cm'
    100,   'cm',    'm',     1,       1e-6,  'cm to m'
    1,     'nm',    'Ang',   10,      1e-6,  'nm to Ang'
    10,    'Ang',   'nm',    1,       1e-6,  'Ang to nm'
    1,     'um',    'nm',    1000,    1e-6,  'um to nm'
    1000,  'mm',    'm',     1,       1e-6,  'mm to m'
    1,     'km',    'm',     1000,    1e-6,  'km to m'
    1,     'kg',    'g',     1000,    1e-6,  'kg to g'
    1000,  'mg',    'g',     1,       1e-6,  'mg to g'
    1,     'min',   's',     60,      1e-6,  'min to s'
    1,     'hr',    's',     3600,    1e-6,  'hr to s'
    1,     'atm',   'Pa',    101325,  1e-6,  'atm to Pa'
    1,     'Torr',  'Pa',    133.322, 1e-3,  'Torr to Pa'
    1,     'bar',   'Pa',    1e5,     1e-6,  'bar to Pa'
    1,     'GPa',   'Pa',    1e9,     1e-6,  'GPa to Pa'
    1000,  'MPa',   'GPa',   1,       1e-6,  'MPa to GPa'
    1.602176634e-19, 'J', 'eV', 1,    1e-6,  'J to eV'
    1,     'eV',    'J',     1.602176634e-19, 1e-6, 'eV to J'
    1,     'T',     'G',     1e4,     1e-6,  'T to G'
    1,     'mT',    'G',     10,      1e-6,  'mT to G'
    180,   'deg',   'rad',   pi,      1e-6,  'deg to rad'
};

for k = 1:size(convTests, 1)
    val = convTests{k,1}; fromU = convTests{k,2}; toU = convTests{k,3};
    expected = convTests{k,4}; tol = convTests{k,5}; name = convTests{k,6};
    try
        result = calc.unitConvert(val, fromU, toU);
        if abs(result - expected) <= tol
            passed = passed + 1;
            fprintf('  PASS: %s  (%g %s -> %g %s)\n', name, val, fromU, result, toU);
        else
            failed = failed + 1;
            fprintf('  FAIL: %s  (%g %s -> %g %s, expected %g)\n', name, val, fromU, result, toU, expected);
        end
    catch ME
        failed = failed + 1;
        fprintf('  FAIL: %s  ERROR: %s\n', name, ME.message);
    end
end

% ════════════════════════════════════════════════════════════════════
%  UNIT CONVERSION — Compound units
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- calc.unitConvert: compound units ---\n');

compoundTests = {
    1,   'mA/cm^2', 'A/m^2',   10,      1e-6,  'mA/cm^2 to A/m^2'
    10,  'A/m^2',   'mA/cm^2', 1,       1e-6,  'A/m^2 to mA/cm^2'
    1,   'uOhm*cm', 'Ohm*m',   1e-8,   1e-14,  'uOhm*cm to Ohm*m'
    1,   'kA/m',    'A/m',     1000,    1e-6,   'kA/m to A/m'
};

for k = 1:size(compoundTests, 1)
    val = compoundTests{k,1}; fromU = compoundTests{k,2}; toU = compoundTests{k,3};
    expected = compoundTests{k,4}; tol = compoundTests{k,5}; name = compoundTests{k,6};
    try
        result = calc.unitConvert(val, fromU, toU);
        if abs(result - expected) <= tol
            passed = passed + 1;
            fprintf('  PASS: %s  (%g %s -> %g %s)\n', name, val, fromU, result, toU);
        else
            failed = failed + 1;
            fprintf('  FAIL: %s  (%g %s -> %g %s, expected %g)\n', name, val, fromU, result, toU, expected);
        end
    catch ME
        failed = failed + 1;
        fprintf('  FAIL: %s  ERROR: %s\n', name, ME.message);
    end
end

% ════════════════════════════════════════════════════════════════════
%  UNIT CONVERSION — Temperature offsets
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- calc.unitConvert: temperature ---\n');

tempTests = {
    273.15, 'K',  'C',  0,       1e-6,  'K to C (273.15K)'
    0,      'C',  'K',  273.15,  1e-6,  'C to K (0C)'
    300,    'K',  'C',  26.85,   1e-2,  'K to C (300K)'
    0,      'C',  'F',  32,      1e-6,  'C to F (0C)'
    212,    'F',  'C',  100,     1e-2,  'F to C (212F)'
    100,    'C',  'F',  212,     1e-2,  'C to F (100C)'
};

for k = 1:size(tempTests, 1)
    val = tempTests{k,1}; fromU = tempTests{k,2}; toU = tempTests{k,3};
    expected = tempTests{k,4}; tol = tempTests{k,5}; name = tempTests{k,6};
    try
        result = calc.unitConvert(val, fromU, toU);
        if abs(result - expected) <= tol
            passed = passed + 1;
            fprintf('  PASS: %s  (%g %s -> %g %s)\n', name, val, fromU, result, toU);
        else
            failed = failed + 1;
            fprintf('  FAIL: %s  (%g %s -> %g %s, expected %g)\n', name, val, fromU, result, toU, expected);
        end
    catch ME
        failed = failed + 1;
        fprintf('  FAIL: %s  ERROR: %s\n', name, ME.message);
    end
end

% ════════════════════════════════════════════════════════════════════
%  UNIT CONVERSION — Equivalence bridges
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- calc.unitConvert: bridges ---\n');

bridgeTests = {
    1,       'eV',  'nm',  1239.84, 0.1,   'eV to nm'
    1239.84, 'nm',  'eV',  1,       0.01,  'nm to eV'
    1,       'Oe',  'T',   1e-4,    1e-6,  'Oe to T'
    1,       'T',   'Oe',  1e4,     1,     'T to Oe'
    1,       'eV',  'THz', 241.799, 0.1,   'eV to THz'
};

for k = 1:size(bridgeTests, 1)
    val = bridgeTests{k,1}; fromU = bridgeTests{k,2}; toU = bridgeTests{k,3};
    expected = bridgeTests{k,4}; tol = bridgeTests{k,5}; name = bridgeTests{k,6};
    try
        result = calc.unitConvert(val, fromU, toU);
        if abs(result - expected) <= tol
            passed = passed + 1;
            fprintf('  PASS: %s  (%g %s -> %g %s)\n', name, val, fromU, result, toU);
        else
            failed = failed + 1;
            fprintf('  FAIL: %s  (%g %s -> %g %s, expected %g)\n', name, val, fromU, result, toU, expected);
        end
    catch ME
        failed = failed + 1;
        fprintf('  FAIL: %s  ERROR: %s\n', name, ME.message);
    end
end

% ════════════════════════════════════════════════════════════════════
%  UNIT CONVERSION — info struct
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- calc.unitConvert: info struct ---\n');

[~, info] = calc.unitConvert(1, 'mA/cm^2', 'A/m^2');
infoFields = {'factor', 'fromParsed', 'toParsed', 'description', 'latex'};
for k = 1:numel(infoFields)
    if isfield(info, infoFields{k})
        passed = passed + 1;
        fprintf('  PASS: info has %s\n', infoFields{k});
    else
        failed = failed + 1;
        fprintf('  FAIL: info missing %s\n', infoFields{k});
    end
end
if abs(info.factor - 10) < 1e-6
    passed = passed + 1; fprintf('  PASS: info.factor = 10\n');
else
    failed = failed + 1; fprintf('  FAIL: info.factor = %g (expected 10)\n', info.factor);
end

% ════════════════════════════════════════════════════════════════════
%  UNIT CONVERSION — Error handling
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- calc.unitConvert: errors ---\n');

errorTests = {'m', 'kg'; 's', 'Pa'};
for k = 1:size(errorTests, 1)
    try
        calc.unitConvert(1, errorTests{k,1}, errorTests{k,2});
        failed = failed + 1;
        fprintf('  FAIL: %s->%s should error\n', errorTests{k,1}, errorTests{k,2});
    catch
        passed = passed + 1;
        fprintf('  PASS: %s->%s correctly errors\n', errorTests{k,1}, errorTests{k,2});
    end
end

% ════════════════════════════════════════════════════════════════════
%  ELEMENT DATA
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- calc.elementData ---\n');

elements = calc.elementData();

% Basic structure
if numel(elements) == 118
    passed = passed + 1; fprintf('  PASS: 118 elements\n');
else
    failed = failed + 1; fprintf('  FAIL: got %d elements (expected 118)\n', numel(elements));
end

if strcmp(elements(1).symbol, 'H')
    passed = passed + 1; fprintf('  PASS: H is first\n');
else
    failed = failed + 1; fprintf('  FAIL: first element is %s\n', elements(1).symbol);
end

if strcmp(elements(2).symbol, 'He')
    passed = passed + 1; fprintf('  PASS: He is second\n');
else
    failed = failed + 1; fprintf('  FAIL: second element is %s\n', elements(2).symbol);
end

if elements(118).Z == 118
    passed = passed + 1; fprintf('  PASS: Og is Z=118\n');
else
    failed = failed + 1; fprintf('  FAIL: last element Z=%d\n', elements(118).Z);
end

% Spot-check Iron
fe = calc.elementData('bySymbol', 'Fe');
if fe.Z == 26
    passed = passed + 1; fprintf('  PASS: Fe Z=26\n');
else
    failed = failed + 1; fprintf('  FAIL: Fe Z=%d\n', fe.Z);
end
if strcmp(fe.name, 'Iron')
    passed = passed + 1; fprintf('  PASS: Fe name=Iron\n');
else
    failed = failed + 1; fprintf('  FAIL: Fe name=%s\n', fe.name);
end
if abs(fe.mass - 55.845) < 0.01
    passed = passed + 1; fprintf('  PASS: Fe mass=%.3f\n', fe.mass);
else
    failed = failed + 1; fprintf('  FAIL: Fe mass=%.3f (expected ~55.845)\n', fe.mass);
end
if strcmp(fe.category, 'transition metal')
    passed = passed + 1; fprintf('  PASS: Fe category=transition metal\n');
else
    failed = failed + 1; fprintf('  FAIL: Fe category=%s\n', fe.category);
end
if ~isnan(fe.density)
    passed = passed + 1; fprintf('  PASS: Fe has density=%.3f\n', fe.density);
else
    failed = failed + 1; fprintf('  FAIL: Fe density is NaN\n');
end
if ~isnan(fe.bCoherent)
    passed = passed + 1; fprintf('  PASS: Fe has bCoherent=%.2f fm\n', fe.bCoherent);
else
    failed = failed + 1; fprintf('  FAIL: Fe bCoherent is NaN\n');
end

% Spot-check Silicon by Z
si = calc.elementData('byZ', 14);
if strcmp(si.symbol, 'Si')
    passed = passed + 1; fprintf('  PASS: Z=14 is Si\n');
else
    failed = failed + 1; fprintf('  FAIL: Z=14 is %s\n', si.symbol);
end
if abs(si.mass - 28.085) < 0.01
    passed = passed + 1; fprintf('  PASS: Si mass=%.3f\n', si.mass);
else
    failed = failed + 1; fprintf('  FAIL: Si mass=%.3f\n', si.mass);
end

% getProperty
masses = calc.elementData('getProperty', 'mass');
if numel(masses) == 118
    passed = passed + 1; fprintf('  PASS: getProperty returns 118 values\n');
else
    failed = failed + 1; fprintf('  FAIL: getProperty returned %d values\n', numel(masses));
end
if abs(masses(1) - 1.008) < 0.01
    passed = passed + 1; fprintf('  PASS: H mass via getProperty = %.3f\n', masses(1));
else
    failed = failed + 1; fprintf('  FAIL: H mass via getProperty = %.3f\n', masses(1));
end

% Check bCoherent populated for common elements
commonElems = {'O', 'Cu', 'Si', 'Al', 'Ti', 'Ni', 'Au', 'Pt'};
for k = 1:numel(commonElems)
    el = calc.elementData('bySymbol', commonElems{k});
    if ~isnan(el.bCoherent)
        passed = passed + 1;
        fprintf('  PASS: %s has bCoherent=%.2f fm\n', commonElems{k}, el.bCoherent);
    else
        failed = failed + 1;
        fprintf('  FAIL: %s bCoherent is NaN\n', commonElems{k});
    end
end

% ════════════════════════════════════════════════════════════════════
%  SUMMARY
% ════════════════════════════════════════════════════════════════════

fprintf('\n=== Results: %d passed, %d failed ===\n\n', passed, failed);
if failed > 0
    error('test_calc_units:failed', '%d test(s) failed.', failed);
end
