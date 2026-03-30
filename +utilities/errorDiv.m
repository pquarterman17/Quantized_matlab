function [val, err] = errorDiv(a, da, b, db)
%ERRORDIV  Error propagation for division.
%
%   Syntax:
%       [val, err] = utilities.errorDiv(a, da, b, db)
%
%   Computes val = a ./ b and propagates uncertainties using the rule that
%   relative errors add in quadrature:
%       err = |a ./ b| .* sqrt((da./a).^2 + (db./b).^2)
%
%   Operates element-wise on vectors and arrays.
%
%   Inputs:
%       a, b   — values (scalars or arrays of matching size)
%       da, db — corresponding uncertainties (same shape as a, b)
%
%   Outputs:
%       val — a ./ b
%       err — absolute uncertainty of the quotient
%
%   Examples:
%       [v, e] = utilities.errorDiv(6.0, 0.3, 2.0, 0.1);
%       % v = 3.0,  e = 3 * sqrt((0.3/6)^2 + (0.1/2)^2)
%
%   See also utilities.errorProp, utilities.errorAdd, utilities.errorMul,
%            utilities.errorFunc

arguments
    a  double
    da double
    b  double
    db double
end

val = a ./ b;

% Use relative quadrature; guard against zero denominator
relA = da ./ max(abs(a), eps);
relB = db ./ max(abs(b), eps);
err  = abs(val) .* sqrt(relA.^2 + relB.^2);

end
