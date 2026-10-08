function tests = test_properties
%TEST_PROPERTIES Verify property correlations, ranges, and signs.
%   Requirements: SRS002.4, SRS005.3, SRS018.
tests = functiontests(localfunctions);
end

function setupOnce(test_case)
root = fileparts(fileparts(mfilename("fullpath")));
addpath(root);
ironair_setup();
test_case.TestData.p = ironair_default_parameters("smoke");
end

function test_conductivity_positive_and_temperature_rising(test_case)
p = test_case.TestData.p;
c = p.electrolyte.c_KOH_initial_mol_m3;
k_low = ironair_KOH_conductivity(c, 298.15, p);
k_high = ironair_KOH_conductivity(c, 333.15, p);
verifyGreaterThan(test_case, k_low, 0);
verifyGreaterThan(test_case, k_high, k_low);
end

function test_density_and_viscosity_signs(test_case)
p = test_case.TestData.p;
rho = ironair_KOH_density(6000, 298.15, p);
mu = ironair_KOH_viscosity(6000, 298.15, p);
cp = ironair_KOH_heat_capacity(6000, 298.15, p);
a_w = ironair_KOH_water_activity(6000, 298.15, p);
verifyGreaterThan(test_case, rho, 900);
verifyGreaterThan(test_case, mu, 0);
verifyGreaterThan(test_case, cp, 1000);
verifyGreaterThan(test_case, a_w, 0);
verifyLessThan(test_case, a_w, 1);
end

function test_oxygen_solubility_salting(test_case)
p = test_case.TestData.p;
H_low = ironair_O2_solubility(2000, 298.15, p);
H_high = ironair_O2_solubility(8000, 298.15, p);
verifyGreaterThan(test_case, H_low, H_high);
verifyGreaterThan(test_case, H_high, 0);
end

function test_diffusivities_and_resistivity(test_case)
p = test_case.TestData.p;
D_liq = ironair_O2_diffusivity(6000, 298.15, p);
D_gas = ironair_gas_diffusivity(298.15, 101325, p);
rho = ironair_iron_electrical_resistivity(298.15, p);
k_fe = ironair_thermal_conductivity("Fe", 298.15, p);
verifyGreaterThan(test_case, D_liq, 0);
verifyGreaterThan(test_case, D_gas, D_liq);
verifyGreaterThan(test_case, rho, 0);
verifyGreaterThan(test_case, k_fe, 1);
end

function test_arrhenius_increases_with_temperature(test_case)
p = test_case.TestData.p;
k_low = ironair_reaction_rate_constant(1, 40000, 298.15, p);
k_high = ironair_reaction_rate_constant(1, 40000, 333.15, p);
verifyGreaterThan(test_case, k_high, k_low);
end

function test_out_of_range_temperature_rejected(test_case)
p = test_case.TestData.p;
verifyError(test_case, @() ironair_KOH_conductivity(6000, 100, p), ...
    "ironair:property:OutsideValidity");
end
