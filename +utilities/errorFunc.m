function [val, err] = errorFunc(func, a, da)
%ERRORFUNC  Error propagation for a single-variable function.
%
%   Syntax:
%       [val, err] = utilities.errorFunc(func, a, da)
%
%   Evaluates val = func(a) and propagates uncertainty using a numerical
%   first derivative: err = |df/da| .* da, where df/da is computed via
%   a central-difference step.
%
%   Operates element-wise on vectors and arrays.
%
%   Inputs:
%       func — function handle accepting a scalar or array, returning same shape
%       a    — input value(s)
%       da   — uncertainty on a (same shape)
%
%   Outputs:
%       val — func(a)
%       err — |df/da| .* da (absolute uncertainty)
%
%   Examples:
%       % Error on log(x)
%       [v, e] = utilities.errorFunc(@log, 2.0, 0.1);
%       % v = ln(2) ≈ 0.6931,  e = (1/2) * 0.1 = 0.05
%
%       % Error on exp(x)
%       [v, e] = utilities.errorFunc(@exp, 1.0, 0.05);
%       % e = exp(1) * 0.05 ≈ 0.1359
%
%       % Works on vectors
%       x  = [1 2 3];
%       dx = [0.1 0.1 0.1];
%       [v, e] = utilities.errorFunc(@sqrt, x, dx);
%
%   See also utilities.errorProp, utilities.errorAdd, utilities.errorMul,
%            utilities.errorDiv

arguments
    func (1,1) function_handle
    a    double
    da   double
end

val = func(a);

% Central-difference step, same shape as a
h    = max(abs(a) * 1e-7, 1e-10);
dfdx = (func(a + h) - func(a - h)) ./ (2 .* h);

err = abs(dfdx) .* da;

end
