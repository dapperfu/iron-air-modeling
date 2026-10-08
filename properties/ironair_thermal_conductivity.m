function [k_W_mK, diagnostics] = ironair_thermal_conductivity(material_name, T_K, p)
%IRONAIR_THERMAL_CONDUCTIVITY Return an assumed material conductivity.
%   [K_W_MK, DIAGNOSTICS] = IRONAIR_THERMAL_CONDUCTIVITY(MATERIAL_NAME, T_K, P)
%   selects Fe, electrolyte, or polymer values from the parameter catalog.
%
%   Inputs:
%     material_name - "Fe", "electrolyte", or "polymer".
%     T_K           - Temperature, K.
%     p             - Complete parameter structure.
%
%   Outputs:
%     k_W_mK      - Thermal conductivity, W/(m K).
%     diagnostics - Extrapolation diagnostics.
%
%   Equation: THM-005
%   Requirements: SRS002.4, SRS008.

arguments
    material_name (1, 1) string {mustBeMember(material_name, ...
        ["Fe", "electrolyte", "polymer"])}
    T_K double
    p (1, 1) struct
end

policy = ironair_property_policy(p);
[T_K, d_T] = ironair_property_guard(T_K, ...
    [p.electrolyte.T_property_min_K, p.electrolyte.T_property_max_K], ...
    policy, "T_K");

switch material_name
    case "Fe"
        k_W_mK = p.thermal_properties.k_Fe_W_mK + 0 .* T_K;
    case "electrolyte"
        k_W_mK = p.thermal_properties.k_electrolyte_W_mK + 0 .* T_K;
    case "polymer"
        k_W_mK = p.thermal_properties.k_polymer_W_mK + 0 .* T_K;
    otherwise
        error("ironair:property:UnknownMaterial", ...
            "Unsupported thermal-conductivity material.");
end

diagnostics = struct("temperature", d_T, "material", material_name, ...
    "classification", "ASSUMED");
end
