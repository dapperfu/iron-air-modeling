function results = ironair_sim_collector(resolution_name)
%IRONAIR_SIM_COLLECTOR Algebraic current-collector loss evaluation.
arguments
    resolution_name (1, 1) string = "smoke"
end
ironair_setup();
p = ironair_configuration_profile("single_cell", resolution_name);
I = linspace(-10, 10, 21);
P = zeros(size(I));
for k = 1:numel(I)
    out = ironair_current_collector(0, struct("T_collector_K", 298.15, ...
        "I_cell_A", I(k)), p);
    P(k) = out.P_joule_W;
end
results = struct("I_cell_A", I, "P_joule_W", P, "p", p);
end
