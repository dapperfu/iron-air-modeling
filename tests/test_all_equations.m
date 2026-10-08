function tests = test_all_equations
%TEST_ALL_EQUATIONS Aggregate entry point for domain equation suites.
tests = functiontests(localfunctions);
end

function setupOnce(test_case)
root = fileparts(fileparts(mfilename("fullpath")));
addpath(root);
ironair_setup();
test_case.TestData.root = root;
end

function test_run_domain_suites(test_case)
root = test_case.TestData.root;
suites = [ ...
    "test_parameters.m", "test_properties.m", "test_reaction_network.m", ...
    "test_equations_electrochemistry.m", "test_equations_balance_of_plant.m", ...
    "test_equations_electrical.m", "test_equations_controls_grid.m", ...
    "test_traceability_coverage.m", "test_system_scenarios.m"];
for index = 1:numel(suites)
    result = runtests(fullfile(root, "tests", suites(index)));
    verifyTrue(test_case, all([result.Passed]), ...
        "Suite failed: " + suites(index));
end
end
