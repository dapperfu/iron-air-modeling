function y = ironair_sl_metal_out(u)
% u = [util; i_app; c_OH; T] -> [util; eta; i_far]
IronAir = evalin('base', 'IronAir');
[~, eta, i_far] = ironair_metal_ode(u(1), u(2), u(3), u(4), IronAir.Metal);
y = [u(1); eta; i_far];
end
