function [dx, outputs, diagnostics] = ironair_metal_ode(t, x, inputs, p)
%IRONAIR_METAL_ODE Iron electrode inventories, passivation, and kinetics.
%   [DX, OUTPUTS, DIAGNOSTICS] = IRONAIR_METAL_ODE(T, X, INPUTS, P) advances
%   Fe/FeOH2/Fe3O4 inventories and passivation thickness.
%
%   State x, concatenated over control volumes:
%     n_Fe_mol, n_FeOH2_mol, n_Fe3O4_mol, delta_pass_m
%
%   Inputs:
%     t - Time, s.
%     inputs.T_Fe_K, inputs.a_OH, inputs.I_Fe_A or inputs.eta_Fe_V
%     inputs.n_nodes, inputs.phi_l_Fe_V
%
%   Equation: FE-001 through FE-016
%   Requirements: SRS003, SRS019, SRS023.

arguments
    t (1, 1) double
    x (:, 1) double
    inputs (1, 1) struct
    p (1, 1) struct
end

n_nodes = node_count(inputs);
local_count = 4;
if numel(x) ~= local_count * n_nodes
    error("ironair:metal:StateSize", ...
        "Iron electrode state length must be 4 times the node count.");
end

n_Fe = x(1:n_nodes);
n_FeOH2 = x(n_nodes+1:2*n_nodes);
n_Fe3O4 = x(2*n_nodes+1:3*n_nodes);
delta_pass = x(3*n_nodes+1:4*n_nodes);
diagnostics = ironair_state_validity("metal", [n_Fe; n_FeOH2; n_Fe3O4], delta_pass);

T_Fe = inputs.T_Fe_K;
c = p.constants;
% FE-006: temperature-dependent exchange current. Constitutive equation.
[j_0_Fe_T, ~] = ironair_reaction_rate_constant( ...
    p.iron_electrode.j_0_Fe_ref_A_m2, p.iron_electrode.E_a_Fe_J_mol, T_Fe, p);
j_0_Fe = j_0_Fe_T;
a_OH = max(inputs.a_OH, 1e-12);
a_Fe = ones(n_nodes, 1);
a_FeOH2 = ones(n_nodes, 1);
if isfield(inputs, "a_Fe")
    a_Fe = inputs.a_Fe .* a_Fe;
end
if isfield(inputs, "a_FeOH2")
    a_FeOH2 = inputs.a_FeOH2 .* a_FeOH2;
end

% FE-002
e_Fe_eq = p.iron_electrode.e_Fe_std_V + ...
    (c.R_J_molK .* T_Fe ./ (2 .* c.F_C_mol)) .* ...
    log(a_FeOH2 ./ (a_Fe .* a_OH.^2));

V_electrode = p.cell_geometry.V_electrode_m3 / n_nodes;
n_solid = [n_Fe.'; n_FeOH2.'; n_Fe3O4.'];
V_molar = [p.iron_phases.V_m_Fe_m3_mol; p.iron_phases.V_m_FeOH2_m3_mol; ...
    p.iron_phases.V_m_Fe3O4_m3_mol];
% FE-010: porosity includes iron phases and inert structure. Constitutive equation.
V_inert = p.iron_phases.V_inert_m3 / n_nodes;
epsilon_Fe = 1 - ((V_molar.' * n_solid).' + V_inert) ./ V_electrode;
f_wet = ones(n_nodes, 1);
if isfield(inputs, "f_wet_Fe")
    f_wet = inputs.f_wet_Fe .* f_wet;
end
f_pass = 1 ./ (1 + max(delta_pass, 0) ./ 1e-8);
f_availability = max(n_Fe, 0) ./ max(n_Fe + n_FeOH2 + n_Fe3O4, 1e-12);
f_area_scale = 1;
if isfield(inputs, "f_area_scale")
    f_area_scale = inputs.f_area_scale;
end
% FE-011: effective active area. Constitutive equation.
A_active_Fe = p.iron_electrode.A_geometric_Fe_m2 ./ n_nodes .* ...
    p.iron_electrode.a_s_Fe .* f_wet .* f_pass .* f_availability .* f_area_scale;

phi_l = 0;
if isfield(inputs, "phi_l_Fe_V")
    phi_l = inputs.phi_l_Fe_V;
end

if isfield(inputs, "eta_Fe_V")
    eta_Fe = inputs.eta_Fe_V .* ones(n_nodes, 1);
    phi_s_Fe = eta_Fe + phi_l + e_Fe_eq;
    eta_Fe = min(max(eta_Fe, -1.2), 1.2);
    % FE-003: Butler-Volmer kinetics. Constitutive equation.
    [j_Fe, bv_diag] = ironair_butler_volmer(j_0_Fe, ...
        p.iron_electrode.alpha_a_Fe, p.iron_electrode.alpha_c_Fe, 2, ...
        eta_Fe, T_Fe, c);
else
    I_Fe_total = inputs.I_Fe_A;
    I_share = I_Fe_total * (A_active_Fe ./ max(sum(A_active_Fe), 1e-12));
    eta_Fe = zeros(n_nodes, 1);
    j_Fe = zeros(n_nodes, 1);
    bv_diag = struct("clipped", false(n_nodes, 1));
    for node = 1:n_nodes
        area = max(A_active_Fe(node), 1e-12);
        [eta_Fe(node), j_Fe(node), ~] = ironair_solve_overpotential( ...
            I_share(node) / area, j_0_Fe, p.iron_electrode.alpha_a_Fe, ...
            p.iron_electrode.alpha_c_Fe, 2, T_Fe, c);
    end
    phi_s_Fe = eta_Fe + phi_l + e_Fe_eq;
end

% FE-004, FE-005
I_Fe = A_active_Fe .* j_Fe;
I_mag = zeros(n_nodes, 1);
if p.iron_phases.enable_magnetite
    e_mag_eq = p.iron_phases.e_mag_std_V;
    eta_mag = phi_s_Fe - phi_l - e_mag_eq;
    j_mag = ironair_butler_volmer(p.iron_phases.j_0_mag_A_m2, 0.5, 0.5, 2, ...
        eta_mag, T_Fe, c);
    I_mag = A_active_Fe .* j_mag;
    % Magnetite cannot be reduced or produced from an empty reactant inventory.
    scale_forward = max(n_FeOH2, 0) ./ (max(n_FeOH2, 0) + 1e-8);
    scale_reverse = max(n_Fe3O4, 0) ./ (max(n_Fe3O4, 0) + 1e-8);
    I_mag = max(I_mag, 0) .* scale_forward + min(I_mag, 0) .* scale_reverse;
end

% FE-001: Fe + 2OH- <-> FeOH2 + 2e-. Oxidation extent is positive on discharge.
% FE-014: 3FeOH2 + 2OH- <-> Fe3O4 + 4H2O + 2e- when magnetite is enabled.
% FE-007, FE-008, FE-015, FE-016 assembled through Faraday extents.
r_Fe_ox = I_Fe ./ (2 .* c.F_C_mol);
r_mag = I_mag ./ (2 .* c.F_C_mol);
dn_Fe_dt = -r_Fe_ox;
dn_FeOH2_dt = r_Fe_ox - 3 .* r_mag;
dn_Fe3O4_dt = r_mag;

g_pass_removal = max(0, -eta_Fe) .* (T_Fe ./ c.T_ref_K) .* a_OH;
% FE-012
ddelta_pass_dt = p.iron_electrode.k_pass_growth_m_s .* abs(j_Fe).^p.iron_electrode.m_pass ...
    - p.iron_electrode.k_pass_removal_m_s .* g_pass_removal;

% FE-013
R_pass = delta_pass ./ (p.iron_electrode.sigma_pass_S_m .* max(A_active_Fe, 1e-12));
% FE-009
U_Fe = 1 - n_Fe ./ max(p.cell_geometry.n_Fe_initial_mol / n_nodes, 1e-12);
rho_Fe = ironair_iron_electrical_resistivity(T_Fe, p);

dx = [dn_Fe_dt; dn_FeOH2_dt; dn_Fe3O4_dt; ddelta_pass_dt];
outputs = struct( ...
    "n_Fe_mol", n_Fe, ...
    "n_FeOH2_mol", n_FeOH2, ...
    "n_Fe3O4_mol", n_Fe3O4, ...
    "I_Fe_A", I_Fe, ...
    "I_mag_A", I_mag, ...
    "j_Fe_A_m2", j_Fe, ...
    "eta_Fe_V", eta_Fe, ...
    "e_Fe_eq_V", e_Fe_eq, ...
    "phi_s_Fe_V", phi_s_Fe, ...
    "A_active_Fe_m2", A_active_Fe, ...
    "epsilon_Fe", epsilon_Fe, ...
    "U_Fe", U_Fe, ...
    "R_pass_Ohm", R_pass, ...
    "r_Fe_ox_mol_s", r_Fe_ox, ...
    "r_mag_mol_s", r_mag, ...
    "rho_Fe_Ohm_m", rho_Fe);
diagnostics.bv = bv_diag;
diagnostics.t = t;
diagnostics.iron_atom_residual_mol = n_Fe + n_FeOH2 + 3 * n_Fe3O4;
end

function n_nodes = node_count(inputs)
n_nodes = 1;
if isfield(inputs, "n_nodes")
    n_nodes = inputs.n_nodes;
end
end
