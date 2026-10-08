function p = ironair_configuration_profile(profile_name, resolution_name)
%IRONAIR_CONFIGURATION_PROFILE Inherit baseline parameters then apply overrides.
%   P = IRONAIR_CONFIGURATION_PROFILE(PROFILE_NAME, RESOLUTION_NAME) starts
%   from ironair_default_parameters and applies one documented profile.
%
%   Inputs:
%     profile_name    - Named configuration from SRS022.
%     resolution_name - `smoke`, `standard`, or `reference`.
%
%   Output:
%     p - Validated inherited parameter structure.
%
%   Requirements: SRS022, SRS002.3.

arguments
    profile_name (1, 1) string {mustBeMember(profile_name, [ ...
        "baseline_research", "single_cell", "small_stack", ...
        "prototype_module", "grid_scale_1MW", "high_temperature", ...
        "low_temperature", "high_KOH", "low_KOH", "degraded_cell", ...
        "separate_ORR_OER", "bifunctional_electrode", ...
        "forced_electrolyte_circulation", "passive_electrolyte"])}
    resolution_name (1, 1) string = "standard"
end

p = ironair_default_parameters(resolution_name);
p.profile_name = profile_name;

switch profile_name
    case "baseline_research"
        p.fidelity_level = 1;
    case "single_cell"
        p = set_topology(p, 1, 1, 1, 1);
        p.fidelity_level = 1;
    case "small_stack"
        p = set_topology(p, 10, 2, 1, 1);
        p.fidelity_level = 2;
    case "prototype_module"
        p = set_topology(p, 20, 4, 2, 1);
        p.fidelity_level = 2;
    case "grid_scale_1MW"
        p = set_topology(p, 100, 10, 4, 25);
        p.fidelity_level = 2;
    case "high_temperature"
        p = ironair_set_parameter(p, "reference", "T_initial_K", 333.15);
    case "low_temperature"
        p = ironair_set_parameter(p, "reference", "T_initial_K", 278.15);
    case "high_KOH"
        p = set_koh(p, 8000);
    case "low_KOH"
        p = set_koh(p, 2000);
    case "degraded_cell"
        p = ironair_set_parameter(p, "reference", "SOH_initial", 0.70);
        p = ironair_set_parameter(p, "orr_catalyst", "activity_initial", 0.70);
        p = ironair_set_parameter(p, "oer_catalyst", "activity_initial", 0.70);
        p = ironair_set_parameter(p, "aging_degradation", ...
            "k_aging_ref_1_s", 5e-10);
    case "separate_ORR_OER"
        p = ironair_set_parameter(p, "air_electrode", "configuration_code", 2);
    case "bifunctional_electrode"
        p = ironair_set_parameter(p, "air_electrode", "configuration_code", 1);
    case "forced_electrolyte_circulation"
        p = ironair_set_parameter(p, "electrolyte_circulation", "enabled", true);
        p = ironair_set_parameter(p, "electrolyte_circulation", ...
            "Q_nominal_m3_s", 5e-5);
    case "passive_electrolyte"
        p = ironair_set_parameter(p, "electrolyte_circulation", "enabled", false);
        p = ironair_set_parameter(p, "electrolyte_circulation", ...
            "Q_nominal_m3_s", 0);
    otherwise
        error("ironair:config:UnknownProfile", ...
            "Unsupported configuration profile: %s", profile_name);
end

ironair_validate_parameters(p);
end

function p = set_topology(p, n_series, n_parallel, n_stacks, n_modules)
p = ironair_set_parameter(p, "stack", "N_series", n_series);
p = ironair_set_parameter(p, "stack", "N_parallel", n_parallel);
p = ironair_set_parameter(p, "module", "N_stacks", n_stacks);
p = ironair_set_parameter(p, "enclosure", "N_modules", n_modules);
end

function p = set_koh(p, c_KOH_mol_m3)
p = ironair_set_parameter(p, "electrolyte", "c_KOH_initial_mol_m3", c_KOH_mol_m3);
p = ironair_set_parameter(p, "electrolyte", "c_OH_initial_mol_m3", c_KOH_mol_m3);
p = ironair_set_parameter(p, "electrolyte", "c_K_initial_mol_m3", c_KOH_mol_m3);
p = ironair_set_parameter(p, "reference", "c_KOH_initial_mol_L", c_KOH_mol_m3 / 1000);
end
