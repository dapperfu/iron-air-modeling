function [j_A_m2, diagnostics] = ironair_butler_volmer(j_0_A_m2, alpha_a, alpha_c, n_e, eta_V, T_K, constants)
%IRONAIR_BUTLER_VOLMER Evaluate a numerically stable Butler-Volmer current.
%   [J_A_M2, DIAGNOSTICS] = IRONAIR_BUTLER_VOLMER(...) uses bounded exponents.
%
%   Inputs:
%     j_0_A_m2  - Exchange current density, A/m2.
%     alpha_a   - Anodic transfer coefficient, dimensionless.
%     alpha_c   - Cathodic transfer coefficient, dimensionless.
%     n_e       - Electrons in the kinetic exponent, dimensionless.
%     eta_V     - Overpotential, V.
%     T_K       - Temperature, K.
%     constants - Physical constants structure.
%
%   Outputs:
%     j_A_m2      - Faradaic current density, A/m2.
%     diagnostics - Exponent clip flags.
%
%   Equation: FE-003, HER-002, AIR-004, AIR-005
%   Requirements: SRS003.2, SRS018.

arguments
    j_0_A_m2 double
    alpha_a double
    alpha_c double
    n_e double
    eta_V double
    T_K double
    constants (1, 1) struct
end

if any(T_K <= 0, "all")
    error("ironair:kinetics:InvalidTemperature", ...
        "Butler-Volmer temperature must be positive.");
end

RT_inv = constants.F_C_mol ./ (constants.R_J_molK .* T_K);
xi_a = alpha_a .* n_e .* RT_inv .* eta_V;
xi_c = -alpha_c .* n_e .* RT_inv .* eta_V;
xi_limit = 40;
clipped = abs(xi_a) > xi_limit | abs(xi_c) > xi_limit;
xi_a = min(max(xi_a, -xi_limit), xi_limit);
xi_c = min(max(xi_c, -xi_limit), xi_limit);
j_A_m2 = j_0_A_m2 .* (exp(xi_a) - exp(xi_c));

diagnostics = struct("clipped", clipped, "xi_limit", xi_limit);
end
