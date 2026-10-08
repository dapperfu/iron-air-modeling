function dc_dt = ironair_electrolyte_ode(c, i_app, p)
%IRONAIR_ELECTROLYTE_ODE 1D KOH concentration ODE (Fick + migration approx).
% c [mol/m^3] length Nx; i_app [A/m^2] applied current density (discharge > 0).
% Requirement IDs: SSS003, SDD001
Nx = p.Nx;
dx = p.L / max(Nx - 1, 1);
D = p.D_OH * exp(-p.E_act_D / p.R * (1 / p.T - 1 / p.T_ref));
t_plus = p.t_plus;
F = p.F;
nu = (1 - t_plus) / F; % migration source scaling for OH-

dc_dt = zeros(Nx, 1);
if Nx == 1
    % Lumped volume with Faradaic source at boundaries represented as volumetric
    dc_dt(1) = (p.a_v * nu * i_app) / max(p.eps_elyte, eps);
    return;
end

% Diffusion (Neumann zero-flux ends) + volumetric Faradaic coupling at ends
for k = 2:Nx-1
    dc_dt(k) = D * (c(k+1) - 2 * c(k) + c(k-1)) / dx^2;
end
dc_dt(1) = D * (c(2) - c(1)) / dx^2 + (p.a_v * nu * i_app) / max(p.eps_elyte, eps);
dc_dt(Nx) = D * (c(Nx-1) - c(Nx)) / dx^2 - (p.a_v * nu * i_app) / max(p.eps_elyte, eps);
end
