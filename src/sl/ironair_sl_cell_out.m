function z = ironair_sl_cell_out(u)
% u = [y_state(1:2*Nx+3); I_cell] -> IRS001 bus as 7-vector
IronAir = evalin('base', 'IronAir');
Nx = IronAir.Electrolyte.Nx;
n = 2 * Nx + 3;
out = ironair_cell_outputs(u(1:n), u(n + 1), IronAir.CellBundle);
z = [out.Voltage_V; out.Current_A; out.SOC; out.Temperature_K; ...
    out.H2_Rate_mol_s; out.H2_Volume_m3; out.FaradaicEfficiency];
end
