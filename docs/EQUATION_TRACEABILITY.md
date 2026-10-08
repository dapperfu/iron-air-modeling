# Equation traceability

| ID | SRS | File | Test |
|---|---|---|---|
| FE-001 to FE-016 | SRS003 | components/electrochemistry/ironair_metal_ode.m | tests/test_equations_electrochemistry.m |
| HER-001 to HER-005 | SRS003.4 | components/electrochemistry/ironair_HER_model.m | tests/test_equations_electrochemistry.m |
| AIR-001 to AIR-009 | SRS004 | components/electrochemistry/ironair_air_electrode_ode.m | tests/test_equations_electrochemistry.m |
| GDL-001 to GDL-006 | SRS006 | components/air/ironair_gas_diffusion_layer.m | tests/test_equations_electrochemistry.m |
| ELY-001 to ELY-015 | SRS005 | components/electrolyte/ironair_electrolyte_ode.m | tests/test_equations_electrochemistry.m |
| SEP-001 to SEP-004 | SRS006 | components/separator/ironair_separator_model.m | tests/test_equations_electrochemistry.m |
| COL-001 to COL-004 | SRS007 | components/electrical/ironair_current_collector.m | tests/test_equations_electrochemistry.m |
| CELL-001 to CELL-010 | SRS007 | components/cell/ironair_cell_model.m | tests/test_equations_electrochemistry.m |
| THM-001 to THM-009 | SRS008 | components/thermal/ironair_thermal_ode.m | tests/test_equations_balance_of_plant.m |
| AIRSYS-001 to AIRSYS-010 | SRS009 | components/air/ironair_air_system_ode.m | tests/test_equations_balance_of_plant.m |
| FLD-001 to FLD-010 | SRS010 | components/fluids/ironair_electrolyte_flow_ode.m | tests/test_equations_balance_of_plant.m |
| HEX-001 to HEX-004 | SRS008 | components/thermal/ironair_heat_exchanger.m | tests/test_equations_balance_of_plant.m |
| STK-001 to STK-006 | SRS011 | components/stack/ironair_stack_model.m | tests/test_equations_electrical.m |
| MOD-001 to MOD-005 | SRS011 | components/module/ironair_module_model.m | tests/test_equations_electrical.m |
| DC-001 to DC-004 | SRS012 | components/electrical/ironair_dc_bus_ode.m | tests/test_equations_electrical.m |
| CONV-001 to CONV-006 | SRS012 | components/electrical/ironair_dcdc_converter.m | tests/test_equations_electrical.m |
| INV-001 to INV-007 | SRS012 | components/electrical/ironair_inverter.m | tests/test_equations_electrical.m |
| TRF-001 to TRF-004 | SRS012 | components/electrical/ironair_transformer.m | tests/test_equations_electrical.m |
| GRID-001 to GRID-006 | SRS013 | components/grid/ironair_grid_model.m | tests/test_equations_controls_grid.m |
| CTRL-001 to CTRL-006 | SRS014 | controls/ironair_supervisory_controller.m | tests/test_equations_controls_grid.m |
| EST-001 to EST-006 | SRS015 | controls/ironair_state_estimator.m | tests/test_equations_controls_grid.m |
| DEG-001 to DEG-006 | SRS016 | components/degradation/ironair_degradation_ode.m | tests/test_equations_controls_grid.m |
| FLT-001 to FLT-006 | SRS017 | components/faults/ironair_fault_injection.m | tests/test_equations_controls_grid.m |
| SYS-001 to SYS-007 | SRS018/023 | core/ironair_system_ode.m | tests/test_system_scenarios.m |

Verification status for the rows above is **passed** against `tests/test_all_equations.m` on the smoke configuration. Coefficients that are not fundamental constants are tagged `ASSUMED` or `CALIBRATION_REQUIRED` in `parameters/ironair_parameter_catalog.m`. They are development values, not validated commercial battery data.

Internal units are mol/m3, K, Pa, A, J, and W. Discharge current is positive. `P_cell = V_cell .* I_cell`.

| ID | SRS | Function | Class | States | Assumptions |
|---|---|---|---|---|---|
| FE-001 | SRS003.1 | ironair_metal_ode | conservation law | n_Fe, n_FeOH2 | oxidation positive on discharge |
| FE-002 | SRS003.1 | ironair_metal_ode | constitutive equation | e_Fe_eq | pure solids at unit activity |
| FE-003 | SRS003.2 | ironair_butler_volmer | constitutive equation | j_Fe | exponents clipped at ±40 |
| FE-004 | SRS003.2 | ironair_metal_ode | constitutive equation | eta_Fe | eta = phi_s - phi_l - e_eq |
| FE-005 | SRS003.2 | ironair_metal_ode | constitutive equation | I_Fe | I = A * j |
| FE-006 | SRS003.2 | ironair_reaction_rate_constant | constitutive equation | j_0_Fe_T | Arrhenius about T_ref |
| FE-007 | SRS003.3 | ironair_metal_ode | conservation law | n_Fe | Faraday, n_e = 2 |
| FE-008 | SRS003.3 | ironair_metal_ode | conservation law | n_FeOH2 | Faraday, n_e = 2 |
| FE-009 | SRS003.3 | ironair_metal_ode | constitutive equation | U_Fe | initial metallic inventory |
| FE-010 | SRS003.3 | ironair_metal_ode | constitutive equation | epsilon_Fe | includes inert solid volume |
| FE-011 | SRS003.3 | ironair_metal_ode | constitutive equation | A_active_Fe | a_s is dimensionless |
| FE-012 | SRS003.3 | ironair_metal_ode | empirical approximation | delta_pass | CALIBRATION_REQUIRED |
| FE-013 | SRS003.3 | ironair_metal_ode | constitutive equation | R_pass | film resistance |
| FE-014 | SRS003.1 | ironair_reaction_network | conservation law | n_Fe3O4 | optional, separately parameterized |
| FE-015 | SRS003.3 | ironair_metal_ode | conservation law | n_Fe3O4 | Faraday, n_e = 2 |
| FE-016 | SRS003.3 | ironair_metal_ode | conservation law | n_FeOH2 | three hydroxide per magnetite |
| HER-001 | SRS003.4 | ironair_HER_model | conservation law | n_H2 | cathodic branch |
| HER-002 | SRS003.4 | ironair_HER_model | empirical approximation | j_HER | one-electron kinetic form |
| HER-003 | SRS003.4 | ironair_HER_model | conservation law | n_H2 | I_HER <= 0 |
| HER-004 | SRS003.4 | ironair_HER_model | constitutive equation | eta_F_charge | idle ratio is 1 |
| HER-005 | SRS003.4 | ironair_HER_model | conservation law | n_H2 | vent and dissolution |
| AIR-001 | SRS004.1 | ironair_air_electrode_ode | conservation law | n_O2 | cathodic partial current |
| AIR-002 | SRS004.2 | ironair_air_electrode_ode | conservation law | n_O2 | anodic partial current |
| AIR-003 | SRS004.1 | ironair_air_electrode_ode | constitutive equation | e_O2_eq | consistent reference state |
| AIR-004 | SRS004.1 | ironair_air_electrode_ode | constitutive equation | j_ORR | anodic branch excluded |
| AIR-005 | SRS004.2 | ironair_air_electrode_ode | constitutive equation | j_OER | independent kinetics |
| AIR-006 | SRS004.1 | ironair_air_electrode_ode | conservation law | n_O2 | positive consumption when I_ORR < 0 |
| AIR-007 | SRS004.2 | ironair_air_electrode_ode | conservation law | n_O2 | Faraday, n_e = 4 |
| AIR-008 | SRS004.4 | ironair_air_electrode_ode | constitutive equation | j_lim_O2 | positive magnitude |
| AIR-009 | SRS004.4 | ironair_air_electrode_ode | empirical approximation | eta_conc | domain |j| < j_lim |
| GDL-001 | SRS006 | ironair_gas_diffusion_layer | constitutive equation | N_O2 | Fickian flux |
| GDL-002 | SRS006 | ironair_gas_diffusion_layer | constitutive equation | D_O2_eff | Bruggeman-style epsilon/tau |
| GDL-003 | SRS006 | ironair_finite_volume_1d | conservation law | c_O2 | finite volume, not a built-in div |
| GDL-004 | SRS006 | ironair_gas_diffusion_layer | constitutive equation | p_capillary | p_gas - p_liquid |
| GDL-005 | SRS006 | ironair_gas_diffusion_layer | constitutive equation | p_capillary | Young-Laplace |
| GDL-006 | SRS006 | ironair_gas_diffusion_layer | empirical approximation | D_O2_eff | saturation-dependent |
| ELY-001 | SRS005.1 | ironair_finite_volume_1d | constitutive equation | N_i | dilute Nernst-Planck |
| ELY-002 | SRS005.1 | ironair_electrolyte_ode | conservation law | c_i | product rule when volume varies |
| ELY-003 | SRS005.1 | ironair_electrolyte_ode | conservation law | c_K, c_OH, c_CO3 | algebraic electroneutrality |
| ELY-004 | SRS005.1 | ironair_electrolyte_ode | constitutive equation | i_electrolyte | sum over species |
| ELY-005 | SRS005.1 | ironair_electrolyte_ode | conservation law | div_i | equals a_s * j_F |
| ELY-006 | SRS005.3 | ironair_KOH_conductivity | empirical approximation | kappa_KOH | CALIBRATION_REQUIRED |
| ELY-007 | SRS005.3 | ironair_electrolyte_ode | constitutive equation | R_electrolyte | ohmic length |
| ELY-008 | SRS005.1 | ironair_electrolyte_ode | conservation law | n_K | boundary flows only |
| ELY-009 | SRS005.2 | ironair_reaction_network | conservation law | n_CO3 | carbonation stoichiometry |
| ELY-010 | SRS005.2 | ironair_electrolyte_ode | empirical approximation | r_carbonation | CALIBRATION_REQUIRED |
| ELY-011 | SRS005.4 | ironair_species_rates | conservation law | n_H2O | stoichiometric water row |
| ELY-012 | SRS005.3 | ironair_KOH_density | empirical approximation | rho_KOH | CALIBRATION_REQUIRED |
| ELY-013 | SRS005.3 | ironair_KOH_viscosity | empirical approximation | mu_KOH | CALIBRATION_REQUIRED |
| ELY-014 | SRS005.3 | ironair_O2_solubility | constitutive equation | c_O2_eq | Henry, mol/(m3 Pa) |
| ELY-015 | SRS005.1 | ironair_electrolyte_ode | constitutive equation | n_O2 | k_L a transfer |
| SEP-001 | SRS006 | ironair_separator_model | constitutive equation | R_separator | none |
| SEP-002 | SRS006 | ironair_separator_model | constitutive equation | kappa_separator | epsilon/tau |
| SEP-003 | SRS006 | ironair_separator_model | constitutive equation | J_i | diffusion plus optional migration |
| SEP-004 | SRS006 | ironair_separator_model | constitutive equation | Q_dot | conduction |
| COL-001 | SRS007 | ironair_current_collector | constitutive equation | R_collector | geometry |
| COL-002 | SRS007 | ironair_current_collector | constitutive equation | V_drop | Ohm's law |
| COL-003 | SRS007 | ironair_current_collector | constitutive equation | Q_dot | Joule heating |
| COL-004 | SRS007 | ironair_current_collector | empirical approximation | R_collector_T | linear alpha |
| CELL-001 | SRS007.1 | ironair_cell_model | constitutive equation | e_cell_eq | air minus iron |
| CELL-002 | SRS007.1 | ironair_cell_model | constitutive equation | V_cell | discharge-positive losses |
| CELL-003 | SRS007.1 | ironair_cell_model | constitutive equation | P_cell | V * I |
| CELL-004 | SRS007.2 | ironair_cell_model | conservation law | Q_throughput | absolute ampere-seconds |
| CELL-005 | SRS007.2 | ironair_cell_model | constitutive equation | Q_Fe | 2 F n_Fe |
| CELL-006 | SRS007.2 | ironair_cell_model | constitutive equation | SOC | primary Fe/FeOH2 inventory |
| CELL-007 | SRS007.2 | ironair_cell_model | constitutive equation | eta_C | matched cycle totals |
| CELL-008 | SRS007.2 | ironair_cell_model | constitutive equation | eta_E | trapz of positive powers |
| CELL-009 | SRS007.4 | ironair_cell_model | constitutive equation | eta_dl | includes de_eq/dt |
| CELL-010 | SRS007.1 | ironair_cell_model | constitutive equation | R_ohmic | five resistance terms |
| THM-001 | SRS008 | ironair_thermal_ode | conservation law | T_cell | lumped capacitance |
| THM-002 | SRS008 | ironair_thermal_ode | constitutive equation | Q_ohmic | I^2 R |
| THM-003 | SRS008 | ironair_thermal_ode | constitutive equation | Q_activation | sum of j*eta*A |
| THM-004 | SRS008 | ironair_thermal_ode | constitutive equation | Q_reversible | T * de_eq/dT |
| THM-005 | SRS008 | ironair_thermal_ode | constitutive equation | Q_conduction | conductance form |
| THM-006 | SRS008 | ironair_thermal_ode | constitutive equation | Q_convection | Newton's law |
| THM-007 | SRS008 | ironair_thermal_ode | constitutive equation | Q_radiation | Stefan-Boltzmann |
| THM-008 | SRS008 | ironair_thermal_ode | constitutive equation | Q_coolant | stream enthalpy rise |
| THM-009 | SRS008 | ironair_thermal_ode | conservation law | T_node | three-node network |
| AIRSYS-001 | SRS009 | ironair_air_system_ode | constitutive equation | p_gas | ideal gas residual |
| AIRSYS-002 | SRS009 | ironair_air_system_ode | constitutive equation | p_O2 | dry-air partial pressure |
| AIRSYS-003 | SRS009 | ironair_air_system_ode | constitutive equation | n_O2 | inlet mole fraction |
| AIRSYS-004 | SRS009 | ironair_air_system_ode | conservation law | n_O2 | ORR, OER, and transfer |
| AIRSYS-005 | SRS009 | ironair_air_system_ode | constitutive equation | P_fan_shaft | hydraulic power |
| AIRSYS-006 | SRS009 | ironair_air_system_ode | constitutive equation | P_fan_electric | motor efficiency |
| AIRSYS-007 | SRS009 | ironair_air_system_ode | empirical approximation | N_fan | fan similarity laws |
| AIRSYS-008 | SRS009 | ironair_air_system_ode | empirical approximation | delta_p_filter | linear plus quadratic |
| AIRSYS-009 | SRS009 | ironair_air_system_ode | constitutive equation | lambda_O2 | undefined below 1e-9 mol/s |
| AIRSYS-010 | SRS009 | ironair_air_system_ode | control law | N_fan | first-order lag |
| FLD-001 | SRS010 | ironair_electrolyte_flow_ode | conservation law | V_reservoir | closed loop cancels through-flow |
| FLD-002 | SRS010 | ironair_electrolyte_flow_ode | constitutive equation | P_hydraulic | delta_p * Q |
| FLD-003 | SRS010 | ironair_electrolyte_flow_ode | constitutive equation | P_electric | pump and motor efficiency |
| FLD-004 | SRS010 | ironair_electrolyte_flow_ode | constitutive equation | Re | pipe Reynolds number |
| FLD-005 | SRS010 | ironair_electrolyte_flow_ode | constitutive equation | delta_p_pipe | Darcy-Weisbach |
| FLD-006 | SRS010 | ironair_electrolyte_flow_ode | constitutive equation | f_Darcy | 64/Re for laminar pipe flow |
| FLD-007 | SRS010 | ironair_electrolyte_flow_ode | empirical approximation | delta_p_minor | loss coefficients |
| FLD-008 | SRS010 | ironair_electrolyte_flow_ode | conservation law | c_tank | product rule |
| FLD-009 | SRS010 | ironair_electrolyte_flow_ode | conservation law | omega_pump | rotational dynamics |
| FLD-010 | SRS010 | ironair_electrolyte_flow_ode | constitutive equation | Q_valve | orifice law |
| HEX-001 | SRS008 | ironair_heat_exchanger | constitutive equation | Q_HX | U A LMTD |
| HEX-002 | SRS008 | ironair_log_mean_delta_T | constitutive equation | delta_T_lm | arithmetic limit when ends match |
| HEX-003 | SRS008 | ironair_heat_exchanger | constitutive equation | epsilon_HX | actual over maximum |
| HEX-004 | SRS008 | ironair_heat_exchanger | constitutive equation | NTU | UA / C_min |
| STK-001 | SRS011 | ironair_stack_model | constitutive equation | V_stack | series sum |
| STK-002 | SRS011 | ironair_stack_model | conservation law | I_string | no shunt branches |
| STK-003 | SRS011 | ironair_stack_model | conservation law | I_stack | parallel sum |
| STK-004 | SRS011 | ironair_stack_model | constitutive equation | V_nominal | N_series * V_nominal |
| STK-005 | SRS011 | ironair_stack_model | constitutive equation | P_stack | V * I |
| STK-006 | SRS011 | ironair_stack_model | empirical approximation | I_string_k | linear Thevenin |
| MOD-001 | SRS011 | ironair_module_model | constitutive equation | P_module | stack sum |
| MOD-002 | SRS011 | ironair_module_model | constitutive equation | P_net | auxiliaries subtracted |
| MOD-003 | SRS011 | ironair_enclosure_model | conservation law | T_enclosure | HVAC and ambient |
| MOD-004 | SRS011 | ironair_module_model | constitutive equation | P_aux | fan, pump, HVAC, controls |
| MOD-005 | SRS011 | ironair_module_model | conservation law | E_stored | chemical, thermal, electric, kinetic |
| DC-001 | SRS012 | ironair_dc_bus_ode | conservation law | V_dc | capacitor current |
| DC-002 | SRS012 | ironair_dc_bus_ode | constitutive equation | E_dc | 1/2 C V^2 |
| DC-003 | SRS012 | ironair_dc_bus_ode | conservation law | E_dc | V * I_bus |
| DC-004 | SRS012 | ironair_dc_bus_ode | constitutive equation | P_loss | I^2 R |
| CONV-001 | SRS012 | ironair_dcdc_converter | constitutive equation | i_L | buck or boost by voltage ratio |
| CONV-002 | SRS012 | ironair_dcdc_converter | conservation law | V_out | capacitor form matches topology |
| CONV-003 | SRS012 | ironair_dcdc_converter | conservation law | power residual | reported, includes switching loss |
| CONV-004 | SRS012 | ironair_dcdc_converter | constitutive equation | P_conduction | I_rms^2 R |
| CONV-005 | SRS012 | ironair_dcdc_converter | empirical approximation | P_switching | f * (E_on + E_off) |
| CONV-006 | SRS012 | ironair_dcdc_converter | constitutive equation | eta | positive power magnitudes |
| INV-001 | SRS012 | ironair_inverter | constitutive equation | P_AC | three-phase |
| INV-002 | SRS012 | ironair_inverter | constitutive equation | Q_AC | three-phase |
| INV-003 | SRS012 | ironair_inverter | constitutive equation | S_AC | apparent power |
| INV-004 | SRS012 | ironair_inverter | conservation law | P_DC | AC plus loss |
| INV-005 | SRS012 | ironair_pi_antiwindup | control law | integral_e_P | anti-windup |
| INV-006 | SRS012 | ironair_pi_antiwindup | control law | integral_e_Q | uses e_Q |
| INV-007 | SRS012 | ironair_inverter | control law | S_AC | scaled inside S_rated |
| TRF-001 | SRS012 | ironair_transformer | constitutive equation | V_secondary | ideal turns ratio |
| TRF-002 | SRS012 | ironair_transformer | constitutive equation | P_copper | both windings |
| TRF-003 | SRS012 | ironair_transformer | empirical approximation | P_core | Steinmetz |
| TRF-004 | SRS008 | ironair_transformer | conservation law | T_transformer | lumped thermal |
| GRID-001 | SRS013 | ironair_grid_model | constitutive equation | delta_f | f - f_nominal |
| GRID-002 | SRS013 | ironair_grid_model | control law | P_command | sign is configurable |
| GRID-003 | SRS013 | ironair_grid_model | control law | Q_command | deadband |
| GRID-004 | SRS013 | ironair_grid_model | control law | dP/dt | ramp limits |
| GRID-005 | SRS013 | ironair_grid_model | constitutive equation | V_pu | measured over base |
| GRID-006 | SRS013 | ironair_der_ride_through | control law | t_violation | illustrative, not a certification |
| CTRL-001 | SRS014 | ironair_supervisory_controller | control law | SOC_valid | inclusive window |
| CTRL-002 | SRS014 | ironair_supervisory_controller | control law | P_charge | nonnegative magnitudes |
| CTRL-003 | SRS014 | ironair_supervisory_controller | control law | P_discharge | nonnegative magnitudes |
| CTRL-004 | SRS014 | ironair_pi_antiwindup | control law | integral_e_I | anti-windup |
| CTRL-005 | SRS014 | ironair_supervisory_controller | control law | f_thermal | configurable derate |
| CTRL-006 | SRS014 | ironair_supervisory_controller | control law | allow_transition | four readiness flags |
| EST-001 | SRS015 | ironair_state_estimator | constitutive equation | SOC_hat | not integrated as plant SOC |
| EST-002 | SRS015 | ironair_state_estimator | control law | x_hat | observer dimensions preserved |
| EST-003 | SRS015 | ironair_discrete_state_model | constitutive equation | x_hat_pred | forward Euler |
| EST-004 | SRS015 | ironair_state_estimator | control law | K_EKF | matrix division |
| EST-005 | SRS015 | ironair_state_estimator | control law | x_hat | correction |
| EST-006 | SRS015 | ironair_state_estimator | constitutive equation | SOH | capacity ratio |
| DEG-001 | SRS016 | ironair_degradation_ode | empirical approximation | k_aging | Arrhenius, CALIBRATION_REQUIRED |
| DEG-002 | SRS016 | ironair_degradation_ode | empirical approximation | f_area | first-order area loss |
| DEG-003 | SRS016 | ironair_degradation_ode | empirical approximation | a_catalyst | applied to air activities |
| DEG-004 | SRS016 | ironair_degradation_ode | empirical approximation | R_extra | temperature, SOC, current |
| DEG-005 | SRS016 | ironair_degradation_ode | conservation law | n_Fe_inactive | subtracted once from metallic iron |
| DEG-006 | SRS016 | ironair_degradation_ode | constitutive equation | Q_usable | not double-counted |
| FLT-001 | SRS017 | ironair_fault_injection | empirical approximation | y_measured | bias plus noise |
| FLT-002 | SRS017 | ironair_fault_injection | constitutive equation | y_sensor | first-order lag |
| FLT-003 | SRS017 | ironair_fault_injection | empirical approximation | bias | constant drift rate |
| FLT-004 | SRS017 | ironair_fault_injection | conservation law | V_electrolyte | leak is a volumetric sink |
| FLT-005 | SRS017 | ironair_fault_injection | control law | N_fan | failed command is zero |
| FLT-006 | SRS017 | ironair_fault_injection | constitutive equation | I_short | consistent with R_int and R_fault |
| SYS-001 | SRS023 | ironair_species_rates | conservation law | n_species | one stoichiometric matrix |
| SYS-002 | SRS023 | ironair_reaction_network | conservation law | elements | inf-norm residual |
| SYS-003 | SRS023 | ironair_system_ode | conservation law | I_node | Kirchhoff residual |
| SYS-004 | SRS019 | ironair_system_ode | conservation law | U_system | open-system ledger |
| SYS-005 | SRS023 | ironair_system_ode | constitutive equation | eta_AC | includes auxiliary loads |
| SYS-006 | SRS018 | ironair_system_mass_matrix | constitutive equation | x | identity mass matrix for ode15s |
| SYS-007 | SRS018 | ironair_system_ode | conservation law | e_algebraic | reported residuals |
