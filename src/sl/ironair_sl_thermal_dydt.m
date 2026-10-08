function dT = ironair_sl_thermal_dydt(u)
% u = [T; Q_gen]
IronAir = evalin('base', 'IronAir');
dT = ironair_thermal_ode(u(1), u(2), IronAir.Thermal);
dT = dT(1);
end
