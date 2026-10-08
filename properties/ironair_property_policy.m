function policy = ironair_property_policy(p)
%IRONAIR_PROPERTY_POLICY Map configuration to an extrapolation policy.
%   POLICY = IRONAIR_PROPERTY_POLICY(P) returns "error", "clip", or "warn"
%   from the electrolyte extrapolation policy code.
%
%   Input:
%     p - Parameter structure from ironair_default_parameters.
%
%   Output:
%     policy - Documented extrapolation policy string.
%
%   Units: policy is dimensionless text.
%   Assumptions: missing codes default to fail-fast rejection.
%   Requirements: SRS002.4, SRS018.

arguments
    p (1, 1) struct
end

policy = "error";
if isfield(p, "electrolyte") && isfield(p.electrolyte, "extrapolation_policy_code")
    switch p.electrolyte.extrapolation_policy_code
        case 0
            policy = "error";
        case 1
            policy = "warn";
        otherwise
            error("ironair:property:UnknownPolicy", ...
                "Unsupported extrapolation_policy_code.");
    end
end
end
