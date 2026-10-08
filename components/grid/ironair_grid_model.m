function [outputs, diagnostics] = ironair_grid_model(t, inputs, p)
%IRONAIR_GRID_MODEL Frequency, voltage, droop, and ramp interface.
%   [OUTPUTS, DIAGNOSTICS] = IRONAIR_GRID_MODEL(T, INPUTS, P)
%
%   Droop signs follow the catalog: overfrequency reduces scheduled power,
%   and overvoltage absorbs reactive power. Deadband and ramp limits are
%   configurable parameter fields.
%
%   Equation: GRID-001 through GRID-005
%   Requirements: SRS013.

arguments
    t (1, 1) double
    inputs (1, 1) struct
    p (1, 1) struct
end

f_grid = inputs.f_grid_Hz;
% GRID-001
delta_f_grid = f_grid - p.grid.f_nominal_Hz;
droop_sign = 1;
if isfield(inputs, "frequency_droop_sign")
    droop_sign = inputs.frequency_droop_sign;
end
% GRID-002
P_command_raw = inputs.P_scheduled_W - droop_sign .* ...
    p.grid.K_frequency_droop_W_Hz .* delta_f_grid;
V_error = inputs.V_grid_V - p.grid.V_grid_base_V;
if abs(V_error) < p.grid.V_deadband_V
    V_error_effective = 0;
else
    V_error_effective = V_error - sign(V_error) .* p.grid.V_deadband_V;
end
% GRID-003
Q_command = -p.grid.K_voltage_droop_var_V .* V_error_effective;
% GRID-005
V_grid_pu = inputs.V_grid_measured_V ./ p.grid.V_grid_base_V;
dP_requested_dt = inputs.dP_requested_dt;
% GRID-004
dP_command_dt = min(max(dP_requested_dt, -p.grid.ramp_down_limit_W_s), ...
    p.grid.ramp_up_limit_W_s);

outputs = struct( ...
    "delta_f_grid_Hz", delta_f_grid, ...
    "P_command_W", P_command_raw, ...
    "Q_command_var", Q_command, ...
    "dP_command_dt", dP_command_dt, ...
    "V_grid_pu", V_grid_pu);
diagnostics = struct("t", t, "deadband_active", V_error_effective == 0, ...
    "certification_claim", "illustrative ASSUMED characteristic, not a certification result");
end
