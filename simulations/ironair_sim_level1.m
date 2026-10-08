function results = ironair_sim_level1(resolution_name)
arguments
    resolution_name (1, 1) string = "standard"
end
results = ironair_scenario_discharge(resolution_name);
end
