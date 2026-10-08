function results = ironair_scenario_rest(resolution_name)
arguments
    resolution_name (1, 1) string = "smoke"
end
ironair_setup();
p = ironair_configuration_profile("single_cell", resolution_name);
p.fidelity_level = 1;
scenario = struct("name", "rest", "I_cell_A", 0, "command", "rest", ...
    "t_span_s", [0, 2]);
results = ironair_run_simulation(p, scenario);
end
