function results = ironair_scenario_faults(resolution_name)
arguments
    resolution_name (1, 1) string = "smoke"
end
ironair_setup();
p = ironair_configuration_profile("single_cell", resolution_name);
p.fidelity_level = 1;
schedule = struct( ...
    "fan_failure", struct("onset_s", 0.2, "duration_s", 1), ...
    "electrolyte_leak", struct("onset_s", 0.5, "duration_s", 1));
scenario = struct("name", "faults", "I_cell_A", 1, "command", "discharge", ...
    "t_span_s", [0, 2], "fault_schedule", schedule);
results = ironair_run_simulation(p, scenario);
end
