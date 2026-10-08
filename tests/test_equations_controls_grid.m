function tests = test_equations_controls_grid
tests = functiontests(localfunctions);
end

function setupOnce(test_case)
root = fileparts(fileparts(mfilename("fullpath")));
addpath(root);
ironair_setup();
test_case.TestData.p = ironair_configuration_profile("grid_scale_1MW", "smoke");
end

function test_grid_droop_and_pu(test_case)
p = test_case.TestData.p;
out = ironair_grid_model(0, struct("f_grid_Hz", 59.5, ...
    "V_grid_V", p.grid.V_grid_base_V, "P_scheduled_W", 1e6, ...
    "V_grid_measured_V", p.grid.V_grid_base_V, "dP_requested_dt", 0), p);
verifyEqual(test_case, out.delta_f_grid_Hz, -0.5, "AbsTol", 1e-12);
verifyEqual(test_case, out.V_grid_pu, 1, "AbsTol", 1e-12);
end

function test_ride_through_is_non_certification(test_case)
p = test_case.TestData.p;
[~, out, diag] = ironair_der_ride_through(0, 0, struct("V_grid_pu", 1, ...
    "f_grid_Hz", 60), p);
verifyFalse(test_case, out.certification_claim);
verifyTrue(test_case, diag.assumed_table);
end

function test_controller_priority_and_soc_window(test_case)
p = test_case.TestData.p;
in = default_ctrl(p);
in.command = "discharge";
[~, out] = ironair_supervisory_controller(0, 0, in, p);
verifyTrue(test_case, out.SOC_valid);
in.grid_fault = true;
[~, outf] = ironair_supervisory_controller(0, 0, in, p);
verifyEqual(test_case, outf.mode, 16);
end

function test_estimator_without_true_state(test_case)
p = test_case.TestData.p;
in = struct("I_measured_A", 2, "V_measured_V", 1.1);
[~, out, diag] = ironair_state_estimator(0, 0.5, in, p);
verifyTrue(test_case, diag.observer_mode);
verifyGreaterThan(test_case, out.Q_usable_C, 0);
end

function test_degradation_monotonic(test_case)
p = test_case.TestData.p;
[dx, out] = ironair_degradation_ode(0, [1; 0; 0], struct("T_cell_K", 320, ...
    "I_cell_A", 5, "SOC", 0.5), p);
verifyLessThanOrEqual(test_case, dx(1), 0);
verifyGreaterThanOrEqual(test_case, dx(2), 0);
verifyGreaterThanOrEqual(test_case, dx(3), 0);
verifyGreaterThan(test_case, out.k_aging, 0);
end

function test_fault_modifies_physics(test_case)
p = test_case.TestData.p;
sched = struct("fan_failure", struct("onset_s", 0, "duration_s", 10), ...
    "cell_short", struct("onset_s", 0, "duration_s", 10));
[flt, ~] = ironair_fault_schedule(1, sched, p);
verifyTrue(test_case, flt.fan_failed);
verifyEqual(test_case, flt.R_short_Ohm, p.fault_detection.R_short_fault_Ohm);
x = [1.1; 0];
in = struct("y_true", 1.2, "sensor_noise", 0, "Q_electrolyte_in_m3_s", 1e-5, ...
    "Q_electrolyte_out_m3_s", 1e-5, "N_fan", 0.02, "N_fan_command", 0.02, ...
    "V_cell_V", 1.1, "R_ohmic_Ohm", 0.02, "e_oc_V", 1.28, "I_external_A", 2, ...
    "fault_name", "short");
[~, out] = ironair_fault_injection(0, x, in, p);
verifyGreaterThan(test_case, out.I_short_A, 0);
end

function in = default_ctrl(p)
in = struct("SOC", 0.5, "T_cell_K", 298.15, "I_ref_A", 2, ...
    "I_measured_A", 1.8, "I_limit_A", 20, "P_rated_W", p.reference.P_AC_rated_W, ...
    "grid_ready", true, "thermal_ready", true, ...
    "fluid_ready", true, "electrodes_ready", true, "command", "idle", ...
    "P_charge_converter_limit_W", 1e6, "P_charge_electrochemical_limit_W", 1e6, ...
    "P_charge_thermal_limit_W", 1e6, "P_charge_grid_limit_W", 1e6, ...
    "P_discharge_converter_limit_W", 1e6, "P_discharge_oxygen_limit_W", 1e6, ...
    "P_discharge_electrochemical_limit_W", 1e6, "P_discharge_thermal_limit_W", 1e6, ...
    "grid_fault", false, "electrolyte_fault", false, "H2_fault", false, ...
    "controller_failed", false, "oxygen_limited", false);
end
