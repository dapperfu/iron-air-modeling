function diagnostics = ironair_conservation_check(n_species, n_species_ref, q_boundary_integral, net, tolerances)
%IRONAIR_CONSERVATION_CHECK Report elemental inventory residuals.
%   DIAGNOSTICS = IRONAIR_CONSERVATION_CHECK(N_SPECIES, N_SPECIES_REF,
%   Q_BOUNDARY_INTEGRAL, NET, TOLERANCES) compares current inventories with a
%   reference after subtracting integrated boundary flows.
%
%   Inputs:
%     n_species            - Current species moles, aligned with net.species.
%     n_species_ref        - Reference species moles.
%     q_boundary_integral  - Time-integrated boundary moles.
%     net                  - Canonical reaction network.
%     tolerances           - Absolute elemental residual limits.
%
%   Output:
%     diagnostics - Absolute and normalized residuals plus pass flags.
%
%   Requirements: SRS023.

arguments
    n_species (:, 1) double
    n_species_ref (:, 1) double
    q_boundary_integral (:, 1) double
    net (1, 1) struct
    tolerances (1, 1) struct = struct("absolute", 1e-8, "relative", 1e-8)
end

n_internal = n_species - n_species_ref - q_boundary_integral;
element_now = net.A_elements * n_internal;
scale = max(1, abs(net.A_elements * n_species_ref));
absolute_residual = abs(element_now);
normalized_residual = absolute_residual ./ scale;
passed = absolute_residual <= tolerances.absolute | ...
    normalized_residual <= tolerances.relative;

diagnostics = struct( ...
    "elements", net.elements, ...
    "absolute_residual", absolute_residual, ...
    "normalized_residual", normalized_residual, ...
    "passed", passed, ...
    "all_passed", all(passed));
end
