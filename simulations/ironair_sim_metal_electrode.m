function results = ironair_sim_metal_electrode(resolution_name)
%IRONAIR_SIM_METAL_ELECTRODE Standalone iron-electrode discharge.
%   RESULTS = IRONAIR_SIM_METAL_ELECTRODE(RESOLUTION_NAME)
%   Requirements: SRS003.

arguments
    resolution_name (1, 1) string = "smoke"
end

ironair_setup();
p = ironair_configuration_profile("single_cell", resolution_name);
n_nodes = 1;
x0 = [p.cell_geometry.n_Fe_initial_mol; p.cell_geometry.n_FeOH2_initial_mol; 0; 0];
inputs = struct("T_Fe_K", p.reference.T_initial_K, "a_OH", 6, ...
    "I_Fe_A", 5, "n_nodes", n_nodes);
rhs = @(t, x) local_dx(t, x, inputs, p);
options = ironair_solver_options(p.resolution, max(abs(x0), 1e-6), [], [], 1:4);
[t, x] = ode15s(rhs, [0, 600], x0, options);
[~, outputs] = ironair_metal_ode(t(end), x(end, :).', inputs, p);
results = struct("t_s", t, "x", x, "outputs", outputs, "p", p);
end

function dx = local_dx(t, x, inputs, p)
[dx, ~, ~] = ironair_metal_ode(t, x, inputs, p);
end
