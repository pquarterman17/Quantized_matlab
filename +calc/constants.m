function C = constants()
%CONSTANTS  Return a struct of fundamental physical constants (CODATA 2018).
%
%   C = calc.constants()
%
%   Fields:
%     C.h     — Planck constant (J*s)
%     C.hbar  — reduced Planck constant (J*s)
%     C.c     — speed of light in vacuum (m/s)
%     C.e     — elementary charge (C)
%     C.kB    — Boltzmann constant (J/K)
%     C.NA    — Avogadro number (1/mol)
%     C.mu0   — vacuum permeability (H/m)
%     C.muB   — Bohr magneton (J/T)
%     C.r_e   — classical electron radius (m)
%     C.R     — molar gas constant (J/mol/K)
%     C.F     — Faraday constant (C/mol)
%     C.Phi0  — magnetic flux quantum (Wb)
%     C.eps0  — vacuum permittivity (F/m)
%     C.m_e   — electron mass (kg)
%
%   Uses a persistent variable internally — the struct is built once on
%   first call, then returned from cache on subsequent calls.
%
%   Example:
%     C = calc.constants();
%     lambda = C.h * C.c / (1.0 * C.e);  % wavelength for 1 eV photon

% ════════════════════════════════════════════════════════════════════
persistent cachedC

if ~isempty(cachedC)
    C = cachedC;
    return
end

C.h     = 6.62607015e-34;       % Planck constant (J*s)
C.hbar  = 1.054571817e-34;      % reduced Planck constant (J*s)
C.c     = 2.99792458e8;         % speed of light (m/s)
C.e     = 1.602176634e-19;      % elementary charge (C)
C.kB    = 1.380649e-23;         % Boltzmann constant (J/K)
C.NA    = 6.02214076e23;        % Avogadro number (1/mol)
C.mu0   = 4*pi*1e-7;            % vacuum permeability (H/m)
C.eps0  = 8.8541878128e-12;     % vacuum permittivity (F/m)
C.muB   = 9.2740100783e-24;     % Bohr magneton (J/T)
C.r_e   = 2.8179403262e-15;     % classical electron radius (m)
C.m_e   = 9.1093837015e-31;     % electron mass (kg)
C.R     = 8.314462618;          % molar gas constant (J/mol/K)
C.F     = 96485.33212;          % Faraday constant (C/mol)
C.Phi0  = 2.067833848e-15;      % magnetic flux quantum (Wb)

cachedC = C;
end
