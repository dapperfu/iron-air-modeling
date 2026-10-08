function results = ironair_sim_level2(resolution_name)
arguments
    resolution_name (1, 1) string = "smoke"
end
ironair_setup();
p = ironair_configuration_profile("small_stack", resolution_name);
p.fidelity_level = 2;
scenario = struct("name", "discharge", "I_cell_A", 1, "command", "discharge", ...
    "t_span_s", [0, 1.5]);
results = ironair_run_simulation(p, scenario);
end
