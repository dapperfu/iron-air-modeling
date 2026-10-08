function y = ironair_sl_h2_out(u)
% u = [n_cum; eta_metal; I_cell; T] -> [n_dot; V_H2; eta_F; i_H2]
IronAir = evalin('base', 'IronAir');
C = ironair_constants();
[n_dot, ~, eta_F, i_H2] = ironair_h2_evolution(u(2), u(3), u(4), IronAir.H2);
V_H2 = u(1) * C.R * u(4) / C.P_atm;
y = [n_dot; V_H2; eta_F; i_H2];
end
