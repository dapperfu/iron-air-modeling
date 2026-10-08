# Complete Iron-Air MATLAB System

## Delivery principles
- Treat `ChatGPT_Plan.md` as the migration input, then make tracked `.sdoc` files authoritative; do not reuse `cursor_v1` implementation code.
- Keep runtime physics entirely in `.m` files and base MATLAB. StrictDoc is used only to validate/export requirements; generated HTML remains untracked.
- Preserve the specified discharge-positive conventions, one central stoichiometric reaction network, explicit SI units, named state maps, and `[dx, outputs, diagnostics]` component interfaces.
- Use metadata-backed `ASSUMED` or `CALIBRATION_REQUIRED` defaults with applicability/range fields. Reject invalid parameters and never present assumptions as validated commercial data.
- Apply the repository's required single-file atomic commit/push workflow after every created file and prompt-level edit set.

## TODOs
- [x] Save this accepted plan under `plans/`, then track and commit it according to repository rules.
- [x] Create and validate authoritative StrictDoc requirements, trace relations, project scaffolding, state-map utilities, and resolution profiles.
- [x] Implement constants, metadata-rich parameters, property correlations, configuration inheritance, and the canonical reaction/conservation network.
- [x] Implement and verify Level 1-3 electrochemical cell components and all FE through CELL equations.
- [x] Implement and verify thermal, air, hydrogen, electrolyte circulation, and heat-exchanger subsystems.
- [x] Implement and verify stack-to-BESS aggregation, DC bus, converters, inverter, transformer, and protection.
- [x] Implement and verify grid behavior, ride-through, supervisory control, estimation, degradation, sensors, and physical fault injection.
- [x] Assemble the coupled solver and verify all fidelity modes and principal operating/fault scenarios.
- [x] Complete results tooling, documentation, traceability, all-equation tests, conservation/fidelity/tolerance checks, and prohibited-dependency audit.

## Phased implementation

### 0. Requirements and project foundation
- Establish the pure-MATLAB tree: `parameters/`, `properties/`, `components/`, `controls/`, `core/`, `configurations/`, `simulations/`, `scenarios/`, `tests/`, and `docs/`.
- Convert SRS001-SRS024 and all 100 equation IDs into modular StrictDoc sources under `requirements/`, with formal requirement-to-equation-to-implementation-to-test relations and verification status. Add tracked StrictDoc configuration; validate and export through StrictDoc without committing generated HTML.
- Add path/bootstrap, dependency audit, common validation/error helpers, named state-index assembly, deterministic solver options, and `smoke`, `standard`, and `reference` resolution profiles.

### 1. Constants, parameters, properties, and reaction network
- Implement `parameters/ironair_physical_constants.m`, `parameters/ironair_default_parameters.m`, domain parameter builders, metadata/citation registry, inheritance-based configuration profiles, and comprehensive validators.
- Implement all required KOH, gas, iron, thermal, and kinetic property functions with explicit validity ranges and controlled extrapolation.
- Build the canonical species/reaction/element matrices in `core/`, including Fe/FeOH2, optional magnetite, ORR, OER, HER, carbonation, water, charge, and elemental conservation checks.

### 2. Electrochemical cell at three fidelities
- Implement iron, HER, air-electrode, electrolyte, separator, GDL, collector, and cell models at the required paths, retaining every FE/HER/AIR/GDL/ELY/SEP/COL/CELL equation ID in source comments.
- Level 1 uses lumped inventories; Level 2 uses grouped finite volumes; Level 3 uses 1D finite-volume species, potential, oxygen, morphology, porosity, passivation, flooding, and thermal coupling.
- Add bounded stable Butler-Volmer evaluation, custom base-MATLAB nonlinear solves, transport limiting, double-layer dynamics, signed current closure, and diagnostics for infeasible, negative, or nonphysical states.
- Add one standalone simulation and domain-grouped automated tests for every component, including dimensional, sign, boundary, stability, validity, and conservation checks.

### 3. Thermal and balance-of-plant physics
- Implement multinode thermal dynamics, heat exchanger, air/ventilation/H2 dilution, electrolyte reservoir/recirculation/pump/valve/piping, humidity, evaporation, carbonation, makeup, and leak behavior.
- Couple all material and heat flows to the same reaction rates and finite inventories; include auxiliary electrical power and fault-modified physical behavior.
- Verify mass, species, pressure/flow, hydrogen dilution, thermal energy, oxygen starvation, zero-flow, and heat-transfer limits with standalone simulations and tests.

### 4. Hierarchical electrical aggregation
- Implement cell-to-stack-to-module-to-enclosure-to-power-block-to-BESS aggregation with explicit equivalent charge, energy, resistance, power, auxiliary loads, mismatch, current sharing, thermal coupling, representative grouping, sensors, and protection.
- Implement DC bus, bidirectional averaged DC/DC converter, inverter, transformer, current collectors, and electrical protection, preserving DC chemical, DC-bus, AC-terminal, auxiliary, import, and export energy ledgers.
- Add component simulations and tests for topology equations, current/power polarity, limits, losses, transient capacitance, mismatch, and aggregation equivalence.

### 5. Grid, controls, estimation, degradation, and faults
- Implement `components/grid/ironair_grid_model.m` and retain `components/grid/ironair_der_ride_through.m`, using separately versioned illustrative `ASSUMED` category tables, timers, regions, reconnection, and explicit non-certification wording.
- Implement the 18-state supervisory controller with priority, guards, actions, latches, hysteresis, qualification timers, anti-chatter, PI saturation, and anti-windup.
- Implement inventory and observer-mode SOC/SOH estimation without true-state access, plus configurable degradation and all required deterministic physical fault injections with onset, detection, mitigation, and recovery records.
- Verify grid disturbances, transitions, sensor uncertainty, estimator error, degradation monotonicity, and each physical fault mode.

### 6. Coupled solver and system scenarios
- Assemble `core/ironair_system_ode.m` around one state map, stoichiometric mechanism, algebraic closure, mass matrix/J-pattern support, event segmentation, state-specific tolerances, explicit diagnostics, and solver recovery.
- Provide independently executable Level 1/2/3 scripts and principal charge, discharge, rest, direction-switch, 100-hour 1 MW, oxygen-starvation, zero-flow, thermal-extreme, grid-disturbance, degradation, and fault scenarios. All scripts call the same components and accept the three resolution presets without source edits.
- Establish fidelity-reduction comparisons and tolerance-refinement studies; the default `standard` preset balances runtime and accuracy while `smoke` and `reference` define the fast and convergence gates.

### 7. Results, documentation, and completion gates
- Implement structured logging, MAT-file persistence, headless postprocessing, base-MATLAB plots, reports, deterministic seeds, warning/status capture, and complete conservation/energy ledgers.
- Generate the required README and physics, architecture, control, numerics, parameter, scenario, validation, assumption, and traceability Markdown documents from authoritative requirement and model metadata where practical.
- Organize equation tests by domain and make `tests/test_all_equations.m` the aggregate entry point. Add component, integration, scenario, base-MATLAB dependency, source-naming, traceability-coverage, tolerance-refinement, fidelity-reduction, and 100-hour acceptance suites.
- Use MATLAB static analysis and test execution after each phase; finish only when all 100 equation IDs are invoked by production paths, SRS001-SRS024 links are complete, every mandatory conservation check passes, all scenarios reproduce, and no prohibited dependency or stale Simulink asset remains.
