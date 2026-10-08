function du = ironair_sl_metal_dydt(u)
% u = [util; i_app; c_OH; T]
IronAir = evalin('base', 'IronAir');
[du, ~, ~] = ironair_metal_ode(u(1), u(2), u(3), u(4), IronAir.Metal);
end
