%TEST_CALC_MODULES  Tests for Phase 2 calc modules: crystal, electrical,
%   semiconductor, thinFilm, magnetic, substrates.
%
%   Run:
%     run tests/test_calc_modules

clear; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(thisDir);
if ~contains(path, rootDir)
    addpath(rootDir);
end

fprintf('\n=== test_calc_modules ===\n');
passed = 0;
failed = 0;
C = calc.constants();

% ════════════════════════════════════════════════════════════════════
%  CRYSTAL
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- calc.crystal ---\n');

% dSpacing: cubic Si (111) — d = a/sqrt(3)
r = calc.crystal.dSpacing(5.431, 1, 1, 1);
if abs(r.d - 5.431/sqrt(3)) < 0.001 && strcmp(r.system, 'cubic')
    fprintf('  PASS: dSpacing cubic Si(111)\n'); passed = passed + 1;
else
    fprintf('  FAIL: dSpacing cubic Si(111)\n'); failed = failed + 1;
end

% dSpacing: cubic (100) — d = a
r = calc.crystal.dSpacing(3.905, 1, 0, 0);
if abs(r.d - 3.905) < 1e-6
    fprintf('  PASS: dSpacing cubic (100) d=a\n'); passed = passed + 1;
else
    fprintf('  FAIL: dSpacing cubic (100) d=a\n'); failed = failed + 1;
end

% dSpacing: tetragonal (002)
r = calc.crystal.dSpacing(3.905, 0, 0, 2, c=3.95);
if abs(r.d - 3.95/2) < 0.001 && strcmp(r.system, 'tetragonal')
    fprintf('  PASS: dSpacing tetragonal (002)\n'); passed = passed + 1;
else
    fprintf('  FAIL: dSpacing tetragonal (002)\n'); failed = failed + 1;
end

% twoThetaFromD: Cu Ka, d=3.135 -> ~28.44 deg
r = calc.crystal.twoThetaFromD(3.135);
if abs(r.twoTheta - 2*asind(1.5406/(2*3.135))) < 0.01
    fprintf('  PASS: twoThetaFromD\n'); passed = passed + 1;
else
    fprintf('  FAIL: twoThetaFromD (got %.4f)\n', r.twoTheta); failed = failed + 1;
end

% dFromTwoTheta: inverse
r2 = calc.crystal.dFromTwoTheta(r.twoTheta);
if abs(r2.d - 3.135) < 0.001
    fprintf('  PASS: dFromTwoTheta inverse\n'); passed = passed + 1;
else
    fprintf('  FAIL: dFromTwoTheta inverse\n'); failed = failed + 1;
end

% unitCellVolume: cubic Si — V = a^3
r = calc.crystal.unitCellVolume(5.431);
if abs(r.volume - 5.431^3) < 0.01
    fprintf('  PASS: unitCellVolume cubic Si\n'); passed = passed + 1;
else
    fprintf('  FAIL: unitCellVolume cubic Si\n'); failed = failed + 1;
end

% unitCellVolume: tetragonal
r = calc.crystal.unitCellVolume(3.905, c=3.95);
if abs(r.volume - 3.905^2*3.95) < 0.01
    fprintf('  PASS: unitCellVolume tetragonal\n'); passed = passed + 1;
else
    fprintf('  FAIL: unitCellVolume tetragonal\n'); failed = failed + 1;
end

% atomicDensity: Si — 8 atoms/cell -> ~5e22 atoms/cm^3
r = calc.crystal.atomicDensity(5.431, 8);
if abs(r.density - 5e22)/5e22 < 0.01
    fprintf('  PASS: atomicDensity Si\n'); passed = passed + 1;
else
    fprintf('  FAIL: atomicDensity Si (got %.3e)\n', r.density); failed = failed + 1;
end

% densityFromMolar: Si -> 2.329 g/cm^3
r = calc.crystal.densityFromMolar(28.085, 5.431, 8);
if abs(r.density - 2.329) < 0.01
    fprintf('  PASS: densityFromMolar Si\n'); passed = passed + 1;
else
    fprintf('  FAIL: densityFromMolar Si (got %.4f)\n', r.density); failed = failed + 1;
end

% latticeMismatch: tensile
r = calc.crystal.latticeMismatch(4.0, 3.996);
if abs(r.mismatchPct - 0.1) < 0.02 && strcmp(r.description, 'tensile')
    fprintf('  PASS: latticeMismatch tensile\n'); passed = passed + 1;
else
    fprintf('  FAIL: latticeMismatch tensile\n'); failed = failed + 1;
end

% latticeMismatch: compressive
r = calc.crystal.latticeMismatch(3.9, 4.0);
if strcmp(r.description, 'compressive')
    fprintf('  PASS: latticeMismatch compressive\n'); passed = passed + 1;
else
    fprintf('  FAIL: latticeMismatch compressive\n'); failed = failed + 1;
end

% criticalThickness: positive
r = calc.crystal.criticalThickness(4.0, 3.905);
if r.hc > 0 && r.hcNm > 0
    fprintf('  PASS: criticalThickness positive\n'); passed = passed + 1;
else
    fprintf('  FAIL: criticalThickness positive\n'); failed = failed + 1;
end

% strainFromPoisson
r = calc.crystal.strainFromPoisson(0.01, 0.3);
expect = -2*0.3/0.7 * 0.01;
if abs(r.epsPerp - expect) < 1e-8
    fprintf('  PASS: strainFromPoisson\n'); passed = passed + 1;
else
    fprintf('  FAIL: strainFromPoisson\n'); failed = failed + 1;
end

% tetragonalDistortion
r = calc.crystal.tetragonalDistortion(3.905, 3.95);
if abs(r.cOverA - 3.95/3.905) < 1e-6 && r.distortionPct > 0
    fprintf('  PASS: tetragonalDistortion\n'); passed = passed + 1;
else
    fprintf('  FAIL: tetragonalDistortion\n'); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  ELECTRICAL
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- calc.electrical ---\n');

% resistivity: Rs=10, t=1e-5 cm -> rho=1e-4
r = calc.electrical.resistivity(10, 1e-5);
if abs(r.rho - 1e-4) < 1e-10
    fprintf('  PASS: resistivity\n'); passed = passed + 1;
else
    fprintf('  FAIL: resistivity\n'); failed = failed + 1;
end

% conductivity
r = calc.electrical.conductivity(1e-4);
if abs(r.sigma - 1e4) < 1
    fprintf('  PASS: conductivity\n'); passed = passed + 1;
else
    fprintf('  FAIL: conductivity\n'); failed = failed + 1;
end

% sheetResistance: inverse
r = calc.electrical.sheetResistance(1e-4, 1e-5);
if abs(r.Rs - 10) < 1e-6
    fprintf('  PASS: sheetResistance\n'); passed = passed + 1;
else
    fprintf('  FAIL: sheetResistance\n'); failed = failed + 1;
end

% mobility
r = calc.electrical.mobility(1, 1e16);
muExpect = 1 / (C.e * 1e16 * 1);
if abs(r.mu - muExpect)/muExpect < 1e-6
    fprintf('  PASS: mobility\n'); passed = passed + 1;
else
    fprintf('  FAIL: mobility\n'); failed = failed + 1;
end

% currentDensity
r = calc.electrical.currentDensity(1, 0.01);
if abs(r.J - 100) < 1e-10
    fprintf('  PASS: currentDensity\n'); passed = passed + 1;
else
    fprintf('  FAIL: currentDensity\n'); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  SEMICONDUCTOR
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- calc.semiconductor ---\n');

% materialPresets
m = calc.semiconductor.materialPresets();
if isfield(m, 'Si') && m.Si.Eg == 1.12
    fprintf('  PASS: materialPresets has Si\n'); passed = passed + 1;
else
    fprintf('  FAIL: materialPresets has Si\n'); failed = failed + 1;
end
if isfield(m, 'GaAs') && isfield(m, 'GaN')
    fprintf('  PASS: materialPresets has GaAs/GaN\n'); passed = passed + 1;
else
    fprintf('  FAIL: materialPresets has GaAs/GaN\n'); failed = failed + 1;
end

% intrinsicCarrierConc: Si 300K — ni ~ 1e10
r = calc.semiconductor.intrinsicCarrierConc(Material='Si');
if r.ni > 1e9 && r.ni < 1e11
    fprintf('  PASS: intrinsicCarrierConc Si ni ~ 1e10 (got %.2e)\n', r.ni); passed = passed + 1;
else
    fprintf('  FAIL: intrinsicCarrierConc Si ni (got %.2e)\n', r.ni); failed = failed + 1;
end

% explicit params match preset
r2 = calc.semiconductor.intrinsicCarrierConc(Eg=1.12, meStar=1.08, mhStar=0.81, T=300);
if abs(r.ni - r2.ni)/r.ni < 1e-6
    fprintf('  PASS: intrinsicCarrierConc explicit=preset\n'); passed = passed + 1;
else
    fprintf('  FAIL: intrinsicCarrierConc explicit=preset\n'); failed = failed + 1;
end

% GaAs ni < Si ni
r3 = calc.semiconductor.intrinsicCarrierConc(Material='GaAs');
if r3.ni < r.ni
    fprintf('  PASS: intrinsicCarrierConc GaAs < Si\n'); passed = passed + 1;
else
    fprintf('  FAIL: intrinsicCarrierConc GaAs < Si\n'); failed = failed + 1;
end

% carrierConcentration: n-type
r = calc.semiconductor.carrierConcentration(1e17, 1e15, 1e10);
if strcmp(r.type, 'n') && abs(r.n - 9.9e16)/9.9e16 < 0.02
    fprintf('  PASS: carrierConc n-type\n'); passed = passed + 1;
else
    fprintf('  FAIL: carrierConc n-type\n'); failed = failed + 1;
end

% carrierConcentration: p-type
r = calc.semiconductor.carrierConcentration(1e15, 1e17, 1e10);
if strcmp(r.type, 'p') && r.p > 9e16
    fprintf('  PASS: carrierConc p-type\n'); passed = passed + 1;
else
    fprintf('  FAIL: carrierConc p-type\n'); failed = failed + 1;
end

% fermiLevel: n-type positive
r = calc.semiconductor.fermiLevel(Material='Si', Nd=1e17, Na=0);
if r.EF > 0
    fprintf('  PASS: fermiLevel n-type positive\n'); passed = passed + 1;
else
    fprintf('  FAIL: fermiLevel n-type positive\n'); failed = failed + 1;
end

% fermiLevel: p-type negative
r = calc.semiconductor.fermiLevel(Material='Si', Nd=0, Na=1e17);
if r.EF < 0
    fprintf('  PASS: fermiLevel p-type negative\n'); passed = passed + 1;
else
    fprintf('  FAIL: fermiLevel p-type negative\n'); failed = failed + 1;
end

% debyeLength: reasonable value
r = calc.semiconductor.debyeLength(epsilon_r=11.7, n=1e16, T=300);
if r.LD > 0 && r.LD < 1000
    fprintf('  PASS: debyeLength (%.1f nm)\n', r.LD); passed = passed + 1;
else
    fprintf('  FAIL: debyeLength\n'); failed = failed + 1;
end

% depletionWidth: positive
r = calc.semiconductor.depletionWidth(epsilon_r=11.7, Vbi=0.7, Na=1e17, Nd=1e16);
if r.W > 0
    fprintf('  PASS: depletionWidth (%.1f nm)\n', r.W); passed = passed + 1;
else
    fprintf('  FAIL: depletionWidth\n'); failed = failed + 1;
end

% builtInPotential: Si p-n junction ~ 0.76 V
r = calc.semiconductor.builtInPotential(1e17, 1e16, 1e10);
if abs(r.Vbi - 0.757) < 0.05
    fprintf('  PASS: builtInPotential (%.3f V)\n', r.Vbi); passed = passed + 1;
else
    fprintf('  FAIL: builtInPotential (got %.4f V)\n', r.Vbi); failed = failed + 1;
end

% mobilityModel: Si low doping -> high mobility
r = calc.semiconductor.mobilityModel(Material='Si', N=1e14);
if r.muE > 1000 && r.muH > 300
    fprintf('  PASS: mobilityModel low doping\n'); passed = passed + 1;
else
    fprintf('  FAIL: mobilityModel low doping\n'); failed = failed + 1;
end

% mobilityModel: high doping -> lower
r2 = calc.semiconductor.mobilityModel(Material='Si', N=1e19);
if r2.muE < r.muE
    fprintf('  PASS: mobilityModel high doping lower\n'); passed = passed + 1;
else
    fprintf('  FAIL: mobilityModel high doping lower\n'); failed = failed + 1;
end

% diffusionCoeff: Einstein relation
r = calc.semiconductor.diffusionCoeff(1000, T=300);
kBT_q = C.kB * 300 / C.e;
if abs(r.D - 1000*kBT_q)/r.D < 1e-6
    fprintf('  PASS: diffusionCoeff Einstein\n'); passed = passed + 1;
else
    fprintf('  FAIL: diffusionCoeff Einstein\n'); failed = failed + 1;
end

% diffusionLength
r = calc.semiconductor.diffusionLength(25, 1e-6);
if abs(r.L - sqrt(25*1e-6)) < 1e-10
    fprintf('  PASS: diffusionLength\n'); passed = passed + 1;
else
    fprintf('  FAIL: diffusionLength\n'); failed = failed + 1;
end

% sheetCarrierDensity
r = calc.semiconductor.sheetCarrierDensity(1e18, 1e-5);
if abs(r.ns - 1e13) < 1
    fprintf('  PASS: sheetCarrierDensity\n'); passed = passed + 1;
else
    fprintf('  FAIL: sheetCarrierDensity\n'); failed = failed + 1;
end

% hallCoefficient: n-type dominant (RH < 0)
r = calc.semiconductor.hallCoefficient(1e16, 1e4, 1000, 450);
if r.RH < 0
    fprintf('  PASS: hallCoefficient n-type\n'); passed = passed + 1;
else
    fprintf('  FAIL: hallCoefficient n-type\n'); failed = failed + 1;
end

% thermalVelocity
r = calc.semiconductor.thermalVelocity(1.08, T=300);
if r.vth > 0
    fprintf('  PASS: thermalVelocity\n'); passed = passed + 1;
else
    fprintf('  FAIL: thermalVelocity\n'); failed = failed + 1;
end

% dosEffectiveMass
r = calc.semiconductor.dosEffectiveMass(Material='Si', Carrier='e');
if r.mStar == 1.08
    fprintf('  PASS: dosEffectiveMass Si e\n'); passed = passed + 1;
else
    fprintf('  FAIL: dosEffectiveMass Si e\n'); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  THIN FILM
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- calc.thinFilm ---\n');

% depositionRate: 100 Ang / 100 s = 1 Ang/s = 6 nm/min
r = calc.thinFilm.depositionRate(100, 100);
if abs(r.rate - 1.0) < 1e-10 && abs(r.rateNmPerMin - 6.0) < 1e-6
    fprintf('  PASS: depositionRate\n'); passed = passed + 1;
else
    fprintf('  FAIL: depositionRate\n'); failed = failed + 1;
end

% kiessigThickness: deltaQ=0.01 -> t=2pi/0.01
r = calc.thinFilm.kiessigThickness(0.01);
if abs(r.thickness - 2*pi/0.01) < 0.1
    fprintf('  PASS: kiessigThickness\n'); passed = passed + 1;
else
    fprintf('  FAIL: kiessigThickness\n'); failed = failed + 1;
end

% stoneyStress
Es = 130e9; nus = 0.28; ts = 500e-6; tf = 100e-9; R = 50;
sigma = Es * ts^2 / (6*(1-nus)*tf*R);
r = calc.thinFilm.stoneyStress(Es, nus, ts, tf, R);
if abs(r.stress - sigma)/sigma < 1e-6
    fprintf('  PASS: stoneyStress\n'); passed = passed + 1;
else
    fprintf('  FAIL: stoneyStress\n'); failed = failed + 1;
end

% doseFromCurrent
dose = (1e-6 * 60) / (C.e * 1);
r = calc.thinFilm.doseFromCurrent(1e-6, 60, 1);
if abs(r.dose - dose)/dose < 1e-6
    fprintf('  PASS: doseFromCurrent\n'); passed = passed + 1;
else
    fprintf('  FAIL: doseFromCurrent\n'); failed = failed + 1;
end

% thermalMismatchStrain: strain only
r = calc.thinFilm.thermalMismatchStrain(17e-6, 3e-6, -500);
strainExpect = (17e-6 - 3e-6)*(-500);
if abs(r.strain - strainExpect) < 1e-12 && strcmp(r.description, 'compressive')
    fprintf('  PASS: thermalMismatchStrain\n'); passed = passed + 1;
else
    fprintf('  FAIL: thermalMismatchStrain\n'); failed = failed + 1;
end

% thermalMismatchStrain: with stress
r = calc.thinFilm.thermalMismatchStrain(17e-6, 3e-6, -500, E=200e9, nu=0.28);
if ~isnan(r.stressMPa)
    fprintf('  PASS: thermalMismatch with stress\n'); passed = passed + 1;
else
    fprintf('  FAIL: thermalMismatch with stress\n'); failed = failed + 1;
end

% multilayerThermalConductivity
r = calc.thinFilm.multilayerThermalConductivity([100; 100], [1; 10]);
kSer = 200 / (100/1 + 100/10);
kPar = (1*100 + 10*100) / 200;
if abs(r.kSeries - kSer) < 0.001 && abs(r.kParallel - kPar) < 0.001
    fprintf('  PASS: multilayerThermalConductivity\n'); passed = passed + 1;
else
    fprintf('  FAIL: multilayerThermalConductivity\n'); failed = failed + 1;
end

% diffusionLength_thermal
r = calc.thinFilm.diffusionLength_thermal(1e-12, 3600);
Lexpect = sqrt(1e-12 * 3600);
if abs(r.L - Lexpect) < 1e-15
    fprintf('  PASS: diffusionLength_thermal\n'); passed = passed + 1;
else
    fprintf('  FAIL: diffusionLength_thermal\n'); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  MAGNETIC
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- calc.magnetic ---\n');

% magnetization
r = calc.magnetic.magnetization(0.001, 0.001);
if abs(r.Mcgs - 1) < 1e-10 && abs(r.Msi - 1000) < 1e-6
    fprintf('  PASS: magnetization\n'); passed = passed + 1;
else
    fprintf('  FAIL: magnetization\n'); failed = failed + 1;
end

% momentPerAtom: Fe ~2.2 muB
r = calc.magnetic.momentPerAtom(1700, 1, 8.5e22);
if abs(r.muB - 2.2) < 0.2
    fprintf('  PASS: momentPerAtom Fe ~ 2.2 muB (got %.2f)\n', r.muB); passed = passed + 1;
else
    fprintf('  FAIL: momentPerAtom Fe (got %.2f muB)\n', r.muB); failed = failed + 1;
end

% bohrMagnetonConvert: emu
muB_emu = 9.2740100783e-21;
r = calc.magnetic.bohrMagnetonConvert(muB_emu, 'emu');
if abs(r.muB - 1) < 1e-6
    fprintf('  PASS: bohrMagnetonConvert emu\n'); passed = passed + 1;
else
    fprintf('  FAIL: bohrMagnetonConvert emu\n'); failed = failed + 1;
end

% bohrMagnetonConvert: J/T
r = calc.magnetic.bohrMagnetonConvert(C.muB, 'JT');
if abs(r.muB - 1) < 1e-6
    fprintf('  PASS: bohrMagnetonConvert JT\n'); passed = passed + 1;
else
    fprintf('  FAIL: bohrMagnetonConvert JT\n'); failed = failed + 1;
end

% demagFactor: sphere Nz = 1/3
r = calc.magnetic.demagFactor('sphere');
if abs(r.Nz - 1/3) < 1e-10 && abs(r.Nxy - 1/3) < 1e-10
    fprintf('  PASS: demagFactor sphere\n'); passed = passed + 1;
else
    fprintf('  FAIL: demagFactor sphere\n'); failed = failed + 1;
end

% demagFactor: thin film Nz = 1
r = calc.magnetic.demagFactor('thin_film');
if abs(r.Nz - 1) < 1e-10 && abs(r.Nxy) < 1e-10
    fprintf('  PASS: demagFactor thin_film\n'); passed = passed + 1;
else
    fprintf('  FAIL: demagFactor thin_film\n'); failed = failed + 1;
end

% demagFactor: sum rule
r = calc.magnetic.demagFactor('prolate', ratio=5);
if abs(r.Nz + 2*r.Nxy - 1) < 1e-10 && r.Nz < 1/3
    fprintf('  PASS: demagFactor prolate + sum rule\n'); passed = passed + 1;
else
    fprintf('  FAIL: demagFactor prolate + sum rule\n'); failed = failed + 1;
end

% demagFactor: oblate Nz > 1/3
r = calc.magnetic.demagFactor('oblate', ratio=5);
if r.Nz > 1/3 && abs(r.Nz + 2*r.Nxy - 1) < 1e-10
    fprintf('  PASS: demagFactor oblate\n'); passed = passed + 1;
else
    fprintf('  FAIL: demagFactor oblate\n'); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  SUBSTRATES
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- calc.substrates ---\n');

% listSubstrates: 14 entries
list = calc.substrates.listSubstrates();
if numel(list) == 14
    fprintf('  PASS: listSubstrates 14 entries\n'); passed = passed + 1;
else
    fprintf('  FAIL: listSubstrates (%d entries)\n', numel(list)); failed = failed + 1;
end

% Si(100)
s = calc.substrates.getSubstrate('Si(100)');
if abs(s.a - 5.431) < 0.001 && strcmp(s.latticeType, 'cubic') && abs(s.dielectric - 11.7) < 0.1
    fprintf('  PASS: Si(100)\n'); passed = passed + 1;
else
    fprintf('  FAIL: Si(100)\n'); failed = failed + 1;
end

% Al2O3 hexagonal
s = calc.substrates.getSubstrate('Al2O3(0001)');
if strcmp(s.latticeType, 'hexagonal') && abs(s.a - 4.758) < 0.001 && abs(s.gamma - 120) < 0.1
    fprintf('  PASS: Al2O3(0001) hexagonal\n'); passed = passed + 1;
else
    fprintf('  FAIL: Al2O3(0001) hexagonal\n'); failed = failed + 1;
end

% SrTiO3 high dielectric
s = calc.substrates.getSubstrate('SrTiO3(100)');
if abs(s.dielectric - 300) < 1 && abs(s.a - 3.905) < 0.001
    fprintf('  PASS: SrTiO3(100)\n'); passed = passed + 1;
else
    fprintf('  FAIL: SrTiO3(100)\n'); failed = failed + 1;
end

% MgO
s = calc.substrates.getSubstrate('MgO(100)');
if abs(s.a - 4.212) < 0.001
    fprintf('  PASS: MgO(100)\n'); passed = passed + 1;
else
    fprintf('  FAIL: MgO(100)\n'); failed = failed + 1;
end

% bad name errors
try
    calc.substrates.getSubstrate('NotASubstrate');
    fprintf('  FAIL: bad substrate should error\n'); failed = failed + 1;
catch
    fprintf('  PASS: bad substrate errors\n'); passed = passed + 1;
end

% All 14 substrates load
allOk = true;
for i = 1:numel(list)
    try
        s = calc.substrates.getSubstrate(list{i});
        if isempty(s.name); allOk = false; end
    catch
        allOk = false;
    end
end
if allOk
    fprintf('  PASS: all 14 substrates load\n'); passed = passed + 1;
else
    fprintf('  FAIL: not all substrates load\n'); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  LATEX FIELDS
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- LaTeX field checks ---\n');

r = calc.crystal.dSpacing(5.431, 1, 1, 1);
if ischar(r.latex) && ~isempty(r.latex)
    fprintf('  PASS: crystal latex\n'); passed = passed + 1;
else
    fprintf('  FAIL: crystal latex\n'); failed = failed + 1;
end

r = calc.electrical.resistivity(10, 1e-5);
if ischar(r.latex) && ~isempty(r.latex)
    fprintf('  PASS: electrical latex\n'); passed = passed + 1;
else
    fprintf('  FAIL: electrical latex\n'); failed = failed + 1;
end

r = calc.semiconductor.intrinsicCarrierConc(Material='Si');
if ischar(r.latex) && ~isempty(r.latex)
    fprintf('  PASS: semiconductor latex\n'); passed = passed + 1;
else
    fprintf('  FAIL: semiconductor latex\n'); failed = failed + 1;
end

r = calc.thinFilm.kiessigThickness(0.05);
if ischar(r.latex) && ~isempty(r.latex)
    fprintf('  PASS: thinFilm latex\n'); passed = passed + 1;
else
    fprintf('  FAIL: thinFilm latex\n'); failed = failed + 1;
end

r = calc.magnetic.demagFactor('sphere');
if ischar(r.latex) && ~isempty(r.latex)
    fprintf('  PASS: magnetic latex\n'); passed = passed + 1;
else
    fprintf('  FAIL: magnetic latex\n'); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  PLANE SPACINGS
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- calc.crystal.planeSpacings ---\n');

% Primitive cubic: (100) should be present
r = calc.crystal.planeSpacings(5.431, Centering='P', MaxHKL=3);
hklStrs = arrayfun(@(i) sprintf('%d%d%d', r.hkl(i,1), r.hkl(i,2), r.hkl(i,3)), ...
    1:r.nReflections, 'UniformOutput', false);
if any(strcmp(hklStrs, '100'))
    fprintf('  PASS: P centering includes (100)\n'); passed = passed + 1;
else
    fprintf('  FAIL: P centering missing (100)\n'); failed = failed + 1;
end

% FCC (F centering): (100) should be absent, (111) present
r = calc.crystal.planeSpacings(5.431, Centering='F', MaxHKL=3);
hklStrs = arrayfun(@(i) sprintf('%d%d%d', r.hkl(i,1), r.hkl(i,2), r.hkl(i,3)), ...
    1:r.nReflections, 'UniformOutput', false);
if ~any(strcmp(hklStrs, '100'))
    fprintf('  PASS: F centering excludes (100)\n'); passed = passed + 1;
else
    fprintf('  FAIL: F centering should exclude (100)\n'); failed = failed + 1;
end
if any(strcmp(hklStrs, '111'))
    fprintf('  PASS: F centering includes (111)\n'); passed = passed + 1;
else
    fprintf('  FAIL: F centering missing (111)\n'); failed = failed + 1;
end

% FCC (220) should be present (all even)
if any(strcmp(hklStrs, '220'))
    fprintf('  PASS: F centering includes (220)\n'); passed = passed + 1;
else
    fprintf('  FAIL: F centering missing (220)\n'); failed = failed + 1;
end

% BCC (I centering): (100) absent (h+k+l=1 odd), (110) present (h+k+l=2 even)
r = calc.crystal.planeSpacings(2.867, Centering='I', MaxHKL=3);
hklStrs = arrayfun(@(i) sprintf('%d%d%d', r.hkl(i,1), r.hkl(i,2), r.hkl(i,3)), ...
    1:r.nReflections, 'UniformOutput', false);
if ~any(strcmp(hklStrs, '100'))
    fprintf('  PASS: I centering excludes (100)\n'); passed = passed + 1;
else
    fprintf('  FAIL: I centering should exclude (100)\n'); failed = failed + 1;
end
if any(strcmp(hklStrs, '110'))
    fprintf('  PASS: I centering includes (110)\n'); passed = passed + 1;
else
    fprintf('  FAIL: I centering missing (110)\n'); failed = failed + 1;
end

% d-spacing value check: cubic (100) d = a
r = calc.crystal.planeSpacings(3.905, Centering='P', MaxHKL=1);
idx100 = find(r.hkl(:,1)==1 & r.hkl(:,2)==0 & r.hkl(:,3)==0, 1);
if ~isempty(idx100) && abs(r.d(idx100) - 3.905) < 1e-4
    fprintf('  PASS: d(100) = a = 3.905\n'); passed = passed + 1;
else
    fprintf('  FAIL: d(100) != a\n'); failed = failed + 1;
end

% 2theta check: known Cu Ka reflection for Si (111) FCC
% d(111) = 5.431/sqrt(3) ~ 3.1356, 2theta ~ 28.44 deg
r = calc.crystal.planeSpacings(5.431, Centering='F', MaxHKL=3, Lambda=1.5406);
idx111 = find(r.hkl(:,1)==1 & r.hkl(:,2)==1 & r.hkl(:,3)==1, 1);
if ~isempty(idx111) && abs(r.twoTheta(idx111) - 28.44) < 0.1
    fprintf('  PASS: Si(111) 2theta ~ 28.44\n'); passed = passed + 1;
else
    fprintf('  FAIL: Si(111) 2theta\n'); failed = failed + 1;
end

% Sorted descending by d
r = calc.crystal.planeSpacings(5.431, Centering='P', MaxHKL=3);
if all(diff(r.d) <= 0)
    fprintf('  PASS: d-spacings sorted descending\n'); passed = passed + 1;
else
    fprintf('  FAIL: d-spacings not sorted\n'); failed = failed + 1;
end

% Multiplicity check: cubic (100) family should have 6 members
r = calc.crystal.planeSpacings(5.431, Centering='P', MaxHKL=1);
idx100 = find(r.hkl(:,1)==1 & r.hkl(:,2)==0 & r.hkl(:,3)==0, 1);
if ~isempty(idx100) && r.multiplicity(idx100) == 6
    fprintf('  PASS: (100) multiplicity = 6\n'); passed = passed + 1;
else
    if ~isempty(idx100)
        fprintf('  FAIL: (100) multiplicity = %d (expected 6)\n', r.multiplicity(idx100));
    else
        fprintf('  FAIL: (100) not found\n');
    end
    failed = failed + 1;
end

% System field populated
if ischar(r.system) && ~isempty(r.system)
    fprintf('  PASS: system field populated\n'); passed = passed + 1;
else
    fprintf('  FAIL: system field empty\n'); failed = failed + 1;
end

% R centering (obverse): h-k+l = 3n allowed
r = calc.crystal.planeSpacings(4.758, c=12.991, gamma=120, Centering='R', MaxHKL=2);
hklStrs = arrayfun(@(i) sprintf('%d%d%d', r.hkl(i,1), r.hkl(i,2), r.hkl(i,3)), ...
    1:r.nReflections, 'UniformOutput', false);
% (1,0,2): h-k+l = 1-0+2 = 3 -> allowed
if any(strcmp(hklStrs, '102'))
    fprintf('  PASS: R centering includes (102)\n'); passed = passed + 1;
else
    fprintf('  FAIL: R centering missing (102)\n'); failed = failed + 1;
end
% (1,0,0): h-k+l = 1 -> not divisible by 3 -> absent
if ~any(strcmp(hklStrs, '100'))
    fprintf('  PASS: R centering excludes (100)\n'); passed = passed + 1;
else
    fprintf('  FAIL: R centering should exclude (100)\n'); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  SUMMARY
% ════════════════════════════════════════════════════════════════════

fprintf('\n=== Results: %d passed, %d failed ===\n', passed, failed);
