# IRONAIR-MATLAB

Pure base-MATLAB multi-physics model of a grid-connected iron-air battery energy storage system.

Values classified `ASSUMED` or `CALIBRATION_REQUIRED` are runnable research placeholders, not validated commercial data. Ride-through envelopes are illustrative and are not a certification claim.

## Setup

```matlab
cd('c:/projects/iron-air-modeling')
ironair_setup
```

## Default run

```matlab
results = ironair_scenario_discharge("standard");
ironair_generate_report(results);
```

## Principal scenarios

```matlab
ironair_scenario_charge("smoke")
ironair_scenario_discharge("smoke")
ironair_scenario_rest("smoke")
ironair_scenario_direction_switch("smoke")
ironair_scenario_100h_1MW("smoke")
ironair_scenario_oxygen_starvation("smoke")
ironair_scenario_zero_flow("smoke")
ironair_scenario_thermal_extreme("smoke")
ironair_scenario_grid_disturbance("smoke")
ironair_scenario_degradation("smoke")
ironair_scenario_faults("smoke")
```

## Fidelity scripts

```matlab
ironair_sim_level1("smoke")
ironair_sim_level2("smoke")
ironair_sim_level3("smoke")
```

## Tests

```matlab
runtests("tests/test_foundation.m")
runtests("tests/test_all_equations.m")
runtests("tests/test_system_scenarios.m")
runtests("tests")
```

Resolution names `smoke`, `standard`, and `reference` are accepted by every scenario without editing component source.
