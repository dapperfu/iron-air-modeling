function [outputs, diagnostics] = ironair_current_collector(t, inputs, p)
%IRONAIR_CURRENT_COLLECTOR Temperature-dependent collector resistance and heat.
%   [OUTPUTS, DIAGNOSTICS] = IRONAIR_CURRENT_COLLECTOR(T, INPUTS, P)
%
%   Equation: COL-001 through COL-004
%   Requirements: SRS007.

arguments
    t (1, 1) double
    inputs (1, 1) struct
    p (1, 1) struct
end

T_col = inputs.T_collector_K;
% COL-001: geometric collector resistance. Constitutive equation.
R_geometric = p.current_collectors.rho_e_ref_Ohm_m .* ...
    p.current_collectors.L_collector_m ./ p.current_collectors.A_collector_m2;
% COL-004: first-order temperature adjustment. Empirical approximation.
R_collector_T = R_geometric .* ...
    (1 + p.current_collectors.alpha_R_1_K .* (T_col - p.constants.T_ref_K));
R_collector = R_collector_T + p.current_collectors.R_contact_Ohm;
I = inputs.I_cell_A;
% COL-002
V_drop = I .* R_collector;
% COL-003
P_joule = I.^2 .* R_collector;

outputs = struct( ...
    "R_collector_Ohm", R_collector, ...
    "R_geometric_Ohm", R_geometric, ...
    "R_collector_T_Ohm", R_collector_T, ...
    "V_drop_V", V_drop, ...
    "P_joule_W", P_joule);
diagnostics = struct("t", t);
end
