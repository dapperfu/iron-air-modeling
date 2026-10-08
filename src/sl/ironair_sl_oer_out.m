function y = ironair_sl_oer_out(u)
% Algebraic OER: u = [i_app; T] -> [eta; i_oer]
IronAir = evalin('base', 'IronAir');
[eta, i_oer] = ironair_oer_ode(u(1), u(2), IronAir.OER);
y = [eta; i_oer];
end
