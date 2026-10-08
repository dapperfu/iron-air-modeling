function tests = test_reaction_network
%TEST_REACTION_NETWORK Verify stoichiometry and elemental conservation.
%   Equations: FE-001, FE-014, AIR-001, AIR-002, HER-001, ELY-009, SYS-001,
%   SYS-002
%   Requirements: SRS019, SRS023.
tests = functiontests(localfunctions);
end

function setupOnce(test_case)
root = fileparts(fileparts(mfilename("fullpath")));
addpath(root);
ironair_setup();
test_case.TestData.net = ironair_reaction_network();
end

function test_elemental_nullspace(test_case)
net = test_case.TestData.net;
residual = net.A_elements * net.S;
verifyEqual(test_case, residual, zeros(size(residual)), "AbsTol", 1e-12);
end

function test_iron_oxidation_inventory(test_case)
net = test_case.TestData.net;
r = zeros(numel(net.reactions), 1);
r(net.idx.Fe_ox) = 1;
q = zeros(numel(net.species), 1);
[dn_dt, diagnostics] = ironair_species_rates(r, q, net);
verifyEqual(test_case, dn_dt(net.idx.Fe), -1, "AbsTol", 1e-15);
verifyEqual(test_case, dn_dt(net.idx.FeOH2), 1, "AbsTol", 1e-15);
verifyEqual(test_case, dn_dt(net.idx.e), 2, "AbsTol", 1e-15);
verifyEqual(test_case, diagnostics.residual_inf, 0, "AbsTol", 1e-12);
end

function test_orr_oer_are_opposites(test_case)
net = test_case.TestData.net;
verifyEqual(test_case, net.S(:, net.idx.ORR), ...
    -net.S(:, net.idx.OER), "AbsTol", 1e-15);
end

function test_her_produces_hydrogen(test_case)
net = test_case.TestData.net;
r = zeros(numel(net.reactions), 1);
r(net.idx.HER) = 1;
q = zeros(numel(net.species), 1);
dn_dt = ironair_species_rates(r, q, net);
verifyEqual(test_case, dn_dt(net.idx.H2), 1, "AbsTol", 1e-15);
verifyEqual(test_case, dn_dt(net.idx.e), -2, "AbsTol", 1e-15);
end

function test_carbonation_consumes_hydroxide(test_case)
net = test_case.TestData.net;
r = zeros(numel(net.reactions), 1);
r(net.idx.carbonation) = 1;
q = zeros(numel(net.species), 1);
dn_dt = ironair_species_rates(r, q, net);
verifyEqual(test_case, dn_dt(net.idx.OH), -2, "AbsTol", 1e-15);
verifyEqual(test_case, dn_dt(net.idx.CO3), 1, "AbsTol", 1e-15);
end

function test_closed_system_element_conservation(test_case)
net = test_case.TestData.net;
n_ref = [10; 10; 0; 3; 30; 1; 0; 0.01; 0; 0; 3];
r = [0.2; 0.01; 0.05; 0.02; 0.01; 0.001];
q = zeros(numel(net.species), 1);
dn_dt = ironair_species_rates(r, q, net);
n_now = n_ref + dn_dt;
diagnostics = ironair_conservation_check(n_now, n_ref, q, net);
verifyTrue(test_case, diagnostics.all_passed);
end
