function dc = ironair_sl_electrolyte_dydt(u)
%IRONAIR_SL_ELECTROLYTE_DYDT First-order RHS for Electrolyte_1D Integrator.
% u = [c_OH(1:Nx); i_app; T]
IronAir = evalin('base', 'IronAir');
Nx = IronAir.Electrolyte.Nx;
c = u(1:Nx);
i_app = u(Nx + 1);
T = u(Nx + 2);
p = IronAir.Electrolyte;
p.T = T;
dc = ironair_electrolyte_ode(c, i_app, p);
dc = dc(:);
end
