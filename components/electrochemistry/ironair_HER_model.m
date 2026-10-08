function [dx, outputs, diagnostics] = ironair_HER_model(t, x, inputs, p)
%IRONAIR_HER_MODEL Parasitic hydrogen evolution and gas inventory.
%   [DX, OUTPUTS, DIAGNOSTICS] = IRONAIR_HER_MODEL(T, X, INPUTS, P) evaluates
%   HER kinetics on the iron electrode and tracks hydrogen gas.
%
%   State x:
%     n_H2_gas_mol
%
%   Equation: HER-001 through HER-005
%   Requirements: SRS003.4, SRS009, SRS023.

arguments
    t (1, 1) double
    x (:, 1) double
    inputs (1, 1) struct
    p (1, 1) struct
end

if numel(x) < 1
    error("ironair:her:StateSize", "HER state must contain n_H2_gas_mol.");
end
n_H2_gas = x(1);
ironair_state_validity("HER", n_H2_gas);

T_Fe = inputs.T_Fe_K;
c = p.constants;
a_H2O = 1;
if isfield(inputs, "a_H2O")
    a_H2O = max(inputs.a_H2O, p.hydrogen_evolution.water_activity_min);
end
A_active = inputs.A_active_Fe_m2;
phi_s = inputs.phi_s_Fe_V;
phi_l = 0;
if isfield(inputs, "phi_l_Fe_V")
    phi_l = inputs.phi_l_Fe_V;
end

% HER-001: 2H2O + 2e- -> H2 + 2OH-. Constitutive stoichiometry.
e_HER_eq = p.hydrogen_evolution.e_HER_eq_V;
eta_HER = phi_s - phi_l - e_HER_eq;
j_0_HER = ironair_reaction_rate_constant( ...
    p.hydrogen_evolution.j_0_HER_ref_A_m2, ...
    p.hydrogen_evolution.E_a_HER_J_mol, T_Fe, p) .* a_H2O;
% HER-002: effective one-electron kinetic parameterization
[j_HER, bv_diag] = ironair_butler_volmer(j_0_HER, ...
    p.hydrogen_evolution.alpha_a_HER, p.hydrogen_evolution.alpha_c_HER, ...
    1, eta_HER, T_Fe, c);
I_HER = A_active .* min(j_HER, 0);

% HER-003
dn_H2_generation_dt = -I_HER ./ (2 .* c.F_C_mol);
n_dot_H2_vent = 0;
n_dot_H2_dissolution = 0;
if isfield(inputs, "n_dot_H2_vent_mol_s")
    n_dot_H2_vent = inputs.n_dot_H2_vent_mol_s;
end
if isfield(inputs, "n_dot_H2_dissolution_mol_s")
    n_dot_H2_dissolution = inputs.n_dot_H2_dissolution_mol_s;
end
% HER-005
dn_H2_gas_dt = dn_H2_generation_dt - n_dot_H2_vent - n_dot_H2_dissolution;

I_Fe = 0;
if isfield(inputs, "I_Fe_A")
    I_Fe = inputs.I_Fe_A;
end
I_Fe_reduction = min(I_Fe, 0);
denom = abs(I_Fe_reduction) + abs(I_HER);
% HER-004
if denom <= 1e-12
    eta_F_charge = 1;
else
    eta_F_charge = abs(I_Fe_reduction) ./ denom;
end

dx = dn_H2_gas_dt;
outputs = struct( ...
    "n_H2_gas_mol", n_H2_gas, ...
    "I_HER_A", I_HER, ...
    "j_HER_A_m2", j_HER, ...
    "eta_HER_V", eta_HER, ...
    "dn_H2_generation_dt", dn_H2_generation_dt, ...
    "r_HER_mol_s", dn_H2_generation_dt, ...
    "eta_F_charge", eta_F_charge);
diagnostics = struct("t", t, "bv", bv_diag, "idle_efficiency_protected", denom <= 1e-12);
end
