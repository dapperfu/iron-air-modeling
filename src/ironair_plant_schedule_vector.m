function y = ironair_plant_schedule_vector(u)
% u = [P_ac_ref; V_pack]
IronAir = evalin('base', 'IronAir');
[P_dc, I_pack] = ironair_plant_schedule(u(1), u(2), IronAir.Plant.eta_pcs);
y = [P_dc; I_pack];
end
