function [outputs, diagnostics] = ironair_separator_model(t, inputs, p)
%IRONAIR_SEPARATOR_MODEL Algebraic ionic, crossover, and thermal separator.
%   [OUTPUTS, DIAGNOSTICS] = IRONAIR_SEPARATOR_MODEL(T, INPUTS, P)
%
%   Equation: SEP-001 through SEP-004
%   Requirements: SRS006.

arguments
    t (1, 1) double
    inputs (1, 1) struct
    p (1, 1) struct
end

kappa = inputs.kappa_KOH_S_m;
% SEP-002
kappa_eff = kappa .* p.separator.epsilon_separator ./ p.separator.tau_separator;
% SEP-001
R_separator = p.separator.L_separator_m ./ ...
    (kappa_eff .* p.separator.A_separator_m2);
c_side1 = 0;
c_side2 = 0;
if isfield(inputs, "c_left_mol_m3") && isfield(inputs, "c_right_mol_m3")
    c_side1 = inputs.c_left_mol_m3;
    c_side2 = inputs.c_right_mol_m3;
end
% SEP-003: diffusion plus migration when a potential difference is supplied.
D_sep = p.separator.D_crossover_m2_s;
J_i_separator = -D_sep .* (c_side2 - c_side1) ./ p.separator.L_separator_m;
if isfield(inputs, "phi_side1_V") && isfield(inputs, "phi_side2_V")
    z_i = -1;
    if isfield(inputs, "z_i")
        z_i = inputs.z_i;
    end
    T_mean = 0.5 .* (inputs.T_left_K + inputs.T_right_K);
    c_avg = 0.5 .* (c_side1 + c_side2);
    J_i_separator = J_i_separator - z_i .* D_sep .* p.constants.F_C_mol ./ ...
        (p.constants.R_J_molK .* T_mean) .* c_avg .* ...
        (inputs.phi_side2_V - inputs.phi_side1_V) ./ p.separator.L_separator_m;
end
N_crossover = J_i_separator;
T_left = inputs.T_left_K;
T_right = inputs.T_right_K;
% SEP-004
Q_dot_separator = p.separator.k_separator_W_mK .* p.separator.A_separator_m2 ./ ...
    p.separator.L_separator_m .* (T_left - T_right);

outputs = struct( ...
    "kappa_eff_S_m", kappa_eff, ...
    "R_separator_Ohm", R_separator, ...
    "J_i_separator_mol_m2s", J_i_separator, ...
    "N_crossover_mol_m2s", N_crossover, ...
    "Q_dot_separator_W", Q_dot_separator, ...
    "G_leak_S", p.separator.leakage_conductance_S);
diagnostics = struct("t", t, "porosity", p.separator.epsilon_separator);
end
