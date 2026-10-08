function diagnostics = ironair_state_validity(component_name, inventories, extra_nonneg)
%IRONAIR_STATE_VALIDITY Detect nonphysical inventories without silent clamping.
%   DIAGNOSTICS = IRONAIR_STATE_VALIDITY(COMPONENT_NAME, INVENTORIES,
%   EXTRA_NONNEG) errors on substantially negative species or passivation.
%
%   Requirements: SRS018, SRS023.

arguments
    component_name (1, 1) string
    inventories (:, 1) double
    extra_nonneg (:, 1) double = zeros(0, 1)
end

tolerance_mol = 1e-4;
if any(inventories < -tolerance_mol)
    error("ironair:state:NegativeInventory", ...
        "%s contains a substantially negative inventory.", component_name);
end
if any(extra_nonneg < -tolerance_mol)
    error("ironair:state:NegativeThickness", ...
        "%s contains a substantially negative geometric state.", component_name);
end
diagnostics = struct( ...
    "component", component_name, ...
    "min_inventory", min(inventories), ...
    "negative_within_tolerance", any(inventories < 0));
end
