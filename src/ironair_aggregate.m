function pack = ironair_aggregate(cellOut, nSeries, nParallel)
%IRONAIR_AGGREGATE Series/parallel scaling for Stack/Module/Pack.
% Requirement IDs: SSS010, IRS002
pack.Voltage_V = cellOut.Voltage_V * nSeries;
pack.Current_A = cellOut.Current_A * nParallel;
pack.SOC = cellOut.SOC;
pack.Temperature_K = cellOut.Temperature_K;
pack.H2_Rate_mol_s = cellOut.H2_Rate_mol_s * nSeries * nParallel;
pack.H2_Volume_m3 = cellOut.H2_Volume_m3 * nSeries * nParallel;
pack.FaradaicEfficiency = cellOut.FaradaicEfficiency;
pack.Energy_Wh = pack.Voltage_V * pack.Current_A / 3600; % instantaneous power as Wh/s proxy
pack.Power_W = pack.Voltage_V * pack.Current_A;
end
