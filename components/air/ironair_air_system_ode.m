function [dx, outputs, diagnostics] = ironair_air_system_ode(t, x, inputs, p)
%IRONAIR_AIR_SYSTEM_ODE Ventilated air-cathode gas inventory and fan.
%   [DX, OUTPUTS, DIAGNOSTICS] = IRONAIR_AIR_SYSTEM_ODE(T, X, INPUTS, P)
%
%   State x:
%     n_O2_gas_mol, n_inert_gas_mol, N_fan (speed ratio to nominal)
%
%   Equation: AIRSYS-001 through AIRSYS-010
%   Requirements: SRS009, SRS004.4, SRS008.

arguments
    t (1, 1) double
    x (3, 1) double
    inputs (1, 1) struct
    p (1, 1) struct
end

n_O2 = x(1);
n_inert = x(2);
N_fan = x(3);
if n_O2 < -1e-8 || n_inert < -1e-8
    error("ironair:airSystem:NegativeInventory", ...
        "Gas inventories must remain nonnegative.");
end
T_gas = inputs.T_gas_K;
if T_gas <= 0
    error("ironair:airSystem:InvalidTemperature", ...
        "Gas temperature must be absolute.");
end
V_gas = p.cell_geometry.V_gas_m3;
constants = p.constants;
n_gas = max(n_O2, 0) + max(n_inert, 0);
% AIRSYS-001: ideal-gas constitutive relationship, solved for pressure.
p_gas = n_gas .* constants.R_J_molK .* T_gas ./ V_gas;
ideal_gas_residual = p_gas .* V_gas - n_gas .* constants.R_J_molK .* T_gas;
if p_gas <= 0
    error("ironair:airSystem:NegativePressure", ...
        "Gas pressure must be positive.");
end

p_H2O = 0;
if isfield(inputs, "p_H2O_Pa")
    p_H2O = inputs.p_H2O_Pa;
end
% AIRSYS-002
p_dry_air = p_gas - p_H2O;
dry_invalid = p_dry_air < 0;
p_dry_air = max(p_dry_air, 0);
x_O2_dry = max(n_O2, 0) ./ max(n_gas, realmin);
p_O2 = x_O2_dry .* p_dry_air;

N_command = 1;
if isfield(inputs, "N_fan_command")
    N_command = inputs.N_fan_command;
end
% AIRSYS-010
dN_fan_dt = (N_command - N_fan) ./ p.fans.tau_fan_s;
% AIRSYS-007: fan similarity laws. Empirical approximation.
N_nominal = 1;
N_fan_ratio = N_fan ./ N_nominal;
V_dot_air_ratio = N_fan_ratio;
delta_p_fan_ratio = N_fan_ratio.^2;
P_fan_ratio = N_fan_ratio.^3;
V_dot_air = p.fans.V_dot_nominal_m3_s .* V_dot_air_ratio;
delta_p_fan = p.fans.delta_p_nominal_Pa .* delta_p_fan_ratio;
% AIRSYS-008
delta_p_filter = p.fans.K_filter_1_Pa_s_m3 .* V_dot_air ...
    + p.fans.K_filter_2_Pa_s2_m6 .* V_dot_air.^2;
% AIRSYS-005 and AIRSYS-006
P_fan_shaft = delta_p_fan .* V_dot_air ./ p.fans.eta_fan;
P_fan_electric = P_fan_shaft ./ p.fans.eta_motor_fan;
P_fan_from_ratio = (p.fans.delta_p_nominal_Pa .* p.fans.V_dot_nominal_m3_s ./ ...
    p.fans.eta_fan) .* P_fan_ratio;

n_dot_dry_in = p.reference.p_ambient_Pa .* max(V_dot_air, 0) ./ ...
    (constants.R_J_molK .* T_gas);
% AIRSYS-003
n_dot_O2_in = p.gas_properties.x_O2_dry_air .* n_dot_dry_in;
n_dot_inert_in = (1 - p.gas_properties.x_O2_dry_air) .* n_dot_dry_in;
n_target = p.reference.p_ambient_Pa .* V_gas ./ (constants.R_J_molK .* T_gas);
tau_vent_s = 2;
n_dot_out = max(0, n_dot_dry_in + (n_gas - n_target) ./ tau_vent_s);
x_inert = max(n_inert, 0) ./ max(n_gas, realmin);
n_dot_O2_out = x_O2_dry .* n_dot_out;
n_dot_inert_out = x_inert .* n_dot_out;
n_dot_O2_ORR = inputs.n_dot_O2_ORR_mol_s;
n_dot_O2_OER = inputs.n_dot_O2_OER_mol_s;
n_dot_transfer = 0;
if isfield(inputs, "n_dot_O2_transfer_mol_s")
    n_dot_transfer = inputs.n_dot_O2_transfer_mol_s;
end
% AIRSYS-004: gas-phase oxygen inventory. Conservation law.
dn_O2_gas_dt = n_dot_O2_in - n_dot_O2_out - n_dot_O2_ORR + n_dot_O2_OER - n_dot_transfer;
dn_inert_dt = n_dot_inert_in - n_dot_inert_out;

n_dot_consumed = max(n_dot_O2_ORR, 0);
consumption_threshold = 1e-9;
% AIRSYS-009
if n_dot_consumed > consumption_threshold
    lambda_O2 = n_dot_O2_in ./ n_dot_consumed;
    lambda_defined = true;
else
    lambda_O2 = Inf;
    lambda_defined = false;
end

dx = [dn_O2_gas_dt; dn_inert_dt; dN_fan_dt];
outputs = struct( ...
    "p_gas_Pa", p_gas, ...
    "p_dry_air_Pa", p_dry_air, ...
    "p_O2_Pa", p_O2, ...
    "x_O2_dry", x_O2_dry, ...
    "n_dot_O2_in_mol_s", n_dot_O2_in, ...
    "n_dot_O2_out_mol_s", n_dot_O2_out, ...
    "dn_O2_gas_dt", dn_O2_gas_dt, ...
    "V_dot_air_m3_s", V_dot_air, ...
    "delta_p_fan_Pa", delta_p_fan, ...
    "delta_p_filter_Pa", delta_p_filter, ...
    "P_fan_shaft_W", P_fan_shaft, ...
    "P_fan_electric_W", P_fan_electric, ...
    "P_fan_ratio", P_fan_ratio, ...
    "P_fan_from_ratio_W", P_fan_from_ratio, ...
    "V_dot_air_ratio", V_dot_air_ratio, ...
    "delta_p_fan_ratio", delta_p_fan_ratio, ...
    "N_fan_ratio", N_fan_ratio, ...
    "lambda_O2", lambda_O2, ...
    "dN_fan_dt", dN_fan_dt);
diagnostics = struct("t", t, "ideal_gas_residual_J", ideal_gas_residual, ...
    "dry_air_invalid", dry_invalid, "lambda_defined", lambda_defined);
end
