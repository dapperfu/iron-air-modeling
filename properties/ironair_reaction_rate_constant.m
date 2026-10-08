function [k_rate, diagnostics] = ironair_reaction_rate_constant(k_ref, E_a_J_mol, T_K, p)
%IRONAIR_REACTION_RATE_CONSTANT Return an Arrhenius rate coefficient.
%   [K_RATE, DIAGNOSTICS] = IRONAIR_REACTION_RATE_CONSTANT(K_REF, E_A_J_MOL,
%   T_K, P) evaluates k_ref * exp(-(Ea/R)*(1/T-1/T_ref)).
%
%   Inputs:
%     k_ref      - Reference rate coefficient in the caller-documented unit.
%     E_a_J_mol  - Activation energy, J/mol.
%     T_K        - Temperature, K.
%     p          - Complete parameter structure.
%
%   Outputs:
%     k_rate      - Temperature-adjusted rate coefficient.
%     diagnostics - Extrapolation diagnostics.
%
%   Equation: FE-006, DEG-001
%   Requirements: SRS002.4, SRS003.2, SRS016.

arguments
    k_ref double
    E_a_J_mol double
    T_K double
    p (1, 1) struct
end

policy = ironair_property_policy(p);
[T_K, d_T] = ironair_property_guard(T_K, ...
    [p.electrolyte.T_property_min_K, p.electrolyte.T_property_max_K], ...
    policy, "T_K");
if any(k_ref < 0, "all") || any(E_a_J_mol < 0, "all")
    error("ironair:property:InvalidArrhenius", ...
        "Rate coefficient and activation energy must be nonnegative.");
end

k_rate = k_ref .* exp(-(E_a_J_mol ./ p.constants.R_J_molK) .* ...
    (1 ./ T_K - 1 ./ p.constants.T_ref_K));

diagnostics = struct("temperature", d_T, "classification", "CALIBRATION_REQUIRED");
end
