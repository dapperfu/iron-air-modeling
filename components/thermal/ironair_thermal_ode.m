function [dx, outputs, diagnostics] = ironair_thermal_ode(t, x, inputs, p)
%IRONAIR_THERMAL_ODE Lumped and three-node iron-air thermal balance.
%   [DX, OUTPUTS, DIAGNOSTICS] = IRONAIR_THERMAL_ODE(T, X, INPUTS, P)
%
%   State x, K:
%     T_cell, T_collector, T_air
%
%   Equation: THM-001 through THM-009
%   Requirements: SRS008, SRS019.

arguments
    t (1, 1) double
    x (3, 1) double
    inputs (1, 1) struct
    p (1, 1) struct
end

if any(x <= 0)
    error("ironair:thermal:InvalidTemperature", ...
        "Thermal states must be absolute temperatures in kelvin.");
end

T_cell = x(1);
T_collector = x(2);
T_air = x(3);
constants = p.constants;
thermal = p.thermal_properties;
I_cell = inputs.I_cell_A;
R_ohmic = inputs.R_ohmic_Ohm;

% THM-002: ohmic heating. Constitutive equation.
Q_dot_ohmic = I_cell.^2 .* R_ohmic;
% THM-003: irreversible activation heating. Constitutive equation.
Q_dot_activation = inputs.A_reaction_m2 .* inputs.j_reaction_A_m2 .* inputs.eta_reaction_V;
Q_dot_activation = sum(Q_dot_activation(:));
% THM-004: reversible electrochemical heat. Constitutive equation.
Q_dot_reversible = -I_cell .* T_cell .* thermal.de_cell_eq_dT_V_K;

G_thermal = thermal.k_thermal_W_mK .* thermal.A_surface_m2 ./ thermal.L_thermal_m;
% THM-005: conduction from collector and air nodes into the cell node.
Q_dot_conduction_collector = G_thermal .* (T_collector - T_cell);
Q_dot_conduction_air = G_thermal .* (T_air - T_cell);
T_fluid = inputs.T_ambient_K;
% THM-006: convection leaving the cell surface. Constitutive equation.
Q_dot_convection = thermal.h_conv_W_m2K .* thermal.A_surface_m2 .* (T_cell - T_fluid);
% THM-007: radiation leaving the cell surface. Constitutive equation.
Q_dot_radiation = thermal.epsilon_radiation .* constants.sigma_SB_W_m2K4 .* ...
    thermal.A_surface_m2 .* (T_cell.^4 - T_fluid.^4);
% THM-008: coolant heat removal. Constitutive equation.
Q_dot_coolant = inputs.m_dot_coolant_kg_s .* inputs.cp_coolant_J_kgK .* ...
    (inputs.T_coolant_out_K - inputs.T_coolant_in_K);

Q_dot_generation = Q_dot_ohmic + Q_dot_activation + Q_dot_reversible;
Q_dot_in = 0;
Q_dot_out = Q_dot_convection + Q_dot_radiation + Q_dot_coolant ...
    - Q_dot_conduction_collector - Q_dot_conduction_air;
C_cell = thermal.m_thermal_kg .* thermal.cp_thermal_J_kgK;
% THM-001: lumped cell balance. Conservation law.
dT_dt = (Q_dot_generation + Q_dot_in - Q_dot_out) ./ C_cell;

Q_collector = inputs.Q_dot_collector_W;
C_node = thermal.C_thermal_node_J_K;
% THM-009: multinode network. Conservation law.
dT_cell_dt = dT_dt;
dT_collector_dt = (Q_collector + G_thermal .* (T_cell - T_collector)) ./ C_node;
dT_air_dt = (G_thermal .* (T_cell - T_air)) ./ C_node;

dx = [dT_cell_dt; dT_collector_dt; dT_air_dt];
outputs = struct( ...
    "T_cell_K", T_cell, ...
    "T_K", x, ...
    "Q_dot_ohmic_W", Q_dot_ohmic, ...
    "Q_dot_activation_W", Q_dot_activation, ...
    "Q_dot_reversible_W", Q_dot_reversible, ...
    "Q_dot_conduction_W", Q_dot_conduction_collector + Q_dot_conduction_air, ...
    "Q_dot_convection_W", Q_dot_convection, ...
    "Q_dot_radiation_W", Q_dot_radiation, ...
    "Q_dot_coolant_W", Q_dot_coolant, ...
    "Q_dot_generation_W", Q_dot_generation, ...
    "dT_dt", dT_dt, ...
    "G_thermal_W_K", G_thermal);
diagnostics = struct("t", t, "temperature_positive", all(x > 0));
end
