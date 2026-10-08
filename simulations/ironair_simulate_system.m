function results = ironair_simulate_system(scenario_name, resolution_name, t_final_s)
%IRONAIR_SIMULATE_SYSTEM Integrate one coupled plant scenario.
%   RESULTS = IRONAIR_SIMULATE_SYSTEM(SCENARIO_NAME, RESOLUTION_NAME, T_FINAL_S)
%   uses ode15s. Solver failures return an explicit diagnostic instead of an
%   empty result.
%
%   Requirements: SRS018, SRS023.

arguments
    scenario_name (1, 1) string = "discharge"
    resolution_name (1, 1) string = "smoke"
    t_final_s (1, 1) double = 30
end

ironair_setup();
p = ironair_configuration_profile("single_cell", resolution_name);
p.fidelity_level = 1;
scenario = ironair_scenario_inputs(0, scenario_name, p);
[x0, ~] = ironair_system_initial_state(p, scenario.I_cell_command_A);
profile = p.resolution;
scale = max(abs(x0), 1e-6);
options = ironair_solver_options(profile, scale);
rhs = @(t, x) ironair_system_ode(t, x, p, scenario_name);
results = struct("scenario", scenario_name, "status", "ok", "diagnostic", "");
try
    [t_sim, x] = ode15s(rhs, [0, t_final_s], x0, options);
catch solver_error
    results.status = "solver_failure";
    results.diagnostic = solver_error.message;
    results.t_s = 0;
    results.x = x0.';
    results.V_cell_V = NaN;
    results.P_grid_export_W = NaN;
    results.P_grid_import_W = NaN;
    results.eta_round_trip_AC = NaN;
    return;
end

n_out = min(48, numel(t_sim));
sample = unique(round(linspace(1, numel(t_sim), n_out)));
V = zeros(numel(sample), 1);
P_export = zeros(numel(sample), 1);
P_import = zeros(numel(sample), 1);
for k = 1:numel(sample)
    [~, out] = ironair_system_ode(t_sim(sample(k)), x(sample(k), :).', p, scenario_name);
    P_export(k) = out.P_grid_export_W;
    P_import(k) = out.P_grid_import_W;
    V(k) = out.V_cell_V;
end
history = struct("t_sim", t_sim(sample), "P_grid_export_W", P_export, "P_grid_import_W", P_import);
[~, ~, diagnostics] = ironair_system_ode(t_sim(end), x(end, :).', p, scenario_name, history);
results.t_s = t_sim;
results.x = x;
results.t_sample_s = t_sim(sample);
results.V_cell_V = V;
results.P_grid_export_W = P_export;
results.P_grid_import_W = P_import;
results.eta_round_trip_AC = diagnostics.eta_round_trip_AC;
results.element_ok = diagnostics.element_ok;
results.current_ok = diagnostics.current_ok;
results.p = p;
end
