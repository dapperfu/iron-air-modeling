function mon = ironair_der_ride_through(V_pu, f_Hz, p)
%IRONAIR_DER_RIDE_THROUGH IEEE 1547-2018 / UL 1741 style envelopes.
% Requirement IDs: SRS011, SRS013, SSS012
mon.V_pass = (V_pu >= p.V_min_pu) && (V_pu <= p.V_max_pu);
mon.f_pass = (f_Hz >= p.f_min_Hz) && (f_Hz <= p.f_max_Hz);
mon.Pass = mon.V_pass && mon.f_pass;
mon.V_violation = double(~mon.V_pass);
mon.f_violation = double(~mon.f_pass);
end
