function [dx, outputs, diagnostics] = ironair_electrolyte_flow_ode(t, x, inputs, p)
%IRONAIR_ELECTROLYTE_FLOW_ODE Reservoir, pump, pipe, and valve hydraulics.
%   [DX, OUTPUTS, DIAGNOSTICS] = IRONAIR_ELECTROLYTE_FLOW_ODE(T, X, INPUTS, P)
%
%   State x:
%     V_reservoir_m3, omega_pump_rad_s
%
%   Equation: FLD-001 through FLD-010
%   Requirements: SRS010, SRS005, SRS008.

arguments
    t (1, 1) double
    x (2, 1) double
    inputs (1, 1) struct
    p (1, 1) struct
end

V_reservoir = x(1);
omega_pump = x(2);
if V_reservoir < -1e-9
    error("ironair:flow:NegativeVolume", ...
        "Reservoir volume must be nonnegative.");
end
rho = inputs.rho_fluid_kg_m3;
mu = inputs.mu_fluid_Pa_s;
if rho <= 0 || mu <= 0
    error("ironair:flow:InvalidFluid", ...
        "Fluid density and viscosity must be positive.");
end

pump_enabled = p.electrolyte_circulation.enabled;
if isfield(inputs, "pump_failed") && inputs.pump_failed
    pump_enabled = false;
end
Q_cmd = 0;
if pump_enabled
    Q_cmd = p.electrolyte_circulation.Q_nominal_m3_s .* ...
        max(omega_pump, 0) ./ max(p.pumps.omega_nominal_rad_s, 1e-6);
end
Q_leak = p.electrolyte_circulation.Q_leak_m3_s;
if isfield(inputs, "Q_leak_m3_s")
    Q_leak = inputs.Q_leak_m3_s;
end
Q_makeup = p.electrolyte_circulation.Q_makeup_m3_s;
Q_flow_in = Q_cmd;
Q_flow_out = Q_cmd;
% FLD-001
dV_reservoir_dt = Q_flow_in - Q_flow_out + Q_makeup - Q_leak;

area = pi .* p.piping.D_hydraulic_m.^2 ./ 4;
v_fluid = Q_cmd ./ max(area, realmin);
% FLD-004
Re_flow = rho .* v_fluid .* p.piping.D_hydraulic_m ./ mu;
% FLD-006, applicable to developed laminar circular-pipe flow.
laminar = Re_flow > 0 && Re_flow <= p.piping.Re_laminar_max;
f_Darcy_laminar = 0;
if Re_flow > 0
    f_Darcy_laminar = 64 ./ Re_flow;
end
if laminar
    f_Darcy = f_Darcy_laminar;
elseif Re_flow > p.piping.Re_laminar_max
    relative_roughness = p.piping.roughness_m ./ p.piping.D_hydraulic_m;
    f_Darcy = 0.25 ./ (log10(relative_roughness ./ 3.7 + 5.74 ./ Re_flow.^0.9)).^2;
else
    f_Darcy = 0;
end
% FLD-005
delta_p_pipe = f_Darcy .* p.piping.L_pipe_m ./ p.piping.D_hydraulic_m .* ...
    (rho .* v_fluid.^2 ./ 2);
% FLD-007
K_minor = p.piping.K_minor;
v_local = v_fluid;
delta_p_minor = sum(K_minor .* rho .* v_local.^2 ./ 2);
delta_p_valve = delta_p_pipe + delta_p_minor + p.pumps.delta_p_nominal_Pa .* pump_enabled;
% FLD-010
Q_valve = p.valves.C_discharge .* p.valves.A_valve_max_m2 .* ...
    sqrt(2 .* abs(delta_p_valve) ./ rho) .* sign(delta_p_valve);

% FLD-002 and FLD-003
delta_p_pump = p.pumps.delta_p_nominal_Pa .* pump_enabled;
Q_pump = Q_cmd;
P_pump_hydraulic = delta_p_pump .* Q_pump;
P_pump_electric = delta_p_pump .* Q_pump ./ (p.pumps.eta_pump .* p.pumps.eta_motor_pump);
tau_hydraulic = 0;
if abs(omega_pump) > 1e-6
    tau_hydraulic = P_pump_hydraulic ./ omega_pump;
end
omega_command = 0;
if pump_enabled
    omega_command = p.pumps.omega_nominal_rad_s;
end
if isfield(inputs, "tau_motor_Nm")
    tau_motor = inputs.tau_motor_Nm;
else
    tau_motor = tau_hydraulic + p.pumps.B_pump_Nm_s .* omega_pump + ...
        p.pumps.J_pump_kg_m2 .* (omega_command - omega_pump) ./ ...
        p.electrolyte_circulation.tau_flow_s;
end
% FLD-009
domega_pump_dt = (tau_motor - tau_hydraulic - p.pumps.B_pump_Nm_s .* omega_pump) ./ ...
    p.pumps.J_pump_kg_m2;

c_in = inputs.c_i_in_mol_m3;
c_tank = inputs.c_i_tank_mol_m3;
R_i = 0;
if isfield(inputs, "R_i_mol_m3s")
    R_i = inputs.R_i_mol_m3s;
end
% FLD-008: reservoir species balance, then the product rule for concentration.
dVc_i_dt = Q_flow_in .* c_in - Q_flow_out .* c_tank + V_reservoir .* R_i;
dc_i_tank_dt = 0;
if V_reservoir > 0
    dc_i_tank_dt = (dVc_i_dt - c_tank .* dV_reservoir_dt) ./ V_reservoir;
end

dx = [dV_reservoir_dt; domega_pump_dt];
outputs = struct( ...
    "dV_reservoir_dt", dV_reservoir_dt, ...
    "Q_pump_m3_s", Q_pump, ...
    "P_pump_hydraulic_W", P_pump_hydraulic, ...
    "P_pump_electric_W", P_pump_electric, ...
    "Re_flow", Re_flow, ...
    "f_Darcy", f_Darcy, ...
    "f_Darcy_laminar", f_Darcy_laminar, ...
    "delta_p_pipe_Pa", delta_p_pipe, ...
    "delta_p_minor_Pa", delta_p_minor, ...
    "Q_valve_m3_s", Q_valve, ...
    "dVc_i_dt", dVc_i_dt, ...
    "dc_i_tank_dt", dc_i_tank_dt, ...
    "domega_pump_dt", domega_pump_dt, ...
    "tau_motor_Nm", tau_motor, ...
    "tau_hydraulic_Nm", tau_hydraulic, ...
    "laminar", laminar);
diagnostics = struct("t", t, "volume_nonnegative", V_reservoir >= -1e-12);
end
