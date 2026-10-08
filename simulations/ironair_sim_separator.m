function results = ironair_sim_separator(resolution_name)
%IRONAIR_SIM_SEPARATOR Algebraic separator evaluation at two temperatures.
arguments
    resolution_name (1, 1) string = "smoke"
end
ironair_setup();
p = ironair_configuration_profile("single_cell", resolution_name);
inputs = struct("kappa_KOH_S_m", 25, "T_left_K", 310, "T_right_K", 298.15, ...
    "c_left_mol_m3", 6100, "c_right_mol_m3", 5900);
[outputs, diagnostics] = ironair_separator_model(0, inputs, p);
results = struct("outputs", outputs, "diagnostics", diagnostics, "p", p);
end
