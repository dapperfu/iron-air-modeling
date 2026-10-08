function [eta_V, j_A_m2, diagnostics] = ironair_solve_overpotential(j_target_A_m2, j_0_A_m2, alpha_a, alpha_c, n_e, T_K, constants)
%IRONAIR_SOLVE_OVERPOTENTIAL Invert Butler-Volmer for overpotential.
%   [ETA_V, J_A_M2, DIAGNOSTICS] = IRONAIR_SOLVE_OVERPOTENTIAL(...) solves
%   j(eta) = j_target with the bounded Butler-Volmer residual.
%
%   Requirements: SRS003.2, SRS018.

arguments
    j_target_A_m2 (1, 1) double
    j_0_A_m2 (1, 1) double {mustBeNonnegative}
    alpha_a (1, 1) double
    alpha_c (1, 1) double
    n_e (1, 1) double {mustBePositive}
    T_K (1, 1) double {mustBePositive}
    constants (1, 1) struct
end

j_limit = 1e6 * max(j_0_A_m2, 1e-12);
if abs(j_target_A_m2) > j_limit
    error("ironair:kinetics:InfeasibleCurrent", ...
        "Requested current density exceeds the bounded kinetic range.");
end

residual = @(eta) ironair_butler_volmer(j_0_A_m2, alpha_a, alpha_c, n_e, ...
    eta, T_K, constants) - j_target_A_m2;
eta0 = 0;
if j_0_A_m2 > 0
    eta0 = sign(j_target_A_m2) * constants.R_J_molK * T_K / ...
        (n_e * constants.F_C_mol);
end
[eta_V, diagnostics] = ironair_nonlinear_solve(residual, eta0);
j_A_m2 = ironair_butler_volmer(j_0_A_m2, alpha_a, alpha_c, n_e, ...
    eta_V, T_K, constants);
end
