function [eta, i_oer] = ironair_oer_ode(i_app, T, p)
%IRONAIR_OER_ODE OER electrode overpotential (charge: i_app < 0 as current density).
% Requirement IDs: SSS006
C = ironair_constants();
F = C.F;
R = C.R;
i0 = max(p.i0_OER * exp(-p.E_act_OER / R * (1 / T - 1 / p.T_ref)), 1e-6);
i_target = abs(min(i_app, 0));
if i_app >= 0 || i_target < 1e-12
    eta = 0;
    i_oer = 0;
    return;
end
eta = (R * T) / (p.alpha_a * F) * asinh(i_target / (2 * i0));
i_oer = i_target;
end
