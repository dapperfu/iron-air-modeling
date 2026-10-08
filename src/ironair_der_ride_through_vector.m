function y = ironair_der_ride_through_vector(u)
% u = [V_pu; f_Hz]
IronAir = evalin('base', 'IronAir');
mon = ironair_der_ride_through(u(1), u(2), IronAir.Standards);
y = [double(mon.Pass); mon.V_violation; mon.f_violation];
end
