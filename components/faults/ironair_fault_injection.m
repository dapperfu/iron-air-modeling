function [dx, outputs, diagnostics] = ironair_fault_injection(t, x, inputs, p)
%IRONAIR_FAULT_INJECTION Sensors, leakage, fan failure, and cell short.
%   [DX, OUTPUTS, DIAGNOSTICS] = IRONAIR_FAULT_INJECTION(T, X, INPUTS, P)
%
%   State x:
%     y_sensor, bias_sensor
%
%   Equation: FLT-001 through FLT-006
%   Requirements: SRS017, SRS014.

arguments
    t (1, 1) double
    x (2, 1) double
    inputs (1, 1) struct
    p (1, 1) struct
end

y_sensor = x(1);
bias_sensor = x(2);
fault_name = "none";
if isfield(inputs, "fault_name")
    fault_name = string(inputs.fault_name);
end
sensor_noise = 0;
if isfield(inputs, "sensor_noise")
    sensor_noise = inputs.sensor_noise;
end
if fault_name == "sensor_bias"
    sensor_noise = sensor_noise + p.sensors.sigma_voltage_V;
end
y_true = inputs.y_true;
% FLT-001
y_measured = y_true + bias_sensor + sensor_noise;
% FLT-002
dy_sensor_dt = (y_true - y_sensor) ./ max(p.sensors.tau_sensor_s, 1e-6);
% FLT-003
dbias_sensor_dt = p.sensors.k_sensor_drift_unit_s;

Q_in = inputs.Q_electrolyte_in_m3_s;
Q_out = inputs.Q_electrolyte_out_m3_s;
Q_leak = 0;
if fault_name == "leak"
    Q_leak = max(p.electrolyte_circulation.Q_nominal_m3_s, 1e-6);
end
if isfield(inputs, "Q_leak_m3_s")
    Q_leak = inputs.Q_leak_m3_s;
end
% FLT-004
dV_electrolyte_dt = Q_in - Q_out - Q_leak;

N_fan = inputs.N_fan;
N_command = inputs.N_fan_command;
N_effective_command = N_command;
if fault_name == "fan_failed"
    N_effective_command = 0;
end
% FLT-005
dN_fan_dt = (N_effective_command - N_fan) ./ p.fans.tau_fan_s;

I_short = 0;
V_fault = inputs.V_cell_V;
if fault_name == "short"
    R_int = max(inputs.R_ohmic_Ohm, 1e-8);
    R_fault = p.fault_detection.R_short_fault_Ohm;
    e_oc = inputs.e_oc_V;
    I_external = inputs.I_external_A;
    V_fault = (e_oc - I_external .* R_int) ./ (1 + R_int ./ R_fault);
    % FLT-006: short current consistent with the internal resistance.
    I_short = V_fault ./ R_fault;
end

dx = [dy_sensor_dt; dbias_sensor_dt];
outputs = struct( ...
    "y_measured", y_measured, ...
    "dy_sensor_dt", dy_sensor_dt, ...
    "dbias_sensor_dt", dbias_sensor_dt, ...
    "dV_electrolyte_dt", dV_electrolyte_dt, ...
    "Q_leak_m3_s", Q_leak, ...
    "dN_fan_dt", dN_fan_dt, ...
    "N_effective_command", N_effective_command, ...
    "I_short_A", I_short, ...
    "V_fault_V", V_fault);
diagnostics = struct("t", t, "fault_name", fault_name);
end
