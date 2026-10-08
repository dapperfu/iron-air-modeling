function results = ironair_scenario_discharge(resolution_name)
%IRONAIR_SCENARIO_DISCHARGE Principal discharging scenario.
arguments
    resolution_name (1, 1) string = "smoke"
end
ironair_setup();
p = ironair_configuration_profile("single_cell", resolution_name);
p.fidelity_level = 1;
scenario = struct("name", "discharge", "I_cell_A", 1, "command", "discharge", ...
    "t_span_s", local_span(resolution_name));
results = ironair_run_simulation(p, scenario);
end

function t_span = local_span(resolution_name)
t_span = [0, 2];
if resolution_name == "standard"
    t_span = [0, 30];
elseif resolution_name == "reference"
    t_span = [0, 120];
end
end
