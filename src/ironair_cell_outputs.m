function out = ironair_cell_outputs(y, I_cell, p)
%IRONAIR_CELL_OUTPUTS Map cell state to IRS001 bus fields.
Nx = p.Electrolyte.Nx;
u = y(2*Nx+1);
T = y(2*Nx+2);
n_H2 = y(2*Nx+3);
i_app = I_cell / max(p.A, eps);
c_OH_m = mean(y(1:Nx));
[~, eta_m] = ironair_metal_ode(u, i_app, c_OH_m, T, p.Metal);
if I_cell >= 0
    [~, eta_air] = ironair_orr_ode(y(Nx+1:2*Nx), i_app, T, p.ORR);
else
    [eta_air, ~] = ironair_oer_ode(i_app, T, p.OER);
end
kappa = p.Electrolyte.kappa0 * (c_OH_m / p.Electrolyte.c0);
R_elec = p.Electrolyte.L / max(kappa * p.A, eps);
V = p.Metal.E0_cell - abs(eta_m) - abs(eta_air) - I_cell * R_elec;
[n_dot_H2, V_dot_H2, eta_F] = ironair_h2_evolution(eta_m, I_cell, T, p.H2);
C = ironair_constants();
V_H2 = n_H2 * C.R * T / C.P_atm;

out.Voltage_V = V;
out.Current_A = I_cell;
out.SOC = min(max(u, 0), 1);
out.Temperature_K = T;
out.H2_Rate_mol_s = n_dot_H2;
out.H2_Volume_m3 = V_H2;
out.FaradaicEfficiency = eta_F;
out.H2_VolumeRate_m3_s = V_dot_H2;
end
