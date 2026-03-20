function result = ohmicDrop(I, R)
%OHMICDROP  Compute the ohmic (IR) voltage drop in an electrochemical cell.
%
%   Syntax
%   ------
%   result = calc.electrochemistry.ohmicDrop(I, R)
%
%   Inputs
%   ------
%   I — current (A); positive = anodic
%   R — uncompensated cell resistance (Ohm)
%
%   Outputs
%   -------
%   result — struct with fields:
%     .V     — ohmic drop (V)
%     .VmV   — ohmic drop (mV)
%     .latex — LaTeX-formatted result string
%
%   Notes
%   -----
%   The measured potential E_meas = E_true + I*R (anodic sign convention).
%   Subtract result.V from the measured potential to obtain the corrected
%   (IR-free) electrode potential.
%
%   Examples
%   --------
%   r = calc.electrochemistry.ohmicDrop(1e-3, 50);   % 1 mA through 50 Ohm
%   r = calc.electrochemistry.ohmicDrop(0.1, 2);     % 100 mA through 2 Ohm

% ════════════════════════════════════════════════════════════════════

arguments
    I (1,1) double
    R (1,1) double {mustBeNonnegative}
end

V   = I * R;
VmV = V * 1000;

result.V     = V;
result.VmV   = VmV;
result.latex = sprintf('$V_{\\mathrm{IR}} = %.4g\\,\\text{mV}$', VmV);
end
