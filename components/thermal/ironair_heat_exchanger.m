function [outputs, diagnostics] = ironair_heat_exchanger(t, inputs, p)
%IRONAIR_HEAT_EXCHANGER Effectiveness-NTU heat exchanger with stable LMTD.
%   [OUTPUTS, DIAGNOSTICS] = IRONAIR_HEAT_EXCHANGER(T, INPUTS, P)
%   treats the cell as an isothermal hot stream.
%
%   Equation: HEX-001 through HEX-004
%   Requirements: SRS008, SRS010.

arguments
    t (1, 1) double
    inputs (1, 1) struct
    p (1, 1) struct
end

T_hot = inputs.T_hot_K;
T_cold_in = inputs.T_cold_in_K;
C_min = p.heat_exchanger.m_dot_coolant_kg_s .* p.heat_exchanger.cp_coolant_J_kgK;
if C_min <= 0 || T_hot <= T_cold_in
    outputs = idle_outputs(T_cold_in);
    diagnostics = struct("t", t, "active", false);
    return;
end

% HEX-004: number of transfer units. Constitutive equation.
NTU_HX = p.heat_exchanger.U_HX_W_m2K .* p.heat_exchanger.A_HX_m2 ./ C_min;
epsilon_isothermal = 1 - exp(-NTU_HX);
Q_dot_NTU = epsilon_isothermal .* C_min .* (T_hot - T_cold_in);
T_cold_out = T_cold_in + Q_dot_NTU ./ C_min;
delta_T_1 = T_hot - T_cold_out;
delta_T_2 = T_hot - T_cold_in;
% HEX-002
[delta_T_lm, used_limit] = ironair_log_mean_delta_T(delta_T_1, delta_T_2);
% HEX-001: heat rate from the overall coefficient. Constitutive equation.
Q_dot_HX = p.heat_exchanger.U_HX_W_m2K .* p.heat_exchanger.A_HX_m2 .* delta_T_lm;
% HEX-003: effectiveness. Constitutive equation.
epsilon_HX = Q_dot_HX ./ (C_min .* (T_hot - T_cold_in));

outputs = struct( ...
    "Q_dot_HX_W", Q_dot_HX, ...
    "delta_T_lm_K", delta_T_lm, ...
    "epsilon_HX", epsilon_HX, ...
    "NTU_HX", NTU_HX, ...
    "T_cold_out_K", T_cold_out, ...
    "C_min_W_K", C_min);
diagnostics = struct("t", t, "active", true, "lmtd_limit", used_limit);
end

function outputs = idle_outputs(T_cold_in)
outputs = struct( ...
    "Q_dot_HX_W", 0, ...
    "delta_T_lm_K", 0, ...
    "epsilon_HX", 0, ...
    "NTU_HX", 0, ...
    "T_cold_out_K", T_cold_in, ...
    "C_min_W_K", 0);
end
