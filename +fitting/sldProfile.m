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
%   Example:
%       layers = [0 0 0 0; 200 3.47e-6 0 5; 0 2.07e-6 0 3];
%       [z, sld] = fitting.sldProfile(layers);
%       plot(z, sld * 1e6);  ylabel('SLD (10^{-6} Å^{-2})');

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
