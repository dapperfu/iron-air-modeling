function [dx, outputs, diagnostics] = ironair_der_ride_through(t, x, inputs, p)
%IRONAIR_DER_RIDE_THROUGH Time-qualified voltage and frequency envelopes.
%   [DX, OUTPUTS, DIAGNOSTICS] = IRONAIR_DER_RIDE_THROUGH(T, X, INPUTS, P)
%   integrates a violation timer while a qualifying excursion is active and
%   recovers the timer when the grid returns inside the envelope. The
%   characteristic is an illustrative ASSUMED profile, not a grid-code
%   certification.
%
%   State x:
%     t_violation_s
%
%   Equation: GRID-006
%   Requirements: SRS013, SRS014.

arguments
    t (1, 1) double
    x (:, 1) double
    inputs (1, 1) struct
    p (1, 1) struct
end

if isfield(inputs, "f_grid_Hz") && ~isfield(inputs, "delta_f_grid_Hz")
    inputs.delta_f_grid_Hz = inputs.f_grid_Hz - p.grid.f_nominal_Hz;
end
V_pu = inputs.V_grid_pu;
delta_f = inputs.delta_f_grid_Hz;
voltage_violation = V_pu < p.grid.V_low_pu || V_pu > p.grid.V_high_pu;
frequency_violation = abs(delta_f) > p.grid.f_trip_deviation_Hz;
qualifying = voltage_violation || frequency_violation;
t_limit = p.grid.t_voltage_trip_s;
if frequency_violation && ~voltage_violation
    t_limit = p.grid.t_frequency_trip_s;
end
% GRID-006: advance during a qualifying violation, otherwise recover.
if qualifying
    dt_violation_dt = 1;
else
    dt_violation_dt = -x(1) ./ max(p.grid.t_voltage_trip_s, 1e-6);
end
trip_command = qualifying && x(1) >= t_limit;

dx = dt_violation_dt;
outputs = struct( ...
    "dt_violation_dt", dt_violation_dt, ...
    "t_violation_s", x(1), ...
    "qualifying_violation", qualifying, ...
    "trip_command", trip_command, ...
    "t_trip_configured_s", t_limit, ...
    "certification_claim", false);
diagnostics = struct("t", t, "voltage_violation", voltage_violation, ...
    "frequency_violation", frequency_violation, ...
    "assumed_table", true, ...
    "certification_claim", "illustrative ASSUMED ride-through, not a certification result");
end
