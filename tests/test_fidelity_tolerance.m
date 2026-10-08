function tests = test_fidelity_tolerance
tests = functiontests(localfunctions);
end

function setupOnce(~)
root = fileparts(fileparts(mfilename("fullpath")));
addpath(root);
ironair_setup();
end

function test_resolution_refinement_ordering(test_case)
s = ironair_resolution_profile("smoke");
n = ironair_resolution_profile("standard");
r = ironair_resolution_profile("reference");
verifyGreaterThan(test_case, s.rel_tol, n.rel_tol);
verifyGreaterThan(test_case, n.rel_tol, r.rel_tol);
end

function test_level1_recovers_on_single_cell(test_case)
p1 = ironair_configuration_profile("single_cell", "smoke");
p1.fidelity_level = 1;
[x1, ~] = ironair_cell_initial_state(p1, 1);
[~, o1] = ironair_cell_model(0, x1, struct("I_cell_A", 1, "T_cell_K", 298.15), p1);
p2 = p1;
p2.fidelity_level = 2;
[x2, ~] = ironair_cell_initial_state(p2, 1);
[~, o2] = ironair_cell_model(0, x2, struct("I_cell_A", 1, "T_cell_K", 298.15), p2);
verifyEqual(test_case, sign(o1.I_Fe_A), sign(o2.I_Fe_A));
verifyGreaterThan(test_case, o1.e_cell_eq_V, 0.5);
verifyGreaterThan(test_case, o2.e_cell_eq_V, 0.5);
end
