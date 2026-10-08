function results = ironair_scenario_thermal_extreme(resolution_name)
arguments
    resolution_name (1, 1) string = "smoke"
end
ironair_setup();
p = ironair_configuration_profile("high_temperature", resolution_name);
p.fidelity_level = 1;
scenario = struct("name", "thermal_extreme", "I_cell_A", 1, ...
    "command", "discharge", "t_span_s", [0, 2], "T_ambient_K", 333.15);
results = ironair_run_simulation(p, scenario);
end
