function [dx, outputs, diagnostics] = ironair_electrolyte_ode(t, x, inputs, p)
%IRONAIR_ELECTROLYTE_ODE KOH inventories, carbonation, and transport.
%   [DX, OUTPUTS, DIAGNOSTICS] = IRONAIR_ELECTROLYTE_ODE(T, X, INPUTS, P)
%   tracks water, KOH ions, dissolved gases, and optional 1D Nernst-Planck
%   fields.
%
%   Lumped state:
%     n_OH_mol, n_K_mol, n_H2O_mol, n_O2_mol, n_CO2_mol, n_CO3_mol, V_m3
%
%   Equation: ELY-001 through ELY-015
%   Requirements: SRS005.

arguments
    t (1, 1) double
    x (:, 1) double
    inputs (1, 1) struct
    p (1, 1) struct
end

if numel(x) < 7
    error("ironair:ely:StateSize", ...
        "Electrolyte lumped state must contain seven inventory entries.");
end

n_OH = x(1);
n_K = x(2);
n_H2O = x(3);
n_O2 = x(4);
n_CO2 = x(5);
n_CO3 = x(6);
V = max(x(7), 1e-9);
ironair_state_validity("electrolyte", [n_OH; n_K; n_H2O; n_O2; n_CO2; n_CO3; V]);

c_OH = n_OH / V;
c_K = n_K / V;
c_O2 = n_O2 / V;
c_CO2 = n_CO2 / V;
c_CO3 = n_CO3 / V;
c_KOH = 0.5 * (c_OH + c_K);
T = inputs.T_electrolyte_K;
constants = p.constants;

% ELY-003
z = [-1, 1, 0, 0, -2];
c_ions = [c_OH, c_K, c_O2, c_CO2, c_CO3];
e_electroneutrality = sum(z .* c_ions);

% ELY-006
kappa_KOH = ironair_KOH_conductivity(c_KOH, T, p);
% ELY-012
rho_KOH = ironair_KOH_density(c_KOH, T, p);
% ELY-013
mu_KOH = ironair_KOH_viscosity(c_KOH, T, p);
cp_KOH = ironair_KOH_heat_capacity(c_KOH, T, p);
a_H2O = ironair_KOH_water_activity(c_KOH, T, p);
H_O2 = ironair_O2_solubility(c_KOH, T, p);
p_O2 = inputs.p_O2_Pa;
% ELY-014
c_O2_eq = H_O2 .* p_O2;
% ELY-015
n_dot_O2_transfer = p.air_electrode.k_L_a_1_s .* V .* (c_O2_eq - c_O2);
% ELY-010
r_carbonation = p.electrolyte.k_carbonation_m3_mol_s .* c_CO2 .* ...
    max(c_OH, 0).^p.electrolyte.m_carbonation .* V;

net = ironair_reaction_network();
r = zeros(numel(net.reactions), 1);
r(net.idx.Fe_ox) = value_or(inputs, "r_Fe_ox_mol_s", 0);
r(net.idx.magnetite) = value_or(inputs, "r_mag_mol_s", 0);
r(net.idx.ORR) = value_or(inputs, "r_ORR_mol_s", 0);
r(net.idx.OER) = value_or(inputs, "r_OER_mol_s", 0);
r(net.idx.HER) = value_or(inputs, "r_HER_mol_s", 0);
% ELY-009: CO2 + 2OH- -> CO3^2- + H2O.
r(net.idx.carbonation) = r_carbonation;
q = zeros(numel(net.species), 1);
q(net.idx.O2) = n_dot_O2_transfer + value_or(inputs, "n_dot_O2_boundary_mol_s", 0);
q(net.idx.H2O) = value_or(inputs, "n_dot_H2O_boundary_mol_s", 0);
q(net.idx.OH) = value_or(inputs, "n_dot_OH_boundary_mol_s", 0);
q(net.idx.K) = value_or(inputs, "n_dot_K_boundary_mol_s", 0);
q(net.idx.CO2) = value_or(inputs, "n_dot_CO2_boundary_mol_s", 0);
[dn_species, reaction_diag] = ironair_species_rates(r, q, net);

% ELY-007
R_electrolyte = p.cell_geometry.L_electrolyte_m ./ ...
    (kappa_KOH .* p.cell_geometry.A_electrolyte_m2);

dn_OH_dt = dn_species(net.idx.OH);
% ELY-008: potassium changes only through boundary flows. Conservation law.
dn_K_dt = dn_species(net.idx.K);
% ELY-011: water inventory from the stoichiometric network. Conservation law.
dn_H2O_dt = dn_species(net.idx.H2O);
dn_O2_dt = dn_species(net.idx.O2);
dn_CO2_dt = dn_species(net.idx.CO2);
dn_CO3_dt = dn_species(net.idx.CO3);
mass = rho_KOH * V;
dV_dt = (dn_OH_dt * p.constants.M_KOH_kg_mol + ...
    dn_H2O_dt * p.constants.M_H2O_kg_mol) / max(rho_KOH, 1);
% ELY-002: concentration form of species conservation. Conservation law.
dc_OH_dt = (dn_OH_dt .* V - n_OH .* dV_dt) ./ V.^2;
% ELY-005: interfacial current closes the ionic divergence. Conservation law.
I_ionic = value_or(inputs, "I_ionic_A", 0);
A_interface = max(p.iron_electrode.A_geometric_Fe_m2 .* p.iron_electrode.a_s_Fe, 1e-12);
a_s = A_interface ./ max(p.cell_geometry.V_electrode_m3, 1e-12);
j_F = I_ionic ./ A_interface;
div_i_electrolyte = a_s .* j_F;

n_cv = 2;
if isfield(inputs, "enable_spatial") && inputs.enable_spatial
    n_cv = max(2, p.resolution.electrolyte_volumes);
end
c_field = repmat([c_OH, c_K, c_O2, c_CO2, c_CO3], n_cv, 1);
D_field = repmat([p.liquid_transport.D_OH_m2_s, p.liquid_transport.D_K_m2_s, ...
    p.liquid_transport.D_O2_liquid_m2_s, 1e-9, p.liquid_transport.D_CO3_m2_s], n_cv, 1);
phi = linspace(0, I_ionic .* R_electrolyte, n_cv).';
dx_cell = p.cell_geometry.L_electrolyte_m / n_cv;
% ELY-001 is evaluated by the finite-volume Nernst-Planck operator.
[div_N, N_faces] = ironair_finite_volume_1d(c_field, D_field, z, phi, ...
    p.liquid_transport.velocity_m_s, dx_cell, T, constants);
% ELY-004
i_electrolyte = constants.F_C_mol * (N_faces * z.');

dx = [dn_OH_dt; dn_K_dt; dn_H2O_dt; dn_O2_dt; dn_CO2_dt; dn_CO3_dt; dV_dt];
outputs = struct( ...
    "c_OH_mol_m3", c_OH, ...
    "c_K_mol_m3", c_K, ...
    "c_KOH_mol_m3", c_KOH, ...
    "c_O2_mol_m3", c_O2, ...
    "c_CO2_mol_m3", c_CO2, ...
    "c_CO3_mol_m3", c_CO3, ...
    "c_O2_eq_mol_m3", c_O2_eq, ...
    "V_electrolyte_m3", V, ...
    "kappa_KOH_S_m", kappa_KOH, ...
    "rho_KOH_kg_m3", rho_KOH, ...
    "mu_KOH_Pa_s", mu_KOH, ...
    "cp_KOH_J_kgK", cp_KOH, ...
    "a_OH", max(c_OH, 1) / 1000, ...
    "a_H2O", a_H2O, ...
    "R_electrolyte_Ohm", R_electrolyte, ...
    "r_carbonation_mol_s", r_carbonation, ...
    "n_dot_O2_transfer_mol_s", n_dot_O2_transfer, ...
    "dc_OH_dt", dc_OH_dt, ...
    "dn_K_dt", dn_K_dt, ...
    "dn_H2O_dt", dn_H2O_dt, ...
    "div_i_electrolyte_A_m3", div_i_electrolyte, ...
    "mass_kg", mass, ...
    "i_electrolyte_A_m2", i_electrolyte, ...
    "div_N_mol_m3s", div_N);
diagnostics = struct("t", t, "e_electroneutrality", e_electroneutrality, ...
    "reaction", reaction_diag);
end

function value = value_or(inputs, name, default_value)
if isfield(inputs, name)
    value = inputs.(name);
else
    value = default_value;
end
end
