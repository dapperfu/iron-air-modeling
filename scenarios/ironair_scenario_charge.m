function results = ironair_scenario_charge(resolution_name)
%IRONAIR_SCENARIO_CHARGE Principal charging scenario.
arguments
    resolution_name (1, 1) string = "smoke"
end
ironair_setup();
p = ironair_configuration_profile("single_cell", resolution_name);
p.fidelity_level = 1;
scenario = struct("name", "charge", "I_cell_A", -1, "command", "charge", ...
    "t_span_s", [0, 2]);
results = ironair_run_simulation(p, scenario);
end
