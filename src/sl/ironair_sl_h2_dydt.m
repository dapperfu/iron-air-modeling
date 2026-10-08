function dn = ironair_sl_h2_dydt(u)
% u = [n_cum; eta_metal; I_cell; T] -> n_dot (cumulative moles integrator)
IronAir = evalin('base', 'IronAir');
[n_dot, ~, ~, ~] = ironair_h2_evolution(u(2), u(3), u(4), IronAir.H2);
dn = n_dot;
end
