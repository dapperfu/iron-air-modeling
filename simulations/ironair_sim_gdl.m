function results = ironair_sim_gdl(resolution_name)
%IRONAIR_SIM_GDL Standalone gas-diffusion-layer oxygen transient.
arguments
    resolution_name (1, 1) string = "smoke"
end
ironair_setup();
p = ironair_configuration_profile("single_cell", resolution_name);
n_cv = p.resolution.oxygen_control_volumes;
c_gas = 8.5;
x0 = [c_gas * ones(n_cv, 1); 0.1];
inputs = struct("T_air_K", 298.15, "p_gas_Pa", 101325, "p_liquid_Pa", 101325, ...
    "c_O2_gas_mol_m3", c_gas, "n_dot_O2_consumed_mol_s", 2e-6);
[t, x] = ode15s(@(t, x) local_dx(t, x, inputs, p), [0, 30], x0, ...
    ironair_solver_options(p.resolution, max(abs(x0), 1e-6)));
[~, outputs] = ironair_gas_diffusion_layer(t(end), x(end, :).', inputs, p);
results = struct("t_s", t, "x", x, "outputs", outputs);
end

function dx = local_dx(t, x, inputs, p)
[dx, ~, ~] = ironair_gas_diffusion_layer(t, x, inputs, p);
end
