function results = ironair_scenario_100h_1MW(resolution_name)
arguments
    resolution_name (1, 1) string = "smoke"
end
ironair_setup();
p = ironair_configuration_profile("grid_scale_1MW", resolution_name);
p.fidelity_level = 1;
t_end = 2;
if resolution_name == "reference"
    t_end = 3600;
elseif resolution_name == "standard"
    t_end = 60;
end
scenario = struct("name", "hundred_hour", "I_cell_A", 1, "command", "discharge", ...
    "t_span_s", [0, t_end], "P_ref_W", 1e6);
results = ironair_run_simulation(p, scenario);
end
