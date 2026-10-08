function results = ironair_scenario_grid_disturbance(resolution_name)
arguments
    resolution_name (1, 1) string = "smoke"
end
ironair_setup();
p = ironair_configuration_profile("grid_scale_1MW", resolution_name);
p.fidelity_level = 1;
schedule = struct("grid_undervoltage", struct("onset_s", 0.5, "duration_s", 1));
scenario = struct("name", "grid_disturbance", "I_cell_A", 1, ...
    "command", "discharge", "t_span_s", [0, 2], ...
    "V_grid_V", 0.5 * p.grid.V_grid_base_V, "fault_schedule", schedule);
results = ironair_run_simulation(p, scenario);
end
