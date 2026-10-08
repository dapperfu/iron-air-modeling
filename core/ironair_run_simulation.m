function results = ironair_run_simulation(p, scenario)
%IRONAIR_RUN_SIMULATION Integrate the coupled plant for one scenario.
%   RESULTS = IRONAIR_RUN_SIMULATION(P, SCENARIO)
%
%   SCENARIO fields:
%     name or command - scenario key consumed by ironair_scenario_inputs
%     t_span_s        - integration interval, s
%     I_cell_A        - optional discharge-positive current override
%     fault_schedule  - optional onset/duration map
%
%   Requirements: SRS018, SRS020, SRS023.

arguments
    p (1, 1) struct
    scenario (1, 1) struct
end

name = "discharge";
if isfield(scenario, "name")
    name = string(scenario.name);
elseif isfield(scenario, "command")
    name = string(scenario.command);
end
name = local_scenario_alias(name);

t_span = [0, 2];
if isfield(scenario, "t_span_s")
    t_span = scenario.t_span_s;
end

history = scenario;
history.name = name;
if isfield(history, "V_grid_V") && ~isfield(history, "V_grid_measured_V")
    history.V_grid_measured_V = history.V_grid_V;
end
if isfield(history, "I_cell_A") && any(name == ["switching", "hundred_hour"])
    history = rmfield(history, "I_cell_A");
end

I0 = 0;
if isfield(scenario, "I_cell_A")
    I0 = scenario.I_cell_A;
else
    command = ironair_scenario_inputs(t_span(1), name, p);
    I0 = command.I_cell_command_A;
end
[x0, map] = ironair_system_initial_state(p, I0);

profile = p.resolution;
horizon_s = t_span(2) - t_span(1);
if p.fidelity_level <= 1 && horizon_s <= 600
    profile.max_step_s = min(profile.max_step_s, 0.5);
    profile.rel_tol = max(profile.rel_tol, 1e-3);
end
scale = max(abs(x0), 1e-2);
nonneg = [map.cell.metal, map.cell.her, map.cell.electrolyte, ...
    map.cell.gdl, map.air_system(1:2), map.flow(1)];
nonneg = unique(nonneg(:));
j_pattern = local_jpattern(map, p.fidelity_level);
options = ironair_solver_options(profile, scale, [], j_pattern, nonneg);
rhs = @(t, x) ironair_system_ode(t, x, p, name, history);
try
    [t, x] = ode15s(rhs, t_span, x0, options);
catch exception
    results = struct("t_s", 0, "x", x0.', "map", map, "p", p, ...
        "name", name, "solver_failed", true, "outputs", {{}}, ...
        "diagnostics", struct("solver_failed", true, "message", exception.message), ...
        "exception", exception);
    return
end

n_out = min(12, numel(t));
idx = unique(round(linspace(1, numel(t), n_out)));
outputs = cell(numel(idx), 1);
V = zeros(numel(idx), 1);
for k = 1:numel(idx)
    [~, outputs{k}] = ironair_system_ode(t(idx(k)), x(idx(k), :).', p, name, history);
    V(k) = outputs{k}.V_cell_V;
end
[~, ~, diagnostics] = ironair_system_ode(t(end), x(end, :).', p, name, history);
results = struct("t_s", t, "x", x, "t_sample_s", t(idx), "outputs", {outputs}, ...
    "V_cell_V", V, "map", map, "p", p, "name", name, "history", history, ...
    "solver_failed", false, "element_ok", diagnostics.element_ok, ...
    "current_ok", diagnostics.current_ok, "diagnostics", diagnostics);
end

function j_pattern = local_jpattern(map, fidelity_level)
n = map.count;
j_pattern = speye(n);
j_pattern(1:map.n_cell, 1:map.n_cell) = 1;
blocks = {map.thermal, map.air_system, map.flow, map.degradation, ...
    map.sensor, map.enclosure};
for index = 1:numel(blocks)
    idx = blocks{index};
    j_pattern(idx, idx) = 1;
end
if fidelity_level <= 1
    frozen = [map.dc, map.converter, map.inverter, map.transformer, ...
        map.controller, map.ride];
    j_pattern(:, frozen) = 0;
    j_pattern(frozen, :) = 0;
end
end

function name = local_scenario_alias(name)
switch name
    case {"idle", "rest"}
        name = "rest";
    case {"direction_switch", "switching"}
        name = "switching";
    case {"100h", "100h_1MW", "hundred_hour"}
        name = "hundred_hour";
    otherwise
end
end
