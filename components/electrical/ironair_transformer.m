function [dx, outputs, diagnostics] = ironair_transformer(t, x, inputs, p)
%IRONAIR_TRANSFORMER Ideal turns ratio, losses, and thermal dynamics.
%   [DX, OUTPUTS, DIAGNOSTICS] = IRONAIR_TRANSFORMER(T, X, INPUTS, P)
%
%   State x:
%     T_transformer_K
%
%   Equation: TRF-001 through TRF-004
%   Requirements: SRS012, SRS008.

arguments
    t (1, 1) double
    x (1, 1) double
    inputs (1, 1) struct
    p (1, 1) struct
end

T_transformer = x(1);
if T_transformer <= 0
    error("ironair:transformer:InvalidTemperature", ...
        "Transformer temperature must be absolute.");
end
V_primary = inputs.V_primary_V;
% TRF-001: algebraic turns-ratio relationship.
V_secondary = V_primary .* p.transformer.N_secondary ./ p.transformer.N_primary;
turns_residual = V_primary ./ max(V_secondary, realmin) - ...
    p.transformer.N_primary ./ p.transformer.N_secondary;
I_secondary = inputs.I_secondary_A;
I_primary = I_secondary .* p.transformer.N_secondary ./ p.transformer.N_primary;
% TRF-002
P_copper = I_primary.^2 .* p.transformer.R_primary_Ohm + ...
    I_secondary.^2 .* p.transformer.R_secondary_Ohm;
% TRF-003
P_core = p.transformer.k_Steinmetz .* ...
    inputs.f_transformer_Hz.^p.transformer.alpha_Steinmetz .* ...
    inputs.B_peak_T.^p.transformer.beta_Steinmetz .* ...
    p.transformer.V_core_m3;
% TRF-004
dT_transformer_dt = (P_core + P_copper - ...
    (T_transformer - inputs.T_ambient_K) ./ p.transformer.R_thermal_K_W) ./ ...
    p.transformer.C_thermal_J_K;
dx = dT_transformer_dt;
outputs = struct( ...
    "V_secondary_V", V_secondary, ...
    "I_primary_A", I_primary, ...
    "turns_residual", turns_residual, ...
    "P_copper_W", P_copper, ...
    "P_core_W", P_core, ...
    "dT_transformer_dt", dT_transformer_dt);
diagnostics = struct("t", t);
end
