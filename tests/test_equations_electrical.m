function tests = test_equations_electrical
tests = functiontests(localfunctions);
end

function setupOnce(test_case)
root = fileparts(fileparts(mfilename("fullpath")));
addpath(root);
ironair_setup();
test_case.TestData.p = ironair_configuration_profile("small_stack", "smoke");
end

function test_stack_power_polarity(test_case)
p = test_case.TestData.p;
in = struct("V_cell_V", 1.1, "I_cell_A", 2);
out = ironair_stack_model(0, in, p);
verifyGreaterThan(test_case, out.P_stack_W, 0);
verifyEqual(test_case, out.V_stack_V, p.stack.N_series * 1.1, "RelTol", 1e-12);
end

function test_dc_bus_energy(test_case)
p = test_case.TestData.p;
[dx, out] = ironair_dc_bus_ode(0, 1000, struct("I_source_A", 10, "I_load_A", 4), p);
verifyGreaterThan(test_case, dx, 0);
verifyEqual(test_case, out.E_dc_J, 0.5 * p.dc_bus.C_dc_F * 1000^2, "RelTol", 1e-12);
end

function test_converter_and_inverter(test_case)
p = test_case.TestData.p;
[~, conv] = ironair_dcdc_converter(0, [10; 800], struct("d_duty", 0.6, ...
    "V_in_V", 1000, "I_out_A", 8), p);
verifyGreaterThan(test_case, conv.P_switching_W, 0);
[~, inv] = ironair_inverter(0, [0; 0], struct("V_LL_V", 480, "phi_power_rad", 0, ...
    "I_line_A", 100, "P_ref_W", 1e5, "Q_ref_var", 0), p);
verifyGreaterThan(test_case, inv.P_AC_W, 0);
verifyEqual(test_case, inv.S_AC_VA, abs(inv.P_AC_W), "RelTol", 1e-8);
end

function test_transformer_ratio(test_case)
p = test_case.TestData.p;
[~, out] = ironair_transformer(0, 310, struct("V_primary_V", 12470, ...
    "I_secondary_A", 100, "f_transformer_Hz", 60, "B_peak_T", 1.2, ...
    "T_ambient_K", 298.15), p);
verifyEqual(test_case, out.V_secondary_V, ...
    12470 * p.transformer.N_secondary / p.transformer.N_primary, "RelTol", 1e-12);
end

function test_protection_trip(test_case)
p = test_case.TestData.p;
out = ironair_electrical_protection(0, struct("I_A", 1e9, "V_dc_V", 1000, ...
    "precharge", false), p);
verifyTrue(test_case, out.trip);
end
