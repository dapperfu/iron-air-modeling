function results = ironair_sim_electrolyte(resolution_name)
%IRONAIR_SIM_ELECTROLYTE Standalone electrolyte inventory simulation.
arguments
    resolution_name (1, 1) string = "smoke"
end
ironair_setup();
p = ironair_configuration_profile("single_cell", resolution_name);
V = p.electrolyte.V_electrolyte_initial_m3;
x0 = [6000*V; 6000*V; 30; 0.4*V; 1e-4*V; 0; V];
inputs = struct("T_electrolyte_K", 298.15, "p_O2_Pa", 21278, ...
    "r_Fe_ox_mol_s", 1e-5);
[t, x] = ode15s(@(t, x) local_dx(t, x, inputs, p), [0, 120], x0, ...
    ironair_solver_options(p.resolution, max(abs(x0), 1e-8)));
[~, outputs] = ironair_electrolyte_ode(t(end), x(end, :).', inputs, p);
results = struct("t_s", t, "x", x, "outputs", outputs);
end

function dx = local_dx(t, x, inputs, p)
[dx, ~, ~] = ironair_electrolyte_ode(t, x, inputs, p);
end
