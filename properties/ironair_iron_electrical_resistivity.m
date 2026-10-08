function [rho_Ohm_m, diagnostics] = ironair_iron_electrical_resistivity(T_K, p)
%IRONAIR_IRON_ELECTRICAL_RESISTIVITY Return assumed iron resistivity.
%   [RHO_OHM_M, DIAGNOSTICS] = IRONAIR_IRON_ELECTRICAL_RESISTIVITY(T_K, P)
%   applies a linear temperature coefficient to a reference resistivity.
%
%   Inputs:
%     T_K - Temperature, K.
%     p   - Complete parameter structure.
%
%   Outputs:
%     rho_Ohm_m   - Electrical resistivity, Ohm m.
%     diagnostics - Extrapolation diagnostics.
%
%   Requirements: SRS002.4, SRS003.3.

arguments
    T_K double
    p (1, 1) struct
end

policy = ironair_property_policy(p);
[T_K, d_T] = ironair_property_guard(T_K, ...
    [p.electrolyte.T_property_min_K, p.electrolyte.T_property_max_K], ...
    policy, "T_K");

rho_Ohm_m = p.iron_electrode.rho_Fe_ref_Ohm_m .* ...
    (1 + p.iron_electrode.alpha_rho_Fe_1_K .* (T_K - p.constants.T_ref_K));

diagnostics = struct("temperature", d_T, "classification", "ASSUMED");
end
