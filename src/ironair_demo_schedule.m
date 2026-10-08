function P_ac = ironair_demo_schedule(t)
%IRONAIR_DEMO_SCHEDULE 24-100 h energy arbitrage power profile [W].
% Discharge daytime (positive), charge nighttime (negative).
IronAir = evalin('base', 'IronAir');
Pnom = IronAir.Plant.P_nom_W;
t_h = mod(t / 3600, 24);
if t_h >= 8 && t_h < 20
    P_ac = Pnom;          % discharge
else
    P_ac = -0.8 * Pnom;   % charge
end
end
