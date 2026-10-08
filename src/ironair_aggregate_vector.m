function y = ironair_aggregate_vector(u, nSeries, nParallel)
% Vectorized aggregate for Interpreted MATLAB Function blocks.
% u = [V; I; SOC; T; H2rate; H2vol; etaF]
cellOut.Voltage_V = u(1);
cellOut.Current_A = u(2);
cellOut.SOC = u(3);
cellOut.Temperature_K = u(4);
cellOut.H2_Rate_mol_s = u(5);
cellOut.H2_Volume_m3 = u(6);
cellOut.FaradaicEfficiency = u(7);
pack = ironair_aggregate(cellOut, nSeries, nParallel);
y = [pack.Voltage_V; pack.Current_A; pack.SOC; pack.Temperature_K; ...
    pack.H2_Rate_mol_s; pack.H2_Volume_m3; pack.FaradaicEfficiency; pack.Power_W];
end
