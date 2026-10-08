function p = ironair_default_parameters(resolution_name)
%IRONAIR_DEFAULT_PARAMETERS Build the baseline research parameter set.
%   P = IRONAIR_DEFAULT_PARAMETERS(RESOLUTION_NAME) returns explicit,
%   metadata-backed development parameters for the complete model.
%
%   Input:
%     resolution_name - `smoke`, `standard`, or `reference`.
%
%   Output:
%     p - Scalar configuration structure. Numeric physics values reside in
%       named component groups; provenance resides in each group's `meta`.
%
%   Values classified ASSUMED or CALIBRATION_REQUIRED are runnable engineering
%   placeholders, not experimentally validated commercial battery properties.
%
%   Requirements: SRS002.2, SRS002.3, SRS022.

arguments
    resolution_name (1, 1) string = "standard"
end

p = struct();
p.parameter_set_id = "baseline_research_v1";
p.profile_name = "baseline_research";
p.fidelity_level = 1;
p.resolution = ironair_resolution_profile(resolution_name);
p.constants = ironair_physical_constants();

p.reference = struct( ...
    "T_initial_K", 298.15, ...
    "p_ambient_Pa", 101325, ...
    "RH_ambient", 0.50, ...
    "x_O2_dry_air", 0.2095, ...
    "x_CO2_dry_air", 0.00042, ...
    "c_KOH_initial_mol_L", 6.0, ...
    "SOC_initial", 0.50, ...
    "SOH_initial", 1.0, ...
    "E_cell_nominal_V", 1.0, ...
    "E_cell_eq_ref_V", 1.28, ...
    "duration_target_h", 100, ...
    "P_AC_rated_W", 1e6);
p.reference_meta = reference_metadata();

groups = [ ...
    "iron_electrode", "iron_phases", "air_electrode", "orr_catalyst", ...
    "oer_catalyst", "hydrogen_evolution", "electrolyte", "separator", ...
    "gas_diffusion_layer", "current_collectors", "cell_geometry", ...
    "thermal_properties", "gas_properties", "liquid_transport", ...
    "electrolyte_circulation", "pumps", "fans", "valves", ...
    "heat_exchanger", "reservoir", "piping", "stack", "module", ...
    "enclosure", "dc_bus", "dcdc_converter", "inverter", "transformer", ...
    "electrical_protection", "sensors", "supervisory_controls", "grid", ...
    "aging_degradation", "fault_detection"];
for index = 1:numel(groups)
    p.(groups(index)) = ironair_parameter_catalog(groups(index));
end

ironair_validate_parameters(p);
end

function result = reference_metadata()
result = struct();
result.T_initial_K = ref("K", [250, 400], "REFERENCE_CONDITION");
result.p_ambient_Pa = ref("Pa", [1e4, 2e5], "REFERENCE_CONDITION");
result.RH_ambient = ref("1", [0, 1], "ASSUMED");
result.x_O2_dry_air = ref("1", [0, 1], "REFERENCE_CONDITION");
result.x_CO2_dry_air = ref("1", [0, 0.1], "REFERENCE_CONDITION");
result.c_KOH_initial_mol_L = ref("mol/L", [0.5, 12], "ASSUMED");
result.SOC_initial = ref("1", [0, 1], "ASSUMED");
result.SOH_initial = ref("1", [0, 1], "ASSUMED");
result.E_cell_nominal_V = ref("V", [0.1, 3], "ASSUMED");
result.E_cell_eq_ref_V = ref("V", [0.1, 3], "ASSUMED");
result.duration_target_h = ref("h", [0, 1e5], "ASSUMED");
result.P_AC_rated_W = ref("W", [1, 1e12], "ASSUMED");
end

function result = ref(unit, valid_range, classification)
result = ironair_parameter_metadata(unit, classification, valid_range, ...
    "Baseline research reference configuration", "NONE");
end
