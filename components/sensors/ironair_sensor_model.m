function [dx, outputs, diagnostics] = ironair_sensor_model(t, x, inputs, p)
%IRONAIR_SENSOR_MODEL First-order sensors with bias, noise, and drift.
%   State x: y_sensor, bias_sensor for each channel packed as pairs.
%   Equation: FLT-001 through FLT-003
%   Requirements: SRS017.

arguments
    t (1, 1) double
    x (:, 1) double
    inputs (1, 1) struct
    p (1, 1) struct
end

y_true = inputs.y_true(:);
n = numel(y_true);
if numel(x) ~= 2 * n
    error("ironair:sensor:StateSize", "Sensor state must contain value and bias per channel.");
end
y_sensor = x(1:n);
bias = x(n+1:end);
if inputs.sensor_failed
    noise = 0;
    y_meas = y_sensor;
    dy = zeros(n, 1);
else
    rng_state = rng;
    rng(mod(floor(t * 10) + 17, 2^31 - 1));
    noise = inputs.sigma(:) .* randn(n, 1);
    rng(rng_state);
    dy = (y_true - y_sensor) ./ p.sensors.tau_sensor_s;
    y_meas = y_sensor + bias + noise;
end
dbias = p.sensors.k_sensor_drift_unit_s * ones(n, 1);
if inputs.sensor_bias
    dbias = dbias + 1e-4;
end

dx = [dy; dbias];
outputs = struct("y_measured", y_meas, "y_sensor", y_sensor, "bias", bias);
diagnostics = struct("t", t);
end
