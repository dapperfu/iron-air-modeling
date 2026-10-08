function [dx, outputs, diagnostics] = ironair_state_estimator(t, x, inputs, p)
%IRONAIR_STATE_ESTIMATOR Coulomb counting, observer, and capacity SOH.
%   [DX, OUTPUTS, DIAGNOSTICS] = IRONAIR_STATE_ESTIMATOR(T, X, INPUTS, P)
%
%   State x:
%     SOC_hat
%
%   The observer uses measured and predicted terminals only. It does not
%   read true plant inventories.
%
%   Equation: EST-001, EST-002, EST-004, EST-005, EST-006
%   Requirements: SRS015, SRS007.2.

arguments
    t (1, 1) double
    x (:, 1) double
    inputs (1, 1) struct
    p (1, 1) struct
end

inputs = fill_estimator_inputs(inputs, p);
Q_usable = inputs.Q_usable_C;
if Q_usable <= 0
    error("ironair:estimator:InvalidCapacity", ...
        "Usable capacity must be positive.");
end
% EST-001
dSOC_dt = -inputs.I_Fe_storage_A ./ Q_usable;
y_measured = inputs.y_measured(:);
y_predicted = inputs.y_predicted(:);
L_observer = inputs.L_observer;
innovation = y_measured - y_predicted;
f_state_hat = dSOC_dt .* ones(numel(x), 1);
% EST-002
dx_hat_dt = f_state_hat + L_observer * innovation;

% EST-003
x_hat_pred = ironair_discrete_state_model(inputs.x_hat_previous, inputs.u_input, p);
H_EKF = inputs.H_EKF;
P_pred = inputs.P_pred;
R_measurement = inputs.R_measurement;
% EST-004: matrix division, not an explicit inverse.
K_EKF = (P_pred * H_EKF.') / (H_EKF * P_pred * H_EKF.' + R_measurement);
% EST-005
x_hat = x_hat_pred + K_EKF * innovation;
% EST-006
SOH_capacity = inputs.Q_usable_current_C ./ inputs.Q_usable_BOL_C;

dx = dx_hat_dt;
outputs = struct( ...
    "dSOC_dt", dSOC_dt, ...
    "dx_hat_dt", dx_hat_dt, ...
    "x_hat_pred", x_hat_pred, ...
    "K_EKF", K_EKF, ...
    "x_hat", x_hat, ...
    "SOH_capacity", SOH_capacity, ...
    "Q_usable_C", Q_usable);
diagnostics = struct("t", t, "innovation", innovation, "observer_mode", true);
end

function inputs = fill_estimator_inputs(inputs, p)
Q_default = 2 .* p.constants.F_C_mol .* ...
    (p.cell_geometry.n_Fe_initial_mol + p.cell_geometry.n_FeOH2_initial_mol);
if ~isfield(inputs, "Q_usable_C")
    inputs.Q_usable_C = max(Q_default, 1);
end
if ~isfield(inputs, "I_Fe_storage_A")
    if isfield(inputs, "I_measured_A")
        inputs.I_Fe_storage_A = inputs.I_measured_A;
    else
        inputs.I_Fe_storage_A = 0;
    end
end
if ~isfield(inputs, "y_measured")
    if isfield(inputs, "V_measured_V")
        inputs.y_measured = inputs.V_measured_V;
    else
        inputs.y_measured = 0.5;
    end
end
if ~isfield(inputs, "y_predicted")
    inputs.y_predicted = inputs.y_measured;
end
if ~isfield(inputs, "L_observer")
    inputs.L_observer = 0.05;
end
if ~isfield(inputs, "x_hat_previous")
    inputs.x_hat_previous = 0.5;
end
if ~isfield(inputs, "u_input")
    inputs.u_input = struct("dt_s", 0, "I_Fe_storage_A", inputs.I_Fe_storage_A, ...
        "Q_usable_C", inputs.Q_usable_C);
end
if ~isfield(inputs, "H_EKF")
    inputs.H_EKF = 1;
end
if ~isfield(inputs, "P_pred")
    inputs.P_pred = 0.01;
end
if ~isfield(inputs, "R_measurement")
    inputs.R_measurement = 1e-4;
end
if ~isfield(inputs, "Q_usable_current_C")
    inputs.Q_usable_current_C = inputs.Q_usable_C;
end
if ~isfield(inputs, "Q_usable_BOL_C")
    inputs.Q_usable_BOL_C = max(Q_default, 1);
end
end
