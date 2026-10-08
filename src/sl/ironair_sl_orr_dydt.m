function dc = ironair_sl_orr_dydt(u)
% u = [c_O2(1:Nx); i_app; T]
IronAir = evalin('base', 'IronAir');
Nx = IronAir.ORR.Nx;
[dc, ~, ~] = ironair_orr_ode(u(1:Nx), u(Nx + 1), u(Nx + 2), IronAir.ORR);
dc = dc(:);
end
