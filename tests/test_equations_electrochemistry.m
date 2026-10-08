function tests = test_equations_electrochemistry
%TEST_EQUATIONS_ELECTROCHEMISTRY Verify FE through CELL equations.
%   Requirements: SRS003 through SRS007, SRS023.
tests = functiontests(localfunctions);
end

function setupOnce(test_case)
root = fileparts(fileparts(mfilename("fullpath")));
addpath(root);
ironair_setup();
p = ironair_configuration_profile("single_cell", "smoke");
p.fidelity_level = 1;
test_case.TestData.p = p;
end

function test_butler_volmer_zero_drive(test_case)
p = test_case.TestData.p;
j = ironair_butler_volmer(1, 0.5, 0.5, 2, 0, 298.15, p.constants);
verifyEqual(test_case, j, 0, "AbsTol", 1e-12);
end

function test_metal_iron_conservation_and_signs(test_case)
p = test_case.TestData.p;
x = [10; 10; 0; 0];
inputs = struct("T_Fe_K", 298.15, "a_OH", 6, "I_Fe_A", 4, "n_nodes", 1);
[dx, out] = ironair_metal_ode(0, x, inputs, p);
verifyGreaterThan(test_case, out.I_Fe_A, 0);
verifyLessThan(test_case, dx(1), 0);
verifyGreaterThan(test_case, dx(2), 0);
verifyEqual(test_case, dx(1) + dx(2) + 3 * dx(3), 0, "AbsTol", 1e-12);
end

function test_her_generation_when_cathodic(test_case)
p = test_case.TestData.p;
x = 0;
inputs = struct("T_Fe_K", 298.15, "A_active_Fe_m2", 2, ...
    "phi_s_Fe_V", -1.0, "I_Fe_A", -5, "a_H2O", 0.7);
[dx, out] = ironair_HER_model(0, x, inputs, p);
verifyLessThanOrEqual(test_case, out.I_HER_A, 0);
verifyGreaterThanOrEqual(test_case, out.dn_H2_generation_dt, -1e-15);
verifyGreaterThanOrEqual(test_case, dx, -1e-15);
end

function test_air_orr_negative_on_negative_eta(test_case)
p = test_case.TestData.p;
x = [0.1; 1; 1];
inputs = struct("T_air_K", 298.15, "a_OH", 6, "a_H2O", 0.7, "a_O2", 0.21, ...
    "c_KOH_mol_m3", 6000, "c_O2_bulk_mol_m3", 0.4, "eta_air_V", -0.2);
[~, out] = ironair_air_electrode_ode(0, x, inputs, p);
verifyLessThan(test_case, out.I_ORR_A, 0);
verifyGreaterThanOrEqual(test_case, out.I_OER_A, 0);
verifyGreaterThan(test_case, out.j_lim_O2_A_m2, 0);
end

function test_electrolyte_electroneutrality_and_properties(test_case)
p = test_case.TestData.p;
V = p.electrolyte.V_electrolyte_initial_m3;
x = [6000*V; 6000*V; 30; 0.4*V; 1e-4*V; 0; V];
inputs = struct("T_electrolyte_K", 298.15, "p_O2_Pa", 21278);
[~, out, diag] = ironair_electrolyte_ode(0, x, inputs, p);
verifyEqual(test_case, diag.e_electroneutrality, 0, "AbsTol", 1e-8);
verifyGreaterThan(test_case, out.kappa_KOH_S_m, 0);
verifyGreaterThan(test_case, out.R_electrolyte_Ohm, 0);
end

function test_separator_and_collector_signs(test_case)
p = test_case.TestData.p;
sep_in = struct("kappa_KOH_S_m", 20, "T_left_K", 310, "T_right_K", 300);
[sep] = ironair_separator_model(0, sep_in, p);
verifyGreaterThan(test_case, sep.R_separator_Ohm, 0);
verifyGreaterThan(test_case, sep.Q_dot_separator_W, 0);
col = ironair_current_collector(0, struct("T_collector_K", 298.15, "I_cell_A", 3), p);
verifyGreaterThan(test_case, col.P_joule_W, 0);
verifyEqual(test_case, col.V_drop_V, 3 * col.R_collector_Ohm, "RelTol", 1e-12);
end

function test_gdl_oxygen_gradient(test_case)
p = test_case.TestData.p;
n_cv = p.resolution.oxygen_control_volumes;
c_gas = 8;
x = [c_gas * ones(n_cv, 1); 0.1];
inputs = struct("T_air_K", 298.15, "p_gas_Pa", 101325, "p_liquid_Pa", 101325, ...
    "c_O2_gas_mol_m3", c_gas, "n_dot_O2_consumed_mol_s", 1e-6);
[dx, out] = ironair_gas_diffusion_layer(0, x, inputs, p);
verifyGreaterThan(test_case, out.D_O2_eff_m2_s, 0);
verifyLessThan(test_case, dx(end-1), 1e-3);
end

function test_cell_discharge_polarity_and_soc(test_case)
p = test_case.TestData.p;
[x0, ~] = ironair_cell_initial_state(p, 1);
inputs = struct("I_cell_A", 1, "T_cell_K", 298.15);
[dx, out, diag] = ironair_cell_model(0, x0, inputs, p);
verifyGreaterThan(test_case, out.e_cell_eq_V, 0.5);
verifyEqual(test_case, out.P_cell_W, out.V_cell_V * 1, "RelTol", 1e-12);
verifyGreaterThan(test_case, out.SOC, 0);
verifyLessThan(test_case, out.SOC, 1);
verifyEqual(test_case, numel(dx), numel(x0));
verifyTrue(test_case, isfinite(diag.e_current_negative));
end

function test_cell_charge_reverses_iron_current_direction(test_case)
p = test_case.TestData.p;
x_d = ironair_cell_initial_state(p, 2);
x_c = ironair_cell_initial_state(p, -2);
in_d = struct("I_cell_A", 2, "T_cell_K", 298.15);
in_c = struct("I_cell_A", -2, "T_cell_K", 298.15);
[~, out_d] = ironair_cell_model(0, x_d, in_d, p);
[~, out_c] = ironair_cell_model(0, x_c, in_c, p);
verifyGreaterThan(test_case, out_d.I_Fe_A, out_c.I_Fe_A);
end

function test_short_cell_integration(test_case)
results = ironair_sim_cell("smoke", 1, 5);
verifyGreaterThan(test_case, numel(results.t_s), 2);
verifyTrue(test_case, all(isfinite(results.V_cell_V)));
end
