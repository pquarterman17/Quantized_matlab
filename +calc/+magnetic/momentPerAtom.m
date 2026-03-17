function result = momentPerAtom(totalMoment, volume, atomDensity)
%MOMENTPERATOM  Convert a total magnetic moment to per-atom Bohr magnetons.
%
%   Syntax:
%     result = calc.magnetic.momentPerAtom(totalMoment, volume, atomDensity)
%
%   Inputs:
%     totalMoment — total magnetic moment of the sample (emu)
%     volume      — sample volume (cm³)
%     atomDensity — atomic number density (atoms/cm³)
%
%   Outputs:
%     result — struct with fields:
%       .muB    — moment per atom in Bohr magnetons (µB/atom)
%       .muEmu  — moment per atom (emu/atom)
%       .M      — magnetization (emu/cm³)
%       .latex  — LaTeX-formatted result string
%
%   Formulas:
%     M       = totalMoment / volume
%     muEmu   = M / atomDensity
%     muB     = muEmu / muB_cgs   (muB_cgs = 9.2740100783e-21 emu)
%
%   Example:
%     r = calc.magnetic.momentPerAtom(1.5e-3, 1e-4, 8.49e22);
%     disp(r.muB)   % Bohr magnetons per Fe atom

% ════════════════════════════════════════════════════════════════════

arguments
    totalMoment (1,1) double
    volume      (1,1) double {mustBePositive}
    atomDensity (1,1) double {mustBePositive}
end

muB_cgs = 9.2740100783e-21;   % Bohr magneton in CGS (emu)

M      = totalMoment / volume;          % emu/cm³
muEmu  = M / atomDensity;              % emu/atom
muBohr = muEmu / muB_cgs;             % µB/atom

result.muB   = muBohr;
result.muEmu = muEmu;
result.M     = M;
result.latex = sprintf('$\\mu = %.4g\\,\\mu_\\mathrm{B}/\\mathrm{atom}$', muBohr);

end
