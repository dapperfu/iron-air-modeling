function p = ironair_set_parameter(p, group_name, parameter_name, value)
%IRONAIR_SET_PARAMETER Override one metadata-backed parameter value.
%   P = IRONAIR_SET_PARAMETER(P, GROUP_NAME, PARAMETER_NAME, VALUE) writes a
%   numeric or logical override and leaves provenance metadata unchanged.
%
%   Inputs:
%     p              - Complete parameter structure.
%     group_name     - Top-level group field name.
%     parameter_name - Parameter field within the group.
%     value          - Replacement numeric or logical scalar.
%
%   Output:
%     p - Updated parameter structure. Range checks occur at validation.
%
%   Requirements: SRS002.3, SRS022.

arguments
    p (1, 1) struct
    group_name (1, 1) string
    parameter_name (1, 1) string
    value
end

if ~isfield(p, group_name)
    error("ironair:parameter:UnknownGroup", ...
        "Unknown parameter group: %s", group_name);
end
group = p.(group_name);
if ~isfield(group, parameter_name)
    error("ironair:parameter:UnknownParameter", ...
        "Unknown parameter %s.%s", group_name, parameter_name);
end
group.(parameter_name) = value;
p.(group_name) = group;
end
