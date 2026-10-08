function tests = test_parameters
%TEST_PARAMETERS Verify constants, catalog metadata, and inheritance.
%   Requirements: SRS002, SRS022, SRS023.
tests = functiontests(localfunctions);
end

function setupOnce(test_case)
root = fileparts(fileparts(mfilename("fullpath")));
addpath(root);
test_case.TestData.project = ironair_setup();
end

function test_faraday_capacity_is_derived(test_case)
c = ironair_physical_constants();
expected = c.n_Fe_FeOH2 * c.F_C_mol / (3600 * c.M_Fe_kg_mol);
verifyEqual(test_case, c.Q_Fe_Ah_kg, expected, "RelTol", 1e-15);
end

function test_default_parameters_validate(test_case)
p = ironair_default_parameters("smoke");
verifyTrue(test_case, ironair_validate_parameters(p));
verifyEqual(test_case, p.parameter_set_id, "baseline_research_v1");
end

function test_out_of_range_parameter_rejected(test_case)
p = ironair_default_parameters("smoke");
p.iron_electrode.alpha_a_Fe = 2;
verifyError(test_case, @() ironair_validate_parameters(p), ...
    "ironair:parameter:OutOfRange");
end

function test_electroneutrality_rejected(test_case)
p = ironair_default_parameters("smoke");
p.electrolyte.c_K_initial_mol_m3 = 6100;
verifyError(test_case, @() ironair_validate_parameters(p), ...
    "ironair:parameter:InitialElectroneutrality");
end

function test_configuration_profiles_inherit(test_case)
names = [ ...
    "baseline_research", "single_cell", "small_stack", ...
    "prototype_module", "grid_scale_1MW", "high_temperature", ...
    "low_temperature", "high_KOH", "low_KOH", "degraded_cell", ...
    "separate_ORR_OER", "bifunctional_electrode", ...
    "forced_electrolyte_circulation", "passive_electrolyte"];
for index = 1:numel(names)
    p = ironair_configuration_profile(names(index), "smoke");
    verifyEqual(test_case, p.profile_name, names(index));
    verifyTrue(test_case, ironair_validate_parameters(p));
end
end

function test_high_koh_updates_ions(test_case)
p = ironair_configuration_profile("high_KOH", "smoke");
verifyEqual(test_case, p.electrolyte.c_KOH_initial_mol_m3, 8000);
verifyEqual(test_case, p.electrolyte.c_OH_initial_mol_m3, ...
    p.electrolyte.c_K_initial_mol_m3);
end
