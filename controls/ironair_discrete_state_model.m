function x_hat_pred = ironair_discrete_state_model(x_hat_previous, u_input, p)
%IRONAIR_DISCRETE_STATE_MODEL Forward-Euler SOC prediction.
%   X_HAT_PRED = IRONAIR_DISCRETE_STATE_MODEL(X_HAT_PREVIOUS, U_INPUT, P)
%   advances coulomb counting by one estimator step.
%
%   u_input fields:
%     dt_s, I_Fe_storage_A, Q_usable_C
%
%   Equation: EST-003
%   Requirements: SRS015.
%
%   p is accepted so the estimator can pass the plant parameter structure.

arguments
    x_hat_previous double
    u_input (1, 1) struct
    p (1, 1) struct
end

if u_input.Q_usable_C <= 0 || u_input.dt_s < 0
    error("ironair:estimator:InvalidStep", ...
        "Estimator step size and usable capacity must be positive.");
end
if ~isfield(p, "constants")
    error("ironair:estimator:InvalidParameters", ...
        "The discrete model requires the plant parameter structure.");
end
% EST-003
x_hat_pred = x_hat_previous + u_input.dt_s .* ...
    (-u_input.I_Fe_storage_A ./ u_input.Q_usable_C);
end
