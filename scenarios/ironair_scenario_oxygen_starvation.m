function results = ironair_scenario_oxygen_starvation(resolution_name)
arguments
    resolution_name (1, 1) string = "smoke"
end
ironair_setup();
p = ironair_configuration_profile("single_cell", resolution_name);
p.fidelity_level = 1;
schedule = struct("oxygen_starvation", struct("onset_s", 0.2, "duration_s", 2));
scenario = struct("name", "oxygen_starvation", "I_cell_A", 1, ...
    "command", "discharge", "t_span_s", [0, 2], "fault_schedule", schedule);
results = ironair_run_simulation(p, scenario);
end
