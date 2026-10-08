function [D_gas_m2_s, diagnostics] = ironair_gas_diffusivity(T_K, p_Pa, p)
%IRONAIR_GAS_DIFFUSIVITY Return an assumed binary gas diffusivity.
%   [D_GAS_M2_S, DIAGNOSTICS] = IRONAIR_GAS_DIFFUSIVITY(T_K, P_PA, P) scales a
%   reference oxygen-in-air diffusivity with temperature and pressure.
%
%   Inputs:
%     T_K  - Temperature, K.
%     p_Pa - Total gas pressure, Pa.
%     p    - Complete parameter structure.
%
%   Outputs:
%     D_gas_m2_s  - Gas diffusivity, m2/s.
%     diagnostics - Extrapolation diagnostics.
%
%   Equation: GDL-002
%   Requirements: SRS002.4, SRS006, SRS009.

arguments
    T_K double
    p_Pa double
    p (1, 1) struct
end

policy = ironair_property_policy(p);
[T_K, d_T] = ironair_property_guard(T_K, ...
    [p.electrolyte.T_property_min_K, p.electrolyte.T_property_max_K], ...
    policy, "T_K");
[p_Pa, d_p] = ironair_property_guard(p_Pa, [1e4, 2e5], policy, "p_Pa");

D_gas_m2_s = p.gas_properties.D_gas_ref_m2_s .* ...
    (T_K ./ p.constants.T_ref_K).^p.gas_properties.gas_diffusivity_T_exponent .* ...
    (p.constants.p_ref_Pa ./ p_Pa);

diagnostics = struct("temperature", d_T, "pressure", d_p, ...
    "classification", "ASSUMED");
end
