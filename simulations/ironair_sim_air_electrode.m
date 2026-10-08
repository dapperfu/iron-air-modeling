function results = ironair_sim_air_electrode(resolution_name)
%IRONAIR_SIM_AIR_ELECTRODE Standalone ORR/OER air-electrode simulation.
arguments
    resolution_name (1, 1) string = "smoke"
end
ironair_setup();
p = ironair_configuration_profile("single_cell", resolution_name);
x0 = [0.1; 1; 1];
inputs = struct("T_air_K", 298.15, "a_OH", 6, "a_H2O", 0.7, "a_O2", 0.21, ...
    "c_KOH_mol_m3", 6000, "c_O2_bulk_mol_m3", 0.4, "eta_air_V", -0.15);
[t, x] = ode15s(@(t, x) local_dx(t, x, inputs, p), [0, 60], x0, ...
    ironair_solver_options(p.resolution, max(abs(x0), 1e-3)));
[~, outputs] = ironair_air_electrode_ode(t(end), x(end, :).', inputs, p);
results = struct("t_s", t, "x", x, "outputs", outputs);
end

function dx = local_dx(t, x, inputs, p)
[dx, ~, ~] = ironair_air_electrode_ode(t, x, inputs, p);
end
