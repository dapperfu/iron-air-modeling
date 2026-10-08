function map = ironair_state_map(component_specs)
%IRONAIR_STATE_MAP Build deterministic named indices for coupled states.
%   MAP = IRONAIR_STATE_MAP(COMPONENT_SPECS) concatenates component-local
%   state names into one system ordering.
%
%   Input:
%     component_specs - Structure array with scalar string fields `name`
%       and string-vector field `state_names`.
%
%   Output:
%     map.count        - Total state count.
%     map.names        - Fully qualified state names.
%     map.components   - Scalar structure of component index vectors.
%
%   Units: indices are dimensionless.
%   Assumptions: component and state names are valid MATLAB identifiers.
%   Requirements: SRS001.2, SRS018.

arguments
    component_specs (1, :) struct
end

map = struct("count", 0, "names", strings(0, 1), ...
    "components", struct());
next_index = 1;

for component_index = 1:numel(component_specs)
    spec = component_specs(component_index);
    required_fields = ["name", "state_names"];
    if ~all(isfield(spec, required_fields))
        error("ironair:stateMap:MissingField", ...
            "Each component specification requires name and state_names.");
    end
    component_name = string(spec.name);
    state_names = string(spec.state_names(:));
    if ~isvarname(component_name)
        error("ironair:stateMap:InvalidComponentName", ...
            "Invalid component name: %s", component_name);
    end
    if any(~arrayfun(@isvarname, state_names))
        error("ironair:stateMap:InvalidStateName", ...
            "Component %s contains an invalid state name.", component_name);
    end
    if numel(unique(state_names)) ~= numel(state_names)
        error("ironair:stateMap:DuplicateLocalState", ...
            "Component %s contains duplicate state names.", component_name);
    end

    count = numel(state_names);
    indices = next_index:(next_index + count - 1);
    map.components.(component_name) = indices;
    qualified_names = component_name + "." + state_names;
    map.names = [map.names; qualified_names];
    next_index = next_index + count;
end

if numel(unique(map.names)) ~= numel(map.names)
    error("ironair:stateMap:DuplicateQualifiedState", ...
        "The coupled map contains duplicate qualified state names.");
end
map.count = next_index - 1;
end
