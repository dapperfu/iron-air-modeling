function [dx, outputs, diagnostics] = ironair_inverter(t, x, inputs, p)
%IRONAIR_INVERTER Three-phase power, losses, and PI power control.
%   [DX, OUTPUTS, DIAGNOSTICS] = IRONAIR_INVERTER(T, X, INPUTS, P)
%
%   State x:
%     integral_e_P, integral_e_Q
%
%   Equation: INV-001 through INV-007
%   Requirements: SRS012, SRS013, SRS014.

arguments
    t (1, 1) double
    x (2, 1) double
    inputs (1, 1) struct
    p (1, 1) struct
end

integral_e_P = x(1);
integral_e_Q = x(2);
V_LL = inputs.V_LL_V;
I_line = inputs.I_line_A;
phi_power = inputs.phi_power_rad;
% INV-001, INV-002, INV-003
P_AC = sqrt(3) .* V_LL .* I_line .* cos(phi_power);
Q_AC = sqrt(3) .* V_LL .* I_line .* sin(phi_power);
S_AC = sqrt(P_AC.^2 + Q_AC.^2);
% INV-007: scale active and reactive power back inside the apparent-power circle.
if S_AC > p.inverter.S_rated_VA && S_AC > 0
    scale = p.inverter.S_rated_VA ./ S_AC;
    P_AC = P_AC .* scale;
    Q_AC = Q_AC .* scale;
    S_AC = p.inverter.S_rated_VA;
end
apparent_within_limit = S_AC.^2 <= p.inverter.S_rated_VA.^2 + 1e-6;

P_inverter_loss = (1 - p.inverter.eta_nominal) .* abs(P_AC);
dE_inverter_dt = 0;
% INV-004
P_DC = P_AC + P_inverter_loss + dE_inverter_dt;

% INV-005
e_P = inputs.P_ref_W - P_AC;
[u_P, dintegral_e_P_dt] = ironair_pi_antiwindup(e_P, integral_e_P, ...
    p.inverter.Kp_P, p.inverter.Ki_P_1_Ws, -p.inverter.S_rated_VA, p.inverter.S_rated_VA);
% INV-006
e_Q = inputs.Q_ref_var - Q_AC;
[u_Q, dintegral_e_Q_dt] = ironair_pi_antiwindup(e_Q, integral_e_Q, ...
    p.inverter.Kp_Q, p.inverter.Ki_Q_1_vars, -p.inverter.S_rated_VA, p.inverter.S_rated_VA);

P_out_positive = max(P_AC, 0);
P_in_positive = max(P_DC, 0);
if P_in_positive > 1e-9
    eta_inverter = P_out_positive ./ P_in_positive;
else
    eta_inverter = p.inverter.eta_nominal;
end

dx = [dintegral_e_P_dt; dintegral_e_Q_dt];
outputs = struct( ...
    "P_AC_W", P_AC, ...
    "Q_AC_var", Q_AC, ...
    "S_AC_VA", S_AC, ...
    "P_DC_W", P_DC, ...
    "e_P_W", e_P, ...
    "e_Q_var", e_Q, ...
    "u_P", u_P, ...
    "u_Q", u_Q, ...
    "dintegral_e_P_dt", dintegral_e_P_dt, ...
    "dintegral_e_Q_dt", dintegral_e_Q_dt, ...
    "apparent_within_limit", apparent_within_limit, ...
    "eta_inverter", eta_inverter);
diagnostics = struct("t", t);
end
