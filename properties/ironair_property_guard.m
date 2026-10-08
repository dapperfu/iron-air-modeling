function [value, diagnostics] = ironair_property_guard(value, valid_range, policy, property_name)
%IRONAIR_PROPERTY_GUARD Enforce a documented property correlation domain.
%   [VALUE, DIAGNOSTICS] = IRONAIR_PROPERTY_GUARD(VALUE, VALID_RANGE, POLICY,
%   PROPERTY_NAME) rejects, clips, or explicitly warns about extrapolation.
%
%   Inputs:
%     value         - Numeric scalar or array in the caller's documented SI unit.
%     valid_range   - Two-element [minimum maximum] in the same unit.
%     policy        - `error`, `clip`, or `warn`.
%     property_name - Diagnostic property/independent-variable name.
%
%   Outputs:
%     value       - Original or explicitly clipped numeric value.
%     diagnostics - Structure with extrapolated mask and policy.
%
%   Requirements: SRS002.4, SRS018.

arguments
    value double
    valid_range (1, 2) double
    policy (1, 1) string {mustBeMember(policy, ["error", "clip", "warn"])}
    property_name (1, 1) string
end

if valid_range(1) > valid_range(2)
    error("ironair:property:InvalidRange", ...
        "Invalid range supplied for %s.", property_name);
end
if any(~isfinite(value), "all")
    error("ironair:property:NonfiniteInput", ...
        "%s contains a nonfinite value.", property_name);
end

extrapolated = value < valid_range(1) | value > valid_range(2);
if any(extrapolated, "all")
    switch policy
        case "error"
            error("ironair:property:OutsideValidity", ...
                "%s is outside [%g, %g].", property_name, ...
                valid_range(1), valid_range(2));
        case "clip"
            value = min(max(value, valid_range(1)), valid_range(2));
        case "warn"
            warning("ironair:property:Extrapolation", ...
                "%s is being explicitly extrapolated beyond [%g, %g].", ...
                property_name, valid_range(1), valid_range(2));
    end
end

diagnostics = struct( ...
    "extrapolated", extrapolated, ...
    "policy", policy, ...
    "valid_range", valid_range);
end
