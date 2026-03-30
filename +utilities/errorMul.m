function [val, err] = errorMul(a, da, b, db)
%ERRORMUL  Error propagation for multiplication.
%
%   Syntax:
%       [val, err] = utilities.errorMul(a, da, b, db)
%
%   Computes val = a .* b and propagates uncertainties using the rule that
%   relative errors add in quadrature:
%       err = |a .* b| .* sqrt((da./a).^2 + (db./b).^2)
%
%   Operates element-wise on vectors and arrays.
%
%   Inputs:
%       a, b   — values (scalars or arrays of matching size)
%       da, db — corresponding uncertainties (same shape as a, b)
%
%   Outputs:
%       val — a .* b
%       err — absolute uncertainty of the product
%
%   Examples:
%       [v, e] = utilities.errorMul(3.0, 0.1, 4.0, 0.2);
%       % v = 12.0,  e = 12 * sqrt((0.1/3)^2 + (0.2/4)^2)
%
%   See also utilities.errorProp, utilities.errorAdd, utilities.errorDiv,
%            utilities.errorFunc

arguments
    a  double
    da double
    b  double
    db double
end

val = a .* b;

% Use relative quadrature; guard against zero denominator
relA = da ./ max(abs(a), eps);
relB = db ./ max(abs(b), eps);
err  = abs(val) .* sqrt(relA.^2 + relB.^2);

end
