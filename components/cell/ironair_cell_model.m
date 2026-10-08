function [dx, outputs, diagnostics] = ironair_cell_model(t, x, inputs, p)
%IRONAIR_CELL_MODEL Coupled iron-air cell with shared reaction network.
%   [DX, OUTPUTS, DIAGNOSTICS] = IRONAIR_CELL_MODEL(T, X, INPUTS, P) integrates
%   iron, HER, air, electrolyte, separator, GDL, and collectors.
%
%   Discharge-positive current: I_cell > 0 delivers power from the cell.
%
%   Equation: CELL-001 through CELL-010, SYS-003
%   Requirements: SRS007, SRS019, SRS023.

arguments
    t (1, 1) double
    x (:, 1) double
    inputs (1, 1) struct
    p (1, 1) struct
end

map = ironair_cell_state_map(p);
if numel(x) ~= map.count
    error("ironair:cell:StateSize", ...
        "Cell state length %d does not match map count %d.", numel(x), map.count);
end

I_cell = inputs.I_cell_A;
T_cell = p.reference.T_initial_K;
if isfield(inputs, "T_cell_K")
    T_cell = inputs.T_cell_K;
end

x_metal = x(map.metal);
x_her = x(map.her);
x_air = x(map.air);
x_ely = x(map.electrolyte);
x_gdl = x(map.gdl);
Q_throughput = x(map.Q_throughput);
eta_dl_Fe = x(map.eta_dl_Fe);
eta_dl_air = x(map.eta_dl_air);

ely_in = struct("T_electrolyte_K", T_cell, ...
    "p_O2_Pa", p.reference.x_O2_dry_air * p.reference.p_ambient_Pa, ...
    "enable_spatial", p.fidelity_level >= 3);
[~, ely0] = ironair_electrolyte_ode(t, x_ely, ely_in, p);

metal_in = struct("T_Fe_K", T_cell, "a_OH" , ely0.a_OH, ...
    "n_nodes", map.n_nodes, "I_Fe_A", I_cell);
if isfield(inputs, "f_area_scale")
    metal_in.f_area_scale = inputs.f_area_scale;
end
if p.iron_electrode.C_dl_Fe_F > 0
    metal_in = rmfield(metal_in, "I_Fe_A");
    metal_in.eta_Fe_V = eta_dl_Fe;
end
[dx_metal, metal, d_metal] = ironair_metal_ode(t, x_metal, metal_in, p);

her_in = struct("T_Fe_K", T_cell, "A_active_Fe_m2", sum(metal.A_active_Fe_m2), ...
    "phi_s_Fe_V", mean(metal.phi_s_Fe_V), "I_Fe_A", sum(metal.I_Fe_A), ...
    "a_H2O", ely0.a_H2O);
if isfield(inputs, "n_dot_H2_vent_mol_s")
    her_in.n_dot_H2_vent_mol_s = inputs.n_dot_H2_vent_mol_s;
end
if isfield(inputs, "n_dot_H2_dissolution_mol_s")
    her_in.n_dot_H2_dissolution_mol_s = inputs.n_dot_H2_dissolution_mol_s;
end
[dx_her, her, d_her] = ironair_HER_model(t, x_her, her_in, p);

c_O2_surf = x_gdl(max(1, map.n_gdl));
a_O2 = max(c_O2_surf, 1e-6) * p.constants.R_J_molK * T_cell / p.constants.p_ref_Pa;
air_in = struct("T_air_K", T_cell, "a_OH", ely0.a_OH, "a_H2O", ely0.a_H2O, ...
    "a_O2", a_O2, "c_KOH_mol_m3", ely0.c_KOH_mol_m3, ...
    "c_O2_bulk_mol_m3", max(ely0.c_O2_mol_m3, 1e-6));
if p.air_electrode.C_dl_air_F > 0
    air_in.eta_air_V = eta_dl_air;
else
    air_in.eta_air_V = 0;
    residual_air = @(eta) local_air_current(t, x_air, air_in, p, eta) + I_cell;
    [eta_air_alg, ~] = ironair_nonlinear_solve(residual_air, eta_dl_air);
    air_in.eta_air_V = eta_air_alg;
end
[dx_air, air, d_air] = ironair_air_electrode_ode(t, x_air, air_in, p);

ely_in.r_Fe_ox_mol_s = sum(metal.r_Fe_ox_mol_s);
ely_in.r_mag_mol_s = sum(metal.r_mag_mol_s);
ely_in.r_ORR_mol_s = air.r_ORR_mol_s;
ely_in.r_OER_mol_s = air.r_OER_mol_s;
ely_in.r_HER_mol_s = her.r_HER_mol_s;
ely_in.I_ionic_A = I_cell;
boundary_names = ["n_dot_H2O_boundary_mol_s", "n_dot_K_boundary_mol_s", ...
    "n_dot_O2_boundary_mol_s", "n_dot_OH_boundary_mol_s", "n_dot_CO2_boundary_mol_s"];
for name_index = 1:numel(boundary_names)
    boundary_name = boundary_names(name_index);
    if isfield(inputs, boundary_name)
        ely_in.(boundary_name) = inputs.(boundary_name);
    end
end
[dx_ely, ely, d_ely] = ironair_electrolyte_ode(t, x_ely, ely_in, p);

sep_in = struct("kappa_KOH_S_m", ely.kappa_KOH_S_m, "T_left_K", T_cell, ...
    "T_right_K", T_cell, "c_left_mol_m3", ely.c_OH_mol_m3, ...
    "c_right_mol_m3", ely.c_OH_mol_m3);
[sep, d_sep] = ironair_separator_model(t, sep_in, p);

c_O2_gas = p.reference.x_O2_dry_air * p.reference.p_ambient_Pa / ...
    (p.constants.R_J_molK * T_cell);
gdl_in = struct("T_air_K", T_cell, "p_gas_Pa", p.reference.p_ambient_Pa, ...
    "p_liquid_Pa", p.reference.p_ambient_Pa, "c_O2_gas_mol_m3", c_O2_gas, ...
    "n_dot_O2_consumed_mol_s", air.n_dot_O2_ORR_mol_s - air.n_dot_O2_OER_mol_s);
[dx_gdl, gdl, d_gdl] = ironair_gas_diffusion_layer(t, x_gdl, gdl_in, p);

col_in = struct("T_collector_K", T_cell, "I_cell_A", I_cell);
[col, d_col] = ironair_current_collector(t, col_in, p);

R_iron = mean(metal.rho_Fe_Ohm_m) * p.cell_geometry.L_electrolyte_m / ...
    max(sum(metal.A_active_Fe_m2), 1e-8) + mean(metal.R_pass_Ohm);
% CELL-010: total ohmic resistance. Constitutive equation.
R_iron = R_iron;
R_electrolyte = ely.R_electrolyte_Ohm;
R_separator = sep.R_separator_Ohm;
R_collectors = col.R_collector_Ohm;
R_contacts = 0;
if isfield(inputs, "R_extra_Ohm")
    R_contacts = inputs.R_extra_Ohm;
end
R_ohmic = R_iron + R_electrolyte + R_separator + R_collectors + R_contacts;
% CELL-001: equilibrium cell voltage. Constitutive equation.
e_cell_eq = air.e_O2_eq_V - mean(metal.e_Fe_eq_V);
eta_loss_kin = mean(metal.eta_Fe_V) - air.eta_air_V;
eta_loss_conc = air.eta_conc_ORR_abs_V .* sign(I_cell + realmin);
% CELL-002
V_cell = e_cell_eq - eta_loss_kin - eta_loss_conc - I_cell .* R_ohmic;
% CELL-003
P_cell = V_cell .* I_cell;
% CELL-004
dQ_throughput_dt = abs(I_cell);
n_Fe_total = sum(metal.n_Fe_mol) + sum(metal.n_FeOH2_mol);
% CELL-005
Q_Fe_theoretical_C = 2 .* p.constants.F_C_mol .* n_Fe_total;
Q_Fe_theoretical_Ah = Q_Fe_theoretical_C ./ 3600;
% CELL-006
SOC = sum(metal.n_Fe_mol) ./ max(n_Fe_total, 1e-12);
% CELL-007 and CELL-008 are defined for a matched cycle supplied by the caller.
eta_C = NaN;
eta_E = NaN;
if isfield(inputs, "Q_discharge_C") && isfield(inputs, "Q_charge_C") && ...
        inputs.Q_charge_C > 0
    eta_C = inputs.Q_discharge_C ./ inputs.Q_charge_C;
end
if isfield(inputs, "t_discharge_s") && isfield(inputs, "P_discharge_W") && ...
        isfield(inputs, "t_charge_s") && isfield(inputs, "P_charge_W")
    E_discharge_J = trapz(inputs.t_discharge_s, inputs.P_discharge_W);
    E_charge_J = trapz(inputs.t_charge_s, inputs.P_charge_W);
    eta_E = E_discharge_J ./ max(E_charge_J, realmin);
end

I_Fe = sum(metal.I_Fe_A);
I_HER = her.I_HER_A;
I_ORR = air.I_ORR_A;
I_OER = air.I_OER_A;
e_current_negative = I_Fe + I_HER - I_cell;
[de_Fe_eq_dt, de_O2_eq_dt] = equilibrium_derivatives( ...
    p, T_cell, inputs, x_ely, dx_ely, ely, air);
if p.iron_electrode.C_dl_Fe_F > 0
    % CELL-009: double-layer dynamics including moving equilibrium potential.
    deta_dl_Fe_dt = (I_cell - I_Fe - I_HER) ./ p.iron_electrode.C_dl_Fe_F - de_Fe_eq_dt;
    dphi_Fe_dt = deta_dl_Fe_dt + de_Fe_eq_dt;
    e_current_negative = I_Fe + I_HER + ...
        p.iron_electrode.C_dl_Fe_F * dphi_Fe_dt - I_cell;
else
    deta_dl_Fe_dt = 0;
end
if p.air_electrode.C_dl_air_F > 0
    deta_dl_air_dt = (-I_cell - I_ORR - I_OER) ./ p.air_electrode.C_dl_air_F - de_O2_eq_dt;
    dphi_air_dt = deta_dl_air_dt + de_O2_eq_dt;
    e_current_positive = I_ORR + I_OER + I_cell + ...
        p.air_electrode.C_dl_air_F * dphi_air_dt;
else
    deta_dl_air_dt = 0;
    e_current_positive = I_ORR + I_OER + I_cell;
end

dx = [dx_metal; dx_her; dx_air; dx_ely; dx_gdl; dQ_throughput_dt; ...
    deta_dl_Fe_dt; deta_dl_air_dt];
outputs = struct( ...
    "V_cell_V", V_cell, ...
    "P_cell_W", P_cell, ...
    "e_cell_eq_V", e_cell_eq, ...
    "I_cell_A", I_cell, ...
    "I_Fe_A", I_Fe, ...
    "I_HER_A", I_HER, ...
    "I_ORR_A", I_ORR, ...
    "I_OER_A", I_OER, ...
    "SOC", SOC, ...
    "eta_C", eta_C, ...
    "eta_E", eta_E, ...
    "Q_Fe_theoretical_C", Q_Fe_theoretical_C, ...
    "Q_Fe_theoretical_Ah", Q_Fe_theoretical_Ah, ...
    "de_Fe_eq_dt", de_Fe_eq_dt, ...
    "de_O2_eq_dt", de_O2_eq_dt, ...
    "Q_throughput_C", Q_throughput, ...
    "R_ohmic_Ohm", R_ohmic, ...
    "eta_loss_kin_V", eta_loss_kin, ...
    "eta_loss_conc_V", eta_loss_conc, ...
    "metal", metal, ...
    "her", her, ...
    "air", air, ...
    "electrolyte", ely, ...
    "separator", sep, ...
    "gdl", gdl, ...
    "collector", col);
diagnostics = struct("t", t, "e_current_negative", e_current_negative, ...
    "e_current_positive", e_current_positive, "metal", d_metal, ...
    "her", d_her, "air", d_air, "electrolyte", d_ely, "separator", d_sep, ...
    "gdl", d_gdl, "collector", d_col);
end

function I_air = local_air_current(t, x_air, air_in, p, eta)
air_in.eta_air_V = eta;
[~, air] = ironair_air_electrode_ode(t, x_air, air_in, p);
I_air = air.I_ORR_A + air.I_OER_A;
end

function [de_Fe_eq_dt, de_O2_eq_dt] = equilibrium_derivatives(p, T_cell, inputs, x_ely, dx_ely, ely, air)
constants = p.constants;
dT_dt = 0;
if isfield(inputs, "dT_cell_dt")
    dT_dt = inputs.dT_cell_dt;
end
n_OH = x_ely(1);
V_ely = max(x_ely(7), 1e-12);
dc_OH_dt = (dx_ely(1) .* V_ely - n_OH .* dx_ely(7)) ./ V_ely.^2;
a_OH = max(ely.a_OH, 1e-8);
da_OH_dt = dc_OH_dt ./ 1000;
de_Fe_eq_dt = -(constants.R_J_molK ./ constants.F_C_mol) .* log(a_OH) .* dT_dt ...
    - (constants.R_J_molK .* T_cell ./ constants.F_C_mol) .* da_OH_dt ./ a_OH;
a_O2 = p.reference.x_O2_dry_air;
a_H2O = max(ely.a_H2O, 1e-12);
log_air = log((a_O2 .* a_H2O.^2) ./ a_OH.^4);
de_O2_eq_dt = (constants.R_J_molK ./ (4 .* constants.F_C_mol)) .* log_air .* dT_dt ...
    - (constants.R_J_molK .* T_cell ./ constants.F_C_mol) .* da_OH_dt ./ a_OH;
if ~isfinite(air.e_O2_eq_V)
    de_O2_eq_dt = 0;
end
end
