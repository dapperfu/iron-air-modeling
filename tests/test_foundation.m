function tests = test_foundation
%TEST_FOUNDATION Verify project setup, state mapping, and solver profiles.
%   Requirements: SRS001.2, SRS001.3, SRS018, SRS023.
tests = functiontests(localfunctions);
end

function setupOnce(test_case)
root = fileparts(fileparts(mfilename("fullpath")));
addpath(root);
test_case.TestData.project = ironair_setup();
end

function test_setup_has_no_base_state(test_case)
project = test_case.TestData.project;
verifyTrue(test_case, isfolder(project.root));
verifyTrue(test_case, isfolder(project.requirements_dir));
verifyFalse(test_case, evalin("base", "exist('IronAir','var') == 1"));
end

function test_resolution_ordering(test_case)
smoke = ironair_resolution_profile("smoke");
standard = ironair_resolution_profile("standard");
reference = ironair_resolution_profile("reference");
verifyGreaterThan(test_case, smoke.rel_tol, standard.rel_tol);
verifyGreaterThan(test_case, standard.rel_tol, reference.rel_tol);
verifyLessThan(test_case, smoke.electrode_control_volumes, ...
    standard.electrode_control_volumes);
verifyLessThan(test_case, standard.electrode_control_volumes, ...
    reference.electrode_control_volumes);
end

function test_named_state_map(test_case)
specs(1) = struct("name", "metal", ...
    "state_names", ["n_Fe_mol", "n_FeOH2_mol"]);
specs(2) = struct("name", "thermal", "state_names", "T_cell_K");
map = ironair_state_map(specs);
verifyEqual(test_case, map.count, 3);
verifyEqual(test_case, map.components.metal, 1:2);
verifyEqual(test_case, map.components.thermal, 3);
verifyEqual(test_case, map.names, ...
    ["metal.n_Fe_mol"; "metal.n_FeOH2_mol"; "thermal.T_cell_K"]);
end

function test_duplicate_state_rejected(test_case)
spec = struct("name", "metal", "state_names", ["n_Fe_mol", "n_Fe_mol"]);
verifyError(test_case, @() ironair_state_map(spec), ...
    "ironair:stateMap:DuplicateLocalState");
end

function test_solver_options_are_state_scaled(test_case)
profile = ironair_resolution_profile("standard");
options = ironair_solver_options(profile, [1; 100], [], speye(2));
verifyEqual(test_case, options.RelTol, profile.rel_tol);
verifyEqual(test_case, options.MaxStep, profile.max_step_s);
verifySize(test_case, options.AbsTol, [2, 1]);
verifyGreaterThan(test_case, options.AbsTol(2), options.AbsTol(1));
verifyEqual(test_case, options.JPattern, sparse(logical(eye(2))));
end
