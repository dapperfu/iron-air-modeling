function [x, diagnostics] = ironair_nonlinear_solve(residual_fun, x0, options)
%IRONAIR_NONLINEAR_SOLVE Solve r(x)=0 with a damped Newton method.
%   [X, DIAGNOSTICS] = IRONAIR_NONLINEAR_SOLVE(RESIDUAL_FUN, X0, OPTIONS)
%   uses only base MATLAB linear algebra. It does not call fsolve.
%
%   Inputs:
%     residual_fun - Function handle returning a residual column.
%     x0           - Initial guess column.
%     options      - Optional fields rel_tol, abs_tol, max_iter.
%
%   Outputs:
%     x           - Solution column.
%     diagnostics - Iteration count, residual norm, and convergence flag.
%
%   Requirements: SRS018.

arguments
    residual_fun (1, 1) function_handle
    x0 (:, 1) double
    options (1, 1) struct = struct()
end

rel_tol = get_option(options, "rel_tol", 1e-8);
abs_tol = get_option(options, "abs_tol", 1e-10);
max_iter = get_option(options, "max_iter", 40);
x = x0;
residual = residual_fun(x);
converged = false;
iter = 0;

for iter = 1:max_iter
    residual_norm = norm(residual, inf);
    if residual_norm <= abs_tol || residual_norm <= rel_tol * max(1, norm(x, inf))
        converged = true;
        break;
    end
    jacobian = numerical_jacobian(residual_fun, x, residual);
    if rcond(jacobian) < 1e-14
        jacobian = jacobian + 1e-8 * eye(numel(x));
    end
    step = jacobian \ residual;
    alpha = 1;
    accepted = false;
    while alpha >= 1/32
        x_trial = x - alpha * step;
        residual_trial = residual_fun(x_trial);
        if norm(residual_trial, inf) < residual_norm
            x = x_trial;
            residual = residual_trial;
            accepted = true;
            break;
        end
        alpha = alpha / 2;
    end
    if ~accepted
        x = x - 1e-3 * step;
        residual = residual_fun(x);
    end
end

diagnostics = struct( ...
    "iterations", iter, ...
    "residual_norm", norm(residual, inf), ...
    "converged", converged);
if ~converged
    error("ironair:solver:NewtonFailure", ...
        "Nonlinear solve failed after %d iterations with residual %g.", ...
        iter, diagnostics.residual_norm);
end
end

function value = get_option(options, name, default_value)
if isfield(options, name)
    value = options.(name);
else
    value = default_value;
end
end

function jacobian = numerical_jacobian(residual_fun, x, residual0)
n = numel(x);
jacobian = zeros(n, n);
delta = 1e-8 * max(1, abs(x));
for index = 1:n
    x_pert = x;
    x_pert(index) = x_pert(index) + delta(index);
    residual_pert = residual_fun(x_pert);
    jacobian(:, index) = (residual_pert - residual0) ./ delta(index);
end
end
