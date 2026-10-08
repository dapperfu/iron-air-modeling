function eta = ironair_sl_orr_eta(u)
% u = [c_O2(1:Nx); i_app; T]
IronAir = evalin('base', 'IronAir');
Nx = IronAir.ORR.Nx;
[~, eta, ~] = ironair_orr_ode(u(1:Nx), u(Nx + 1), u(Nx + 2), IronAir.ORR);
end
