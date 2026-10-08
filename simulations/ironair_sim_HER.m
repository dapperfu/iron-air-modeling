function results = ironair_sim_HER(resolution_name)
%IRONAIR_SIM_HER Standalone hydrogen-evolution inventory simulation.
arguments
    resolution_name (1, 1) string = "smoke"
end
ironair_setup();
p = ironair_configuration_profile("single_cell", resolution_name);
x0 = 0;
inputs = struct("T_Fe_K", 298.15, "A_active_Fe_m2", 2, "phi_s_Fe_V", -1.05, ...
    "I_Fe_A", -4, "a_H2O", 0.6);
[t, x] = ode15s(@(t, x) local_dx(t, x, inputs, p), [0, 60], x0, ...
    ironair_solver_options(p.resolution, 1));
[~, outputs] = ironair_HER_model(t(end), x(end).', inputs, p);
results = struct("t_s", t, "x", x, "outputs", outputs);
end

function dx = local_dx(t, x, inputs, p)
[dx, ~, ~] = ironair_HER_model(t, x, inputs, p);
end
