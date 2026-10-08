function [outputs, diagnostics] = ironair_electrical_protection(t, inputs, p)
%IRONAIR_ELECTRICAL_PROTECTION Overcurrent, voltage window, and precharge.
%   Requirements: SRS012, SRS017.

arguments
    t (1, 1) double
    inputs (1, 1) struct
    p (1, 1) struct
end

overcurrent = abs(inputs.I_A) >= p.electrical_protection.I_trip_A;
undervoltage = inputs.V_dc_V < p.dc_bus.V_dc_min_V;
overvoltage = inputs.V_dc_V > p.dc_bus.V_dc_max_V;
trip = overcurrent || undervoltage || overvoltage;
R_path = 0;
if inputs.precharge
    R_path = p.electrical_protection.R_precharge_Ohm;
end

outputs = struct("trip", trip, "overcurrent", overcurrent, ...
    "undervoltage", undervoltage, "overvoltage", overvoltage, ...
    "R_path_Ohm", R_path, "t_reconnect_s", p.electrical_protection.t_reconnect_s);
diagnostics = struct("t", t);
end
