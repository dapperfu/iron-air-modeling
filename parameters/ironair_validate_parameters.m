function valid = ironair_validate_parameters(p)
%IRONAIR_VALIDATE_PARAMETERS Reject incomplete or physically invalid sets.
%   VALID = IRONAIR_VALIDATE_PARAMETERS(P) checks every metadata-backed
%   scalar against its declared range and verifies cross-group constraints.
%
%   Input:
%     p - Complete scalar configuration from ironair_default_parameters.
%
%   Output:
%     valid - Logical true when all checks pass. Invalid input throws a
%       diagnostic error and never receives silent substitutions.
%
%   Requirements: SRS002.3, SRS005.1, SRS018, SRS023.

arguments
    p (1, 1) struct
end

required_top_level = ["constants", "reference", "resolution", ...
    "iron_electrode", "air_electrode", "electrolyte", "cell_geometry"];
if ~all(isfield(p, required_top_level))
    error("ironair:parameter:IncompleteSet", ...
        "The parameter set is missing required top-level groups.");
end

fields = fieldnames(p);
for field_index = 1:numel(fields)
    group_name = fields{field_index};
    group = p.(group_name);
    if ~isstruct(group) || ~isfield(group, "meta")
        continue;
    end
    metadata_names = fieldnames(group.meta);
    for metadata_index = 1:numel(metadata_names)
        parameter_name = metadata_names{metadata_index};
        if ~isfield(group, parameter_name)
            error("ironair:parameter:MetadataWithoutValue", ...
                "%s.%s has metadata but no value.", group_name, parameter_name);
        end
        value = group.(parameter_name);
        metadata = group.meta.(parameter_name);
        if ~(isnumeric(value) || islogical(value)) || ~isscalar(value) || ...
                ~isfinite(double(value))
            error("ironair:parameter:NonfiniteValue", ...
                "%s.%s must be a finite numeric scalar.", ...
                group_name, parameter_name);
        end
        range = metadata.valid_range;
        if double(value) < range(1) || double(value) > range(2)
            error("ironair:parameter:OutOfRange", ...
                "%s.%s is outside [%g, %g] %s.", group_name, ...
                parameter_name, range(1), range(2), metadata.unit);
        end
    end
end

if p.reference.SOC_initial < 0 || p.reference.SOC_initial > 1 || ...
        p.reference.SOH_initial < 0 || p.reference.SOH_initial > 1
    error("ironair:parameter:InvalidStateFraction", ...
        "Initial SOC and SOH must lie in [0, 1].");
end
if p.supervisory_controls.SOC_min >= p.supervisory_controls.SOC_max
    error("ironair:parameter:InvalidSOCLimits", ...
        "SOC_min must be lower than SOC_max.");
end
if p.supervisory_controls.T_derate_K >= p.supervisory_controls.T_trip_K
    error("ironair:parameter:InvalidThermalLimits", ...
        "Thermal derating must begin below the trip temperature.");
end
if p.dc_bus.V_dc_min_V >= p.dc_bus.V_dc_max_V
    error("ironair:parameter:InvalidBusLimits", ...
        "DC minimum voltage must be lower than maximum voltage.");
end

charge_density_mol_m3 = p.electrolyte.c_K_initial_mol_m3 ...
    - p.electrolyte.c_OH_initial_mol_m3 ...
    - 2 * p.electrolyte.c_CO3_initial_mol_m3;
electroneutrality_tolerance_mol_m3 = 1e-9 * ...
    max(1, p.electrolyte.c_K_initial_mol_m3);
if abs(charge_density_mol_m3) > electroneutrality_tolerance_mol_m3
    error("ironair:parameter:InitialElectroneutrality", ...
        "Initial electrolyte species violate electroneutrality.");
end

valid = true;
end
