function results = ironair_scenario_degradation(resolution_name)
arguments
    resolution_name (1, 1) string = "smoke"
end
ironair_setup();
p = ironair_configuration_profile("degraded_cell", resolution_name);
p.fidelity_level = 1;
scenario = struct("name", "degradation", "I_cell_A", 1, "command", "discharge", ...
    "t_span_s", [0, 2]);
results = ironair_run_simulation(p, scenario);
end
