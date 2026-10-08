function [dcO2_dt, eta, i_orr] = ironair_orr_ode(cO2, i_app, T, p)
%IRONAIR_ORR_ODE 1D O2 concentration in ORR electrode + kinetics.
% Discharge i_app > 0 consumes O2. Requirement IDs: SSS005
C = ironair_constants();
F = C.F;
R = C.R;
Nx = p.Nx;
dx = p.L / max(Nx - 1, 1);
D = p.D_O2;
cO2 = max(cO2(:), 0);
c_mean = max(mean(cO2), 1e-6);
i0 = max(p.i0_ORR * exp(-p.E_act_ORR / R * (1 / T - 1 / p.T_ref)), 1e-6);
% Cathodic Tafel inversion: i_app = i0*(c/c_ref)*exp(-alpha*F*eta/(R*T)), eta <= 0
arg = max(abs(i_app), 1e-9) / (i0 * (c_mean / p.c_O2_ref));
eta = -(R * T) / (p.alpha_c * F) * log(arg);
i_orr = -abs(i_app);

dcO2_dt = zeros(Nx, 1);
sink = (p.a_v * abs(i_app)) / (4 * F);
if Nx == 1
    dcO2_dt(1) = -sink + p.k_gas * (p.c_O2_amb - cO2(1));
    return;
end
for k = 2:Nx-1
    dcO2_dt(k) = D * (cO2(k+1) - 2 * cO2(k) + cO2(k-1)) / dx^2 - sink / Nx;
end
dcO2_dt(1) = D * (cO2(2) - cO2(1)) / dx^2 + p.k_gas * (p.c_O2_amb - cO2(1)) - sink / Nx;
dcO2_dt(Nx) = D * (cO2(Nx-1) - cO2(Nx)) / dx^2 - sink / Nx;
end
