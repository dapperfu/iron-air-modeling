function [dx, outputs, diagnostics] = ironair_enclosure_model(t, x, inputs, p)
%IRONAIR_ENCLOSURE_MODEL Enclosure air thermal balance.
%   [DX, OUTPUTS, DIAGNOSTICS] = IRONAIR_ENCLOSURE_MODEL(T, X, INPUTS, P)
%
%   State x:
%     T_enclosure_K
%
%   Equation: MOD-003
%   Requirements: SRS011, SRS008.

arguments
    t (1, 1) double
    x (1, 1) double
    inputs (1, 1) struct
    p (1, 1) struct
end

T_enclosure = x(1);
if T_enclosure <= 0
    error("ironair:enclosure:InvalidTemperature", ...
        "Enclosure temperature must be absolute.");
end
Q_dot_internal = inputs.Q_dot_internal_W;
Q_dot_HVAC = inputs.Q_dot_HVAC_W;
Q_dot_ambient = p.enclosure.UA_ambient_W_K .* (T_enclosure - inputs.T_ambient_K);
% MOD-003: enclosure thermal balance. Conservation law.
dT_enclosure_dt = (Q_dot_internal - Q_dot_HVAC - Q_dot_ambient) ./ ...
    p.enclosure.C_enclosure_J_K;
dx = dT_enclosure_dt;
outputs = struct( ...
    "T_enclosure_K", T_enclosure, ...
    "dT_enclosure_dt", dT_enclosure_dt, ...
    "Q_dot_ambient_W", Q_dot_ambient, ...
    "Q_dot_HVAC_W", Q_dot_HVAC);
diagnostics = struct("t", t);
end
