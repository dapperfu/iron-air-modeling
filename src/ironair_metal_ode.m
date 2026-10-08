function [du_dt, eta, i_far] = ironair_metal_ode(u, i_app, c_OH, T, p)
%IRONAIR_METAL_ODE Metal electrode utilization ODE and overpotential.
% u in [0,1]: solid-phase reduced-iron fraction (1 = fully charged Fe).
% Discharge (i_app > 0) consumes Fe. Requirement IDs: SSS004, SDD002
C = ironair_constants();
F = C.F;
R = C.R;
u = min(max(u, 0), 1);
c_OH = max(c_OH, 1);
i0 = max(p.i0_Fe * exp(-p.E_act_Fe / R * (1 / T - 1 / p.T_ref)), 1e-6);
% Linearized exchange around equilibrium with SOC activity
i0_eff = i0 * max(sqrt(max(u * (1 - u), 1e-4)) * (c_OH / p.c_OH_ref)^0.25, 1e-3);
% Symmetrical BV Tafel-branch approx
if abs(i_app) < 1e-12
    eta = 0;
else
    eta = (R * T) / ((p.alpha_a + p.alpha_c) * 0.5 * F) * asinh(i_app / (2 * i0_eff));
end
i_far = i_app;
du_dt = -i_app / max(p.Q_max, eps);
if u <= 0 && du_dt < 0
    du_dt = 0;
elseif u >= 1 && du_dt > 0
    du_dt = 0;
end
end
