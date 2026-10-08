function tests = test_system_scenarios
tests = functiontests(localfunctions);
end

function setupOnce(~)
root = fileparts(fileparts(mfilename("fullpath")));
addpath(root);
ironair_setup();
end

function test_discharge_and_rest_run(test_case)
d = ironair_scenario_discharge("smoke");
r = ironair_scenario_rest("smoke");
verifyFalse(test_case, d.solver_failed);
verifyFalse(test_case, r.solver_failed);
verifyGreaterThan(test_case, numel(d.t_s), 2);
end

function test_charge_and_switching(test_case)
c = ironair_scenario_charge("smoke");
s = ironair_scenario_direction_switch("smoke");
verifyFalse(test_case, c.solver_failed);
verifyFalse(test_case, s.solver_failed);
verifyGreaterThan(test_case, s.t_s(end), 1);
verifyTrue(test_case, c.element_ok);
verifyTrue(test_case, c.current_ok);
end

function test_fault_and_starvation_run(test_case)
s = ironair_scenario_oxygen_starvation("smoke");
f = ironair_scenario_faults("smoke");
verifyFalse(test_case, s.solver_failed);
verifyFalse(test_case, f.solver_failed);
end

function test_fidelity_scripts_exist(test_case)
verifyTrue(test_case, exist("ironair_sim_level1", "file") == 2);
verifyTrue(test_case, exist("ironair_sim_level2", "file") == 2);
verifyTrue(test_case, exist("ironair_sim_level3", "file") == 2);
end
