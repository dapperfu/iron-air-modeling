function [n_dot_H2, V_dot_H2, eta_F, i_H2] = ironair_h2_evolution(eta_metal, I_cell, T, p)
%IRONAIR_H2_EVOLUTION Parasitic HER on metal electrode.
% Requirement IDs: SRS004, SSS007, SDD003
C = ironair_constants();
F = C.F;
R = C.R;
% Cathodic parasitic: eta_metal < 0 favors HER
eta_H2 = eta_metal; % vs HER equilibrium approx
i0 = p.i0_H2 * exp(-p.E_act_H2 / R * (1 / T - 1 / p.T_ref));
if eta_H2 < 0
    i_H2 = i0 * exp(-p.alpha_H2 * F * eta_H2 / (R * T));
else
    i_H2 = i0 * 0.01; % negligible anodic
end
i_H2 = max(i_H2, 0);
A = p.A;
n_dot_H2 = i_H2 * A / (2 * F);           % mol/s
V_dot_H2 = n_dot_H2 * R * T / C.P_atm;  % m^3/s ideal gas
eta_F = 1 - (i_H2 * A) / (abs(I_cell) + eps);
eta_F = min(max(eta_F, 0), 1);
end
