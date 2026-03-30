function [val, err] = errorAdd(a, da, b, db)
%ERRORADD  Error propagation for addition/subtraction.
%
%   Syntax:
%       [val, err] = utilities.errorAdd(a, da, b, db)
%
%   Computes val = a + b (or a - b when b is negative) and propagates
%   uncertainties in quadrature: err = sqrt(da.^2 + db.^2).
%   Operates element-wise on vectors and arrays.
%
%   Inputs:
%       a, b   — values (scalars or arrays of matching size)
%       da, db — corresponding uncertainties (same shape as a, b)
%
%   Outputs:
%       val — a + b
%       err — sqrt(da.^2 + db.^2)
%
%   Examples:
%       [v, e] = utilities.errorAdd(3.0, 0.1, 4.0, 0.2);
%       % v = 7.0,  e = sqrt(0.01 + 0.04) ≈ 0.2236
%
%       % Element-wise on vectors
%       [v, e] = utilities.errorAdd([1 2 3], [0.1 0.1 0.1], ...
%                                   [4 5 6], [0.2 0.2 0.2]);
%
%   See also utilities.errorProp, utilities.errorMul, utilities.errorDiv,
%            utilities.errorFunc

arguments
    a  double
    da double
    b  double
    db double
end

val = a + b;
err = sqrt(da.^2 + db.^2);

end
