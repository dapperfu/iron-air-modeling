function results = ironair_sim_cell(resolution_name, I_cell_A, t_final_s)
%IRONAIR_SIM_CELL Standalone coupled electrochemical cell.
%   RESULTS = IRONAIR_SIM_CELL(RESOLUTION_NAME, I_CELL_A, T_FINAL_S)
%   Requirements: SRS007.

arguments
    resolution_name (1, 1) string = "smoke"
    I_cell_A (1, 1) double = 2
    t_final_s (1, 1) double = 120
end

ironair_setup();
p = ironair_configuration_profile("single_cell", resolution_name);
p.fidelity_level = 1;
[x0, ~] = ironair_cell_initial_state(p, I_cell_A);
inputs = struct("I_cell_A", I_cell_A, "T_cell_K", p.reference.T_initial_K);
scale = max(abs(x0), 1e-8);
profile = p.resolution;
tau_dl_s = min(p.iron_electrode.C_dl_Fe_F, p.air_electrode.C_dl_air_F) / ...
    max(abs(I_cell_A), 1e-3);
profile.max_step_s = min(profile.max_step_s, max(1e-3, min(0.05, 0.2 * tau_dl_s)));
[~, map] = ironair_cell_initial_state(p, I_cell_A);
nonneg = [map.metal(:); map.her; map.electrolyte(:); map.gdl(:)];
options = ironair_solver_options(profile, scale, [], [], nonneg);
rhs = @(t, x) local_dx(t, x, inputs, p);
[t, x] = ode15s(rhs, [0, t_final_s], x0, options);
n_out = min(20, numel(t));
idx = unique(round(linspace(1, numel(t), n_out)));
V = zeros(numel(idx), 1);
P = zeros(numel(idx), 1);
SOC = zeros(numel(idx), 1);
for k = 1:numel(idx)
    [~, out] = ironair_cell_model(t(idx(k)), x(idx(k), :).', inputs, p);
    V(k) = out.V_cell_V;
    P(k) = out.P_cell_W;
    SOC(k) = out.SOC;
end
results = struct("t_s", t, "x", x, "t_sample_s", t(idx), "V_cell_V", V, ...
    "P_cell_W", P, "SOC", SOC, "p", p, "I_cell_A", I_cell_A);
end

function dx = local_dx(t, x, inputs, p)
[dx, ~, ~] = ironair_cell_model(t, x, inputs, p);
end
