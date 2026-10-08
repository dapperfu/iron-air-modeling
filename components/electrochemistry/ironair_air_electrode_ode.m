function [dx, outputs, diagnostics] = ironair_air_electrode_ode(t, x, inputs, p)
%IRONAIR_AIR_ELECTRODE_ODE ORR/OER kinetics, flooding, and oxygen rates.
%   [DX, OUTPUTS, DIAGNOSTICS] = IRONAIR_AIR_ELECTRODE_ODE(T, X, INPUTS, P)
%   evaluates bifunctional or separate-electrode air kinetics.
%
%   State x:
%     flooding, activity_ORR, activity_OER
%
%   Equation: AIR-001 through AIR-009
%   Requirements: SRS004.

arguments
    t (1, 1) double
    x (:, 1) double
    inputs (1, 1) struct
    p (1, 1) struct
end

if numel(x) < 3
    error("ironair:air:StateSize", ...
        "Air electrode state must contain flooding and catalyst activities.");
end
flooding = min(max(x(1), 0), 1);
activity_ORR = min(max(x(2), 0), 1);
activity_OER = min(max(x(3), 0), 1);

T_air = inputs.T_air_K;
c = p.constants;
a_OH = max(inputs.a_OH, 1e-12);
a_H2O = 1;
if isfield(inputs, "a_H2O")
    a_H2O = max(inputs.a_H2O, 1e-6);
end
a_O2 = max(inputs.a_O2, 1e-12);
phi_l = 0;
if isfield(inputs, "phi_l_air_V")
    phi_l = inputs.phi_l_air_V;
end

% AIR-001: O2 + 2H2O + 4e- -> 4OH-.
% AIR-002: 4OH- -> O2 + 2H2O + 4e-.
% AIR-003
e_O2_eq = p.air_electrode.e_O2_std_V + ...
    (c.R_J_molK .* T_air ./ (4 .* c.F_C_mol)) .* ...
    log((a_O2 .* a_H2O.^2) ./ a_OH.^4);

A_geo = p.air_electrode.A_geometric_air_m2;
A_active = A_geo .* (1 - flooding);
j_0_ORR = ironair_reaction_rate_constant(p.orr_catalyst.j_0_ref_A_m2, ...
    p.orr_catalyst.E_a_J_mol, T_air, p) .* activity_ORR;
j_0_OER = ironair_reaction_rate_constant(p.oer_catalyst.j_0_ref_A_m2, ...
    p.oer_catalyst.E_a_J_mol, T_air, p) .* activity_OER;

if isfield(inputs, "phi_s_air_V")
    phi_s_air = inputs.phi_s_air_V;
    eta_air = phi_s_air - phi_l - e_O2_eq;
else
    eta_air = inputs.eta_air_V;
    phi_s_air = eta_air + phi_l + e_O2_eq;
end
eta_air = min(max(eta_air, -1.2), 1.2);

% AIR-004 / AIR-005 with independent kinetics
[j_BV_ORR, d_orr] = ironair_butler_volmer(j_0_ORR, p.orr_catalyst.alpha_a, ...
    p.orr_catalyst.alpha_c, p.orr_catalyst.n_eff_ORR, eta_air, T_air, c);
[j_BV_OER, d_oer] = ironair_butler_volmer(j_0_OER, p.oer_catalyst.alpha_a, ...
    p.oer_catalyst.alpha_c, p.oer_catalyst.n_eff_OER, eta_air, T_air, c);
j_ORR = min(j_BV_ORR, 0);
j_OER = max(j_BV_OER, 0);
if p.air_electrode.configuration_code == 2
    if isfield(inputs, "oer_isolated") && inputs.oer_isolated
        j_OER = 0;
    end
    if isfield(inputs, "orr_isolated") && inputs.orr_isolated
        j_ORR = 0;
    end
end

D_O2_eff = ironair_O2_diffusivity(inputs.c_KOH_mol_m3, T_air, p);
c_O2_bulk = inputs.c_O2_bulk_mol_m3;
% AIR-008
j_lim_O2 = 4 .* c.F_C_mol .* D_O2_eff .* c_O2_bulk ./ ...
    p.cell_geometry.delta_diffusion_m;
if abs(j_ORR) > 0.999 * j_lim_O2
    j_ORR = -0.999 * j_lim_O2;
    diagnostics_limit = true;
else
    diagnostics_limit = false;
end
if j_lim_O2 <= 0
    error("ironair:air:OxygenStarvation", ...
        "Oxygen limiting current is nonpositive.");
end
% AIR-009 evaluated only inside its physical domain
eta_conc_ORR_abs = -(c.R_J_molK .* T_air ./ (4 .* c.F_C_mol)) .* ...
    log(1 - abs(j_ORR) ./ j_lim_O2);

I_ORR = A_active .* j_ORR;
I_OER = A_active .* j_OER;
% AIR-006, AIR-007
n_dot_O2_ORR = -I_ORR ./ (4 .* c.F_C_mol);
n_dot_O2_OER = I_OER ./ (4 .* c.F_C_mol);

dflood_dt = p.air_electrode.k_flood_1_s .* max(I_ORR, 0) * 0 ...
    + p.air_electrode.k_flood_1_s .* flooding .* 0 ...
    + p.air_electrode.k_flood_1_s .* max(-I_ORR, 0) ./ max(A_geo, 1e-12) ...
    - p.air_electrode.k_dry_1_s .* flooding;
dactivity_ORR_dt = 0;
dactivity_OER_dt = 0;

dx = [dflood_dt; dactivity_ORR_dt; dactivity_OER_dt];
outputs = struct( ...
    "flooding", flooding, ...
    "e_O2_eq_V", e_O2_eq, ...
    "eta_air_V", eta_air, ...
    "eta_ORR_V", eta_air, ...
    "eta_OER_V", eta_air, ...
    "phi_s_air_V", phi_s_air, ...
    "j_ORR_A_m2", j_ORR, ...
    "j_OER_A_m2", j_OER, ...
    "I_ORR_A", I_ORR, ...
    "I_OER_A", I_OER, ...
    "j_lim_O2_A_m2", j_lim_O2, ...
    "eta_conc_ORR_abs_V", eta_conc_ORR_abs, ...
    "n_dot_O2_ORR_mol_s", n_dot_O2_ORR, ...
    "n_dot_O2_OER_mol_s", n_dot_O2_OER, ...
    "r_ORR_mol_s", n_dot_O2_ORR, ...
    "r_OER_mol_s", n_dot_O2_OER, ...
    "A_active_air_m2", A_active);
diagnostics = struct("t", t, "oxygen_limited", diagnostics_limit, ...
    "bv_orr", d_orr, "bv_oer", d_oer);
end
