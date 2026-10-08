function dT_dt = ironair_thermal_ode(T, Q_gen, p)
%IRONAIR_THERMAL_ODE Lumped / 1D thermal node ODE.
% Q_gen [W]; Requirement IDs: SSS008
if isfield(p, 'Nx') && p.Nx > 1 && numel(T) == p.Nx
    Nx = p.Nx;
    dx = p.L / max(Nx - 1, 1);
    alpha = p.k_th / max(p.rho * p.cp, eps);
    dT_dt = zeros(Nx, 1);
    qv = Q_gen / max(p.rho * p.cp * p.Vol, eps);
    for k = 2:Nx-1
        dT_dt(k) = alpha * (T(k+1) - 2 * T(k) + T(k-1)) / dx^2 + qv / Nx;
    end
    dT_dt(1) = alpha * (T(2) - T(1)) / dx^2 - p.h_conv * (T(1) - p.T_amb) / ...
        max(p.rho * p.cp * dx, eps) + qv / Nx;
    dT_dt(Nx) = alpha * (T(Nx-1) - T(Nx)) / dx^2 + qv / Nx;
else
    dT_dt = (Q_gen - p.h_conv * p.A_surf * (T(1) - p.T_amb)) / max(p.m_th * p.cp, eps);
end
end
