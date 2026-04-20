function [z, sld] = sldProfile(layers, options)
%SLDPROFILE  Compute scattering length density depth profile from a layer stack.
%
%   [z, sld] = fitting.sldProfile(layers)
%   [z, sld] = fitting.sldProfile(layers, NPoints=500, Padding=50)
%
%   Generates a depth-resolved SLD profile with interfacial roughness
%   modeled as error-function transitions.
%
%   Inputs:
%       layers — [M×4] layer stack (same format as parrattRefl):
%                [thickness(Å), SLD_real(Å⁻²), SLD_imag(Å⁻²), roughness(Å)]
%
%   Options:
%       NPoints — number of depth points (default: 500)
%       Padding — extra depth above/below stack in Å (default: 50)
%
%   Output:
%       z   — [N×1] depth vector (Å), 0 = top of first film layer
%       sld — [N×1] real SLD profile (Å⁻²)
%
%   Method
%   ─────────────────────────────
%   The profile is built as a sum of error-function transitions, one per
%   interface, which is the real-space dual of Nevot-Croce roughness in
%   the reflectivity calculation:
%
%       rho(z) = rho_1 + sum_{j>=2}  (Drho_j/2) * [1 + erf((z - z_{j-1}) / (sigma_j * sqrt(2)))]
%
%   where Drho_j = rho_j - rho_{j-1} is the SLD contrast at interface j
%   and sigma_j is the rms roughness (in A). When sigma_j -> 0 the erf
%   collapses to a step at z = z_{j-1}, recovering the box model.
%   A small floor (sigma >= 0.5 A) is enforced to avoid the singular limit.
%
%   Example:
%       layers = [0 0 0 0; 200 3.47e-6 0 5; 0 2.07e-6 0 3];
%       [z, sld] = fitting.sldProfile(layers);
%       plot(z, sld * 1e6);  ylabel('SLD (10^{-6} Å^{-2})');
%
%   References
%   ─────────────────────────────
%   - Nevot, L. & Croce, P., "Caracterisation des surfaces par reflexion
%     rasante de rayons X", Rev. Phys. Appl. 15, 761-779 (1980).
%   - Als-Nielsen, J. & McMorrow, D., "Elements of Modern X-ray Physics",
%     2nd ed., Wiley, 2011, Ch. 3.

arguments
    layers  (:,4) double
    options.NPoints (1,1) double = 500
    options.Padding (1,1) double = 50
end

nLayers = size(layers, 1);
d     = layers(:, 1);
sldR  = layers(:, 2);
sigma = layers(:, 4);

% Total thickness of film stack (layers 2 to M-1)
totalThick = sum(d(2:end-1));

% Depth range
zMin = -options.Padding;
zMax = totalThick + options.Padding;
z = linspace(zMin, zMax, options.NPoints)';

% Build profile: SLD at each depth using error function transitions
% Interface positions (cumulative thickness from top)
interfaceZ = zeros(nLayers, 1);
for j = 2:nLayers-1
    interfaceZ(j) = interfaceZ(j-1) + d(j);
end
interfaceZ(nLayers) = totalThick;  % substrate interface

% Start with incident medium SLD everywhere
sld = ones(size(z)) * sldR(1);

% Add each interface transition
for j = 2:nLayers
    zInterface = interfaceZ(j-1);
    sig = max(sigma(j), 0.5);  % minimum 0.5 Å to avoid singularity
    dSLD = sldR(j) - sldR(j-1);

    % Error function transition centered at interface
    sld = sld + dSLD * 0.5 * (1 + erf((z - zInterface) / (sig * sqrt(2))));
end

end
