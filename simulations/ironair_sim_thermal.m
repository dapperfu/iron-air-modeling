function results = ironair_sim_thermal(resolution_name)
arguments
    resolution_name (1, 1) string = "smoke"
end
ironair_setup();
p = ironair_configuration_profile("single_cell", resolution_name);
x0 = 298.15 * ones(5, 1);
in = struct("I_cell_A", 3, "R_ohmic_Ohm", 0.02, "Q_dot_activation_W", 2, ...
    "T_ambient_K", 298.15, "cp_electrolyte_J_kgK", 4000, "Q_dot_aux_W", 40);
[t, x] = ode15s(@(t, x) local_dx(t, x, in, p), [0, 60], x0, ...
    ironair_solver_options(p.resolution, x0));
results = struct("t_s", t, "x", x);
end

function dx = local_dx(t, x, in, p)
[dx, ~, ~] = ironair_thermal_ode(t, x, in, p);
end
