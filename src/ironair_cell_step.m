function [yp, y] = ironair_cell_step(t, y, I_cell, p) %#ok<INUSD>
%IRONAIR_CELL_STEP Continuous RHS for full cell state vector.
% State y = [c_OH(1:Nx); c_O2(1:Nx); u; T; n_H2_cum]
% Requirement IDs: SSS009, SDD002
Nx = p.Electrolyte.Nx;
c_OH = y(1:Nx);
c_O2 = y(Nx+1:2*Nx);
u = y(2*Nx+1);
T = y(2*Nx+2);
% Current density
i_app = I_cell / max(p.A, eps);
c_OH_m = mean(c_OH);

[du_dt, eta_m, ~] = ironair_metal_ode(u, i_app, c_OH_m, T, p.Metal);
% NaN eta marks infeasible Fe current (not a physical overpotential)
if ~isfinite(eta_m)
    eta_m = 0;
end
dc_OH = ironair_electrolyte_ode(c_OH, i_app, p.Electrolyte);
dc_OH = dc_OH(:);
if I_cell >= 0
    [dc_O2, eta_orr, ~] = ironair_orr_ode(c_O2, i_app, T, p.ORR);
    eta_air = abs(eta_orr);
    [~, ~] = ironair_oer_ode(i_app, T, p.OER); %#ok<ASGLU>
else
    dc_O2 = zeros(Nx, 1);
    [eta_oer, ~] = ironair_oer_ode(i_app, T, p.OER);
    eta_air = abs(eta_oer);
end

dc_O2 = dc_O2(:);

% Ohmic
kappa = p.Electrolyte.kappa0 * (mean(c_OH) / p.Electrolyte.c0);
R_elec = p.Electrolyte.L / max(kappa * p.A, eps);
E_eq = p.Metal.E0_cell;
V = E_eq - eta_m - eta_air - I_cell * R_elec;

[n_dot_H2, ~, eta_F, i_H2] = ironair_h2_evolution(eta_m, I_cell, T, p.H2);
Q_gen = abs(I_cell * (eta_m + eta_air + I_cell * R_elec)) + ...
    abs(i_H2 * p.A * 0.1); % small HER heat
dT = ironair_thermal_ode(T, Q_gen, p.Thermal);

yp = [dc_OH; dc_O2; du_dt; dT(1); n_dot_H2];
% pack outputs into persistent-friendly struct via second output as vector extras
% y_out encoded: V, SOC(=u), eta_F, n_dot_H2 (callers use ironair_cell_outputs)
y = [V; u; eta_F; n_dot_H2; T]; %#ok<NASGU>
end
