function [dx, outputs, diagnostics] = ironair_degradation_ode(t, x, inputs, p)
%IRONAIR_DEGRADATION_ODE Thermal aging of area, catalyst, resistance, and iron.
%   [DX, OUTPUTS, DIAGNOSTICS] = IRONAIR_DEGRADATION_ODE(T, X, INPUTS, P)
%
%   State x:
%     f_area, R_extra_Ohm, n_Fe_inactive_mol
%
%   Inactive iron is the sole capacity-loss ledger. Usable capacity is not
%   reduced a second time.
%
%   Equation: DEG-001 through DEG-006
%   Requirements: SRS016, SRS003.3, SRS004.

arguments
    t (1, 1) double
    x (:, 1) double
    inputs (1, 1) struct
    p (1, 1) struct
end
if numel(x) < 3
    error("ironair:degradation:StateSize", ...
        "Degradation state must contain area, resistance, and inactive iron.");
end
x = x(1:3);
if ~isfield(inputs, "A_active_m2")
    inputs.A_active_m2 = p.iron_electrode.A_geometric_Fe_m2;
end
if ~isfield(inputs, "a_catalyst")
    inputs.a_catalyst = 1;
end
if ~isfield(inputs, "Q_usable_BOL_C")
    inputs.Q_usable_BOL_C = 2 .* p.constants.F_C_mol .* ...
        (p.cell_geometry.n_Fe_initial_mol + p.cell_geometry.n_FeOH2_initial_mol);
end
if ~isfield(inputs, "SOC")
    inputs.SOC = 0.5;
end

f_area = x(1);
R_extra = x(2);
n_inactive = x(3);
aging = p.aging_degradation;
constants = p.constants;
T_cell = inputs.T_cell_K;
% DEG-001
k_aging = aging.k_aging_ref_1_s .* exp( ...
    -(aging.E_a_aging_J_mol ./ constants.R_J_molK) .* ...
    (1 ./ T_cell - 1 ./ constants.T_ref_K));
temperature_factor = k_aging ./ max(aging.k_aging_ref_1_s, realmin);
stress = (1 + abs(inputs.I_cell_A) ./ 100) .* (1 + abs(inputs.SOC - 0.5));
A_active = inputs.A_active_m2 .* max(f_area, 0);
% DEG-002
dA_active_dt = -aging.k_area_loss_1_s .* temperature_factor .* A_active;
df_area_dt = -aging.k_area_loss_1_s .* temperature_factor .* max(f_area, 0);
a_catalyst = inputs.a_catalyst;
% DEG-003
da_catalyst_dt = -aging.k_catalyst_loss_1_s .* temperature_factor .* a_catalyst;
% DEG-004: growth coefficient depends on temperature, SOC, and current.
k_resistance_growth = aging.k_resistance_growth_Ohm_s .* temperature_factor .* stress;
dR_internal_dt = k_resistance_growth;
% DEG-005
r_Fe_irreversible = aging.r_Fe_irreversible_mol_s .* temperature_factor .* stress;
dn_Fe_inactive_dt = r_Fe_irreversible;
Q_usable_BOL = inputs.Q_usable_BOL_C;
delta_Q = 2 .* constants.F_C_mol .* max(n_inactive, 0);
% DEG-006
Q_usable_current = Q_usable_BOL - delta_Q;

dx = [df_area_dt; dR_internal_dt; dn_Fe_inactive_dt];
outputs = struct( ...
    "k_aging_1_s", k_aging, ...
    "k_aging", k_aging, ...
    "dA_active_dt", dA_active_dt, ...
    "df_area_dt", df_area_dt, ...
    "da_catalyst_dt", da_catalyst_dt, ...
    "k_resistance_growth_Ohm_s", k_resistance_growth, ...
    "dR_internal_dt", dR_internal_dt, ...
    "dn_Fe_inactive_dt", dn_Fe_inactive_dt, ...
    "r_Fe_irreversible_mol_s", r_Fe_irreversible, ...
    "Q_usable_current_C", Q_usable_current, ...
    "R_extra_Ohm", R_extra);
diagnostics = struct("t", t, "classification", "empirical approximation");
end
