function tests = test_equations_balance_of_plant
tests = functiontests(localfunctions);
end

function setupOnce(test_case)
root = fileparts(fileparts(mfilename("fullpath")));
addpath(root);
ironair_setup();
test_case.TestData.p = ironair_configuration_profile("single_cell", "smoke");
end

function test_heat_exchanger_ntu(test_case)
p = test_case.TestData.p;
in = struct("T_hot_K", 320, "T_cold_in_K", 290);
out = ironair_heat_exchanger(0, in, p);
verifyGreaterThan(test_case, out.Q_dot_HX_W, 0);
verifyGreaterThan(test_case, out.NTU_HX, 0);
verifyGreaterThan(test_case, out.epsilon_HX, 0);
end

function test_thermal_nodes_finite(test_case)
p = test_case.TestData.p;
x = 298.15 * ones(3, 1);
in = struct("I_cell_A", 2, "R_ohmic_Ohm", 0.01, "A_reaction_m2", 1, ...
    "j_reaction_A_m2", 10, "eta_reaction_V", 0.05, "T_ambient_K", 298.15, ...
    "m_dot_coolant_kg_s", 0.01, "cp_coolant_J_kgK", 4000, ...
    "T_coolant_out_K", 300, "T_coolant_in_K", 290, "Q_dot_collector_W", 1);
[dx, out] = ironair_thermal_ode(0, x, in, p);
verifyEqual(test_case, numel(dx), 3);
verifyGreaterThan(test_case, out.Q_dot_ohmic_W, 0);
end

function test_fan_affinity_and_h2(test_case)
p = test_case.TestData.p;
T0 = 298.15;
n_gas = p.reference.p_ambient_Pa .* p.cell_geometry.V_gas_m3 ./ ...
    (p.constants.R_J_molK .* T0);
x = [0.21 * n_gas; 0.79 * n_gas; 1];
in = struct("T_gas_K", T0, "n_dot_O2_ORR_mol_s", 1e-5, ...
    "n_dot_O2_OER_mol_s", 0, "N_fan_command", 1);
[~, out] = ironair_air_system_ode(0, x, in, p);
verifyGreaterThan(test_case, out.P_fan_electric_W, 0);
verifyGreaterThan(test_case, out.lambda_O2, 0);
end

function test_pump_zero_and_reynolds(test_case)
p = test_case.TestData.p;
p.electrolyte_circulation.enabled = true;
x = [p.reservoir.V_reservoir_initial_m3; p.pumps.omega_nominal_rad_s];
in = struct("rho_fluid_kg_m3", 1200, "mu_fluid_Pa_s", 0.002, ...
    "c_i_in_mol_m3", 6000, "c_i_tank_mol_m3", 6000, "Q_leak_m3_s", 0);
[~, out] = ironair_electrolyte_flow_ode(0, x, in, p);
verifyGreaterThan(test_case, out.Re_flow, 0);
verifyGreaterThan(test_case, out.P_pump_electric_W, 0);
in.pump_failed = true;
x(2) = 0;
[~, out0] = ironair_electrolyte_flow_ode(0, x, in, p);
verifyEqual(test_case, out0.Q_pump_m3_s, 0, "AbsTol", 1e-12);
end
