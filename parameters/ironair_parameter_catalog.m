function p = ironair_parameter_catalog(group_name)
%IRONAIR_PARAMETER_CATALOG Return one metadata-backed parameter group.
%   P = IRONAIR_PARAMETER_CATALOG(GROUP_NAME) returns numeric fields used by
%   governing equations and a parallel P.meta structure. Values in this
%   development catalog are explicitly ASSUMED or CALIBRATION_REQUIRED and
%   are not validated commercial battery data.
%
%   Input:
%     group_name - Supported component parameter group.
%
%   Output:
%     p - Scalar structure containing numeric/logical values and metadata.
%
%   Units: recorded per field in p.meta.
%   Requirements: SRS002.2, SRS002.3, SRS021, SRS022.

arguments
    group_name (1, 1) string
end

switch group_name
    case "iron_electrode"
        p = group_iron_electrode();
    case "iron_phases"
        p = group_iron_phases();
    case "air_electrode"
        p = group_air_electrode();
    case "orr_catalyst"
        p = group_orr_catalyst();
    case "oer_catalyst"
        p = group_oer_catalyst();
    case "hydrogen_evolution"
        p = group_hydrogen_evolution();
    case "electrolyte"
        p = group_electrolyte();
    case "separator"
        p = group_separator();
    case "gas_diffusion_layer"
        p = group_gas_diffusion_layer();
    case "current_collectors"
        p = group_current_collectors();
    case "cell_geometry"
        p = group_cell_geometry();
    case "thermal_properties"
        p = group_thermal_properties();
    case "gas_properties"
        p = group_gas_properties();
    case "liquid_transport"
        p = group_liquid_transport();
    case "electrolyte_circulation"
        p = group_electrolyte_circulation();
    case "pumps"
        p = group_pumps();
    case "fans"
        p = group_fans();
    case "valves"
        p = group_valves();
    case "heat_exchanger"
        p = group_heat_exchanger();
    case "reservoir"
        p = group_reservoir();
    case "piping"
        p = group_piping();
    case "stack"
        p = group_stack();
    case "module"
        p = group_module();
    case "enclosure"
        p = group_enclosure();
    case "dc_bus"
        p = group_dc_bus();
    case "dcdc_converter"
        p = group_dcdc_converter();
    case "inverter"
        p = group_inverter();
    case "transformer"
        p = group_transformer();
    case "electrical_protection"
        p = group_electrical_protection();
    case "sensors"
        p = group_sensors();
    case "supervisory_controls"
        p = group_supervisory_controls();
    case "grid"
        p = group_grid();
    case "aging_degradation"
        p = group_aging_degradation();
    case "fault_detection"
        p = group_fault_detection();
    otherwise
        error("ironair:parameter:UnknownGroup", ...
            "Unknown parameter group: %s", group_name);
end
p.group_name = group_name;
end

function p = group_iron_electrode()
p = empty_group();
p = put(p, "e_Fe_std_V", -0.85, "V", "ASSUMED", [-1.2, -0.4]);
p = put(p, "j_0_Fe_ref_A_m2", 2, "A/m2", "CALIBRATION_REQUIRED", [1e-6, 1e4]);
p = put(p, "E_a_Fe_J_mol", 35000, "J/mol", "CALIBRATION_REQUIRED", [0, 1e5]);
p = put(p, "alpha_a_Fe", 0.5, "1", "ASSUMED", [0.05, 0.95]);
p = put(p, "alpha_c_Fe", 0.5, "1", "ASSUMED", [0.05, 0.95]);
p = put(p, "A_geometric_Fe_m2", 0.1, "m2", "ASSUMED", [1e-4, 100]);
p = put(p, "a_s_Fe", 20, "1", "ASSUMED", [0.01, 1e4]);
p = put(p, "sigma_pass_S_m", 1e-5, "S/m", "CALIBRATION_REQUIRED", [1e-12, 1]);
p = put(p, "k_pass_growth_m_s", 1e-12, "m/s", "CALIBRATION_REQUIRED", [0, 1e-6]);
p = put(p, "k_pass_removal_m_s", 2e-13, "m/s", "CALIBRATION_REQUIRED", [0, 1e-6]);
p = put(p, "m_pass", 1, "1", "ASSUMED", [0.1, 4]);
p = put(p, "k_corrosion_mol_s", 1e-10, "mol/s", "CALIBRATION_REQUIRED", [0, 1e-3]);
p = put(p, "C_dl_Fe_F", 10, "F", "ASSUMED", [0, 1e6]);
p = put(p, "rho_Fe_ref_Ohm_m", 9.71e-8, "Ohm m", "ASSUMED", [1e-9, 1e-4]);
p = put(p, "alpha_rho_Fe_1_K", 0.0065, "1/K", "ASSUMED", [0, 0.02]);
end

function p = group_iron_phases()
p = empty_group();
p = put(p, "V_m_Fe_m3_mol", 7.09e-6, "m3/mol", "LITERATURE", [5e-6, 1e-5], "MATWEB-FE-DENSITY");
p = put(p, "V_m_FeOH2_m3_mol", 2.60e-5, "m3/mol", "ASSUMED", [1e-5, 1e-4]);
p = put(p, "V_m_Fe3O4_m3_mol", 4.45e-5, "m3/mol", "ASSUMED", [2e-5, 1e-4]);
p = put(p, "e_mag_std_V", -0.76, "V", "ASSUMED", [-1.2, -0.2]);
p = put(p, "j_0_mag_A_m2", 0.02, "A/m2", "CALIBRATION_REQUIRED", [0, 1e3]);
p = put(p, "enable_magnetite", true, "1", "ASSUMED", [0, 1]);
p = put(p, "enable_higher_oxide", false, "1", "ASSUMED", [0, 1]);
end

function p = group_air_electrode()
p = empty_group();
p = put(p, "e_O2_std_V", 0.40, "V", "ASSUMED", [0.1, 1.3]);
p = put(p, "A_geometric_air_m2", 0.1, "m2", "ASSUMED", [1e-4, 100]);
p = put(p, "C_dl_air_F", 10, "F", "ASSUMED", [0, 1e6]);
p = put(p, "k_L_a_1_s", 0.02, "1/s", "CALIBRATION_REQUIRED", [0, 100]);
p = put(p, "flooding_initial", 0.1, "1", "ASSUMED", [0, 1]);
p = put(p, "k_flood_1_s", 1e-7, "1/s", "CALIBRATION_REQUIRED", [0, 1]);
p = put(p, "k_dry_1_s", 1e-7, "1/s", "CALIBRATION_REQUIRED", [0, 1]);
p = put(p, "configuration_code", 1, "1", "ASSUMED", [1, 2]);
end

function p = group_orr_catalyst()
p = catalyst_group(0.05, 25000, 0.5, 0.5);
p.n_eff_ORR = 1;
p.meta.n_eff_ORR = meta("1", "ASSUMED", [0.1, 4], "ORR effective rate-determining transfer");
end

function p = group_oer_catalyst()
p = catalyst_group(0.01, 30000, 0.5, 0.5);
p.n_eff_OER = 1;
p.meta.n_eff_OER = meta("1", "ASSUMED", [0.1, 4], "OER effective rate-determining transfer");
end

function p = catalyst_group(j_0, activation_energy, alpha_a, alpha_c)
p = empty_group();
p = put(p, "j_0_ref_A_m2", j_0, "A/m2", "CALIBRATION_REQUIRED", [1e-9, 1e4]);
p = put(p, "E_a_J_mol", activation_energy, "J/mol", "CALIBRATION_REQUIRED", [0, 2e5]);
p = put(p, "alpha_a", alpha_a, "1", "ASSUMED", [0.05, 0.95]);
p = put(p, "alpha_c", alpha_c, "1", "ASSUMED", [0.05, 0.95]);
p = put(p, "activity_initial", 1, "1", "ASSUMED", [0, 1]);
end

function p = group_hydrogen_evolution()
p = empty_group();
p = put(p, "e_HER_eq_V", -0.83, "V", "ASSUMED", [-1.5, 0]);
p = put(p, "j_0_HER_ref_A_m2", 1e-3, "A/m2", "CALIBRATION_REQUIRED", [1e-12, 1e3]);
p = put(p, "E_a_HER_J_mol", 30000, "J/mol", "CALIBRATION_REQUIRED", [0, 2e5]);
p = put(p, "alpha_a_HER", 0.5, "1", "ASSUMED", [0.05, 0.95]);
p = put(p, "alpha_c_HER", 0.5, "1", "ASSUMED", [0.05, 0.95]);
p = put(p, "water_activity_min", 0.05, "1", "ASSUMED", [0, 1]);
end

function p = group_electrolyte()
p = empty_group();
p = put(p, "c_KOH_initial_mol_m3", 6000, "mol/m3", "ASSUMED", [500, 12000]);
p = put(p, "c_OH_initial_mol_m3", 6000, "mol/m3", "ASSUMED", [0, 15000]);
p = put(p, "c_K_initial_mol_m3", 6000, "mol/m3", "ASSUMED", [0, 15000]);
p = put(p, "c_O2_initial_mol_m3", 0.4, "mol/m3", "ASSUMED", [0, 10]);
p = put(p, "c_CO2_initial_mol_m3", 1e-4, "mol/m3", "ASSUMED", [0, 100]);
p = put(p, "c_CO3_initial_mol_m3", 0, "mol/m3", "ASSUMED", [0, 10000]);
p = put(p, "n_H2O_initial_mol", 30, "mol", "ASSUMED", [0.01, 1e6]);
p = put(p, "V_electrolyte_initial_m3", 5e-4, "m3", "ASSUMED", [1e-6, 1e3]);
p = put(p, "k_carbonation_m3_mol_s", 1e-7, "m3/(mol s)", "CALIBRATION_REQUIRED", [0, 1]);
p = put(p, "m_carbonation", 1, "1", "ASSUMED", [0.1, 4]);
p = put(p, "extrapolation_policy_code", 0, "1", "ASSUMED", [0, 1]);
p = put(p, "c_property_ref_mol_m3", 6000, "mol/m3", "ASSUMED", [500, 12000]);
p = put(p, "kappa_ref_S_m", 25, "S/m", "CALIBRATION_REQUIRED", [0.1, 200]);
p = put(p, "kappa_temp_coeff_1_K", 0.02, "1/K", "CALIBRATION_REQUIRED", [0, 0.1]);
p = put(p, "rho_water_ref_kg_m3", 997, "kg/m3", "REFERENCE_CONDITION", [900, 1200]);
p = put(p, "rho_c_coeff_kg_mol", 0.045, "kg/mol", "CALIBRATION_REQUIRED", [0, 0.2]);
p = put(p, "rho_temp_coeff_kg_m3K", 0.3, "kg/(m3 K)", "CALIBRATION_REQUIRED", [0, 2]);
p = put(p, "mu_ref_Pa_s", 1e-3, "Pa s", "REFERENCE_CONDITION", [1e-4, 1]);
p = put(p, "mu_c_coeff_m3_mol", 1.8e-4, "m3/mol", "CALIBRATION_REQUIRED", [0, 1e-3]);
p = put(p, "mu_temp_coeff_1_K", 0.025, "1/K", "CALIBRATION_REQUIRED", [0, 0.1]);
p = put(p, "cp_water_ref_J_kgK", 4180, "J/(kg K)", "REFERENCE_CONDITION", [3000, 5000]);
p = put(p, "cp_c_coeff_J_m3_kgK_mol", 0.25, "J m3/(kg K mol)", "CALIBRATION_REQUIRED", [0, 1]);
p = put(p, "water_activity_coeff_m3_mol", 1.7e-4, "m3/mol", "CALIBRATION_REQUIRED", [0, 1e-3]);
p = put(p, "T_property_min_K", 273.15, "K", "ASSUMED", [200, 400]);
p = put(p, "T_property_max_K", 353.15, "K", "ASSUMED", [250, 500]);
p = put(p, "c_property_min_mol_m3", 500, "mol/m3", "ASSUMED", [0, 12000]);
p = put(p, "c_property_max_mol_m3", 12000, "mol/m3", "ASSUMED", [500, 20000]);
end

function p = group_separator()
p = empty_group();
p = put(p, "L_separator_m", 5e-4, "m", "ASSUMED", [1e-6, 0.1]);
p = put(p, "A_separator_m2", 0.1, "m2", "ASSUMED", [1e-4, 100]);
p = put(p, "epsilon_separator", 0.5, "1", "ASSUMED", [0.01, 0.95]);
p = put(p, "tau_separator", 2.5, "1", "ASSUMED", [1, 100]);
p = put(p, "k_separator_W_mK", 0.4, "W/(m K)", "ASSUMED", [0.01, 10]);
p = put(p, "D_crossover_m2_s", 1e-10, "m2/s", "CALIBRATION_REQUIRED", [0, 1e-7]);
p = put(p, "leakage_conductance_S", 1e-8, "S", "CALIBRATION_REQUIRED", [0, 1]);
end

function p = group_gas_diffusion_layer()
p = empty_group();
p = put(p, "L_gdl_m", 5e-4, "m", "ASSUMED", [1e-6, 0.1]);
p = put(p, "epsilon_g", 0.7, "1", "ASSUMED", [0.01, 0.95]);
p = put(p, "tau_g", 2, "1", "ASSUMED", [1, 100]);
p = put(p, "r_pore_m", 20e-6, "m", "ASSUMED", [1e-9, 1e-2]);
p = put(p, "theta_contact_rad", 2.0, "rad", "ASSUMED", [0, pi]);
p = put(p, "gamma_surface_N_m", 0.075, "N/m", "ASSUMED", [0.01, 0.2]);
p = put(p, "permeability_m2", 1e-11, "m2", "CALIBRATION_REQUIRED", [1e-18, 1e-6]);
end

function p = group_current_collectors()
p = empty_group();
p = put(p, "rho_e_ref_Ohm_m", 1.7e-8, "Ohm m", "ASSUMED", [1e-9, 1e-4]);
p = put(p, "L_collector_m", 0.2, "m", "ASSUMED", [1e-3, 10]);
p = put(p, "A_collector_m2", 1e-4, "m2", "ASSUMED", [1e-8, 1]);
p = put(p, "alpha_R_1_K", 0.0039, "1/K", "ASSUMED", [0, 0.02]);
p = put(p, "R_contact_Ohm", 1e-3, "Ohm", "ASSUMED", [0, 10]);
end

function p = group_cell_geometry()
p = empty_group();
p = put(p, "V_electrode_m3", 5e-4, "m3", "ASSUMED", [1e-8, 10]);
p = put(p, "L_electrolyte_m", 2e-3, "m", "ASSUMED", [1e-5, 1]);
p = put(p, "A_electrolyte_m2", 0.1, "m2", "ASSUMED", [1e-4, 100]);
p = put(p, "delta_diffusion_m", 2e-4, "m", "ASSUMED", [1e-7, 0.1]);
p = put(p, "V_gas_m3", 2e-3, "m3", "ASSUMED", [1e-6, 100]);
p = put(p, "n_Fe_initial_mol", 10, "mol", "ASSUMED", [1e-6, 1e8]);
p = put(p, "n_FeOH2_initial_mol", 10, "mol", "ASSUMED", [0, 1e8]);
end

function p = group_thermal_properties()
p = empty_group();
p = put(p, "m_thermal_kg", 20, "kg", "ASSUMED", [0.01, 1e8]);
p = put(p, "cp_thermal_J_kgK", 1000, "J/(kg K)", "ASSUMED", [100, 10000]);
p = put(p, "k_thermal_W_mK", 1, "W/(m K)", "ASSUMED", [0.01, 500]);
p = put(p, "h_conv_W_m2K", 10, "W/(m2 K)", "ASSUMED", [0, 1e5]);
p = put(p, "epsilon_radiation", 0.8, "1", "ASSUMED", [0, 1]);
p = put(p, "A_surface_m2", 1, "m2", "ASSUMED", [1e-4, 1e6]);
p = put(p, "de_cell_eq_dT_V_K", -4e-4, "V/K", "CALIBRATION_REQUIRED", [-0.01, 0.01]);
p = put(p, "k_Fe_W_mK", 80, "W/(m K)", "ASSUMED", [1, 200]);
p = put(p, "k_electrolyte_W_mK", 0.5, "W/(m K)", "ASSUMED", [0.05, 5]);
p = put(p, "k_polymer_W_mK", 0.2, "W/(m K)", "ASSUMED", [0.01, 2]);
end

function p = group_gas_properties()
p = empty_group();
p = put(p, "x_O2_dry_air", 0.2095, "1", "REFERENCE_CONDITION", [0, 1]);
p = put(p, "x_CO2_dry_air", 0.00042, "1", "REFERENCE_CONDITION", [0, 0.1]);
p = put(p, "RH_ambient", 0.5, "1", "ASSUMED", [0, 1]);
p = put(p, "D_O2_air_ref_m2_s", 2.0e-5, "m2/s", "ASSUMED", [1e-7, 1e-3]);
p = put(p, "M_dry_air_kg_mol", 0.028965, "kg/mol", "REFERENCE_CONDITION", [0.02, 0.04]);
p = put(p, "cp_air_J_kgK", 1005, "J/(kg K)", "ASSUMED", [500, 2000]);
p = put(p, "p_H2_trip_Pa", 4000, "Pa", "ASSUMED", [0, 1e5]);
p = put(p, "H_O2_ref_mol_m3Pa", 1.3e-5, "mol/(m3 Pa)", "CALIBRATION_REQUIRED", [1e-8, 1e-3]);
p = put(p, "O2_salting_coeff_m3_mol", 2.5e-4, "m3/mol", "CALIBRATION_REQUIRED", [0, 1e-3]);
p = put(p, "O2_solution_enthalpy_J_mol", -12000, "J/mol", "CALIBRATION_REQUIRED", [-1e5, 1e5]);
p = put(p, "D_O2_liquid_ref_m2_s", 2e-9, "m2/s", "CALIBRATION_REQUIRED", [1e-12, 1e-7]);
p = put(p, "D_gas_ref_m2_s", 2e-5, "m2/s", "ASSUMED", [1e-7, 1e-3]);
p = put(p, "gas_diffusivity_T_exponent", 1.75, "1", "ASSUMED", [1, 3]);
end

function p = group_liquid_transport()
p = empty_group();
p = put(p, "D_OH_m2_s", 5e-9, "m2/s", "ASSUMED", [1e-12, 1e-7]);
p = put(p, "D_K_m2_s", 2e-9, "m2/s", "ASSUMED", [1e-12, 1e-7]);
p = put(p, "D_CO3_m2_s", 1e-9, "m2/s", "ASSUMED", [1e-12, 1e-7]);
p = put(p, "D_O2_liquid_m2_s", 1e-9, "m2/s", "ASSUMED", [1e-12, 1e-7]);
p = put(p, "velocity_m_s", 0.01, "m/s", "ASSUMED", [0, 10]);
end

function p = group_electrolyte_circulation()
p = empty_group();
p = put(p, "Q_nominal_m3_s", 1e-5, "m3/s", "ASSUMED", [0, 10]);
p = put(p, "Q_makeup_m3_s", 0, "m3/s", "ASSUMED", [0, 1]);
p = put(p, "Q_leak_m3_s", 0, "m3/s", "ASSUMED", [0, 1]);
p = put(p, "tau_flow_s", 5, "s", "ASSUMED", [1e-3, 1e5]);
p = put(p, "enabled", true, "1", "ASSUMED", [0, 1]);
end

function p = group_pumps()
p = empty_group();
p = put(p, "delta_p_nominal_Pa", 5e4, "Pa", "ASSUMED", [0, 1e8]);
p = put(p, "eta_pump", 0.65, "1", "ASSUMED", [0.01, 1]);
p = put(p, "eta_motor_pump", 0.9, "1", "ASSUMED", [0.01, 1]);
p = put(p, "J_pump_kg_m2", 0.01, "kg m2", "ASSUMED", [1e-8, 1e4]);
p = put(p, "B_pump_Nm_s", 1e-3, "N m s", "ASSUMED", [0, 1e4]);
p = put(p, "omega_nominal_rad_s", 300, "rad/s", "ASSUMED", [0, 1e5]);
end

function p = group_fans()
p = empty_group();
p = put(p, "V_dot_nominal_m3_s", 0.02, "m3/s", "ASSUMED", [0, 1e4]);
p = put(p, "delta_p_nominal_Pa", 500, "Pa", "ASSUMED", [0, 1e7]);
p = put(p, "eta_fan", 0.6, "1", "ASSUMED", [0.01, 1]);
p = put(p, "eta_motor_fan", 0.9, "1", "ASSUMED", [0.01, 1]);
p = put(p, "tau_fan_s", 2, "s", "ASSUMED", [1e-3, 1e5]);
p = put(p, "K_filter_1_Pa_s_m3", 5000, "Pa s/m3", "ASSUMED", [0, 1e9]);
p = put(p, "K_filter_2_Pa_s2_m6", 1e5, "Pa s2/m6", "ASSUMED", [0, 1e12]);
end

function p = group_valves()
p = empty_group();
p = put(p, "C_discharge", 0.7, "1", "ASSUMED", [0.01, 1]);
p = put(p, "A_valve_max_m2", 1e-4, "m2", "ASSUMED", [1e-10, 1]);
p = put(p, "tau_valve_s", 1, "s", "ASSUMED", [1e-3, 1e5]);
end

function p = group_heat_exchanger()
p = empty_group();
p = put(p, "U_HX_W_m2K", 200, "W/(m2 K)", "ASSUMED", [0.1, 1e5]);
p = put(p, "A_HX_m2", 2, "m2", "ASSUMED", [1e-4, 1e6]);
p = put(p, "m_dot_coolant_kg_s", 0.1, "kg/s", "ASSUMED", [0, 1e5]);
p = put(p, "cp_coolant_J_kgK", 4180, "J/(kg K)", "ASSUMED", [100, 10000]);
end

function p = group_reservoir()
p = empty_group();
p = put(p, "V_reservoir_initial_m3", 0.05, "m3", "ASSUMED", [1e-5, 1e5]);
p = put(p, "V_reservoir_min_m3", 0.01, "m3", "ASSUMED", [0, 1e5]);
p = put(p, "V_reservoir_max_m3", 0.06, "m3", "ASSUMED", [1e-5, 1e5]);
p = put(p, "UA_reservoir_W_K", 20, "W/K", "ASSUMED", [0, 1e8]);
end

function p = group_piping()
p = empty_group();
p = put(p, "L_pipe_m", 10, "m", "ASSUMED", [0.01, 1e6]);
p = put(p, "D_hydraulic_m", 0.02, "m", "ASSUMED", [1e-5, 10]);
p = put(p, "roughness_m", 1e-5, "m", "ASSUMED", [0, 0.1]);
p = put(p, "K_minor", 5, "1", "ASSUMED", [0, 1e6]);
p = put(p, "Re_laminar_max", 2300, "1", "REFERENCE_CONDITION", [1000, 4000]);
end

function p = group_stack()
p = empty_group();
p = put(p, "N_series", 100, "1", "ASSUMED", [1, 1e6]);
p = put(p, "N_parallel", 10, "1", "ASSUMED", [1, 1e6]);
p = put(p, "R_busbar_Ohm", 1e-3, "Ohm", "ASSUMED", [0, 100]);
p = put(p, "sigma_mismatch", 0.02, "1", "ASSUMED", [0, 1]);
p = put(p, "representative_group_count", 6, "1", "ASSUMED", [1, 1e5]);
end

function p = group_module()
p = empty_group();
p = put(p, "N_stacks", 4, "1", "ASSUMED", [1, 1e5]);
p = put(p, "P_controls_W", 50, "W", "ASSUMED", [0, 1e7]);
p = put(p, "P_HVAC_rated_W", 2000, "W", "ASSUMED", [0, 1e9]);
p = put(p, "T_trip_K", 333.15, "K", "ASSUMED", [273.15, 500]);
end

function p = group_enclosure()
p = empty_group();
p = put(p, "N_modules", 25, "1", "ASSUMED", [1, 1e5]);
p = put(p, "C_enclosure_J_K", 1e6, "J/K", "ASSUMED", [1e3, 1e12]);
p = put(p, "UA_ambient_W_K", 500, "W/K", "ASSUMED", [0, 1e9]);
p = put(p, "P_other_W", 500, "W", "ASSUMED", [0, 1e9]);
end

function p = group_dc_bus()
p = empty_group();
p = put(p, "C_dc_F", 0.5, "F", "ASSUMED", [1e-6, 1e6]);
p = put(p, "V_dc_initial_V", 1000, "V", "ASSUMED", [1, 1e6]);
p = put(p, "R_bus_Ohm", 0.01, "Ohm", "ASSUMED", [0, 1e3]);
p = put(p, "V_dc_min_V", 800, "V", "ASSUMED", [0, 1e6]);
p = put(p, "V_dc_max_V", 1200, "V", "ASSUMED", [1, 1e6]);
end

function p = group_dcdc_converter()
p = empty_group();
p = put(p, "L_converter_H", 1e-3, "H", "ASSUMED", [1e-9, 1e3]);
p = put(p, "C_out_F", 0.01, "F", "ASSUMED", [1e-9, 1e6]);
p = put(p, "R_equivalent_Ohm", 0.01, "Ohm", "ASSUMED", [0, 1e3]);
p = put(p, "f_switching_Hz", 10000, "Hz", "ASSUMED", [1, 1e7]);
p = put(p, "E_on_J", 0.01, "J", "CALIBRATION_REQUIRED", [0, 1e3]);
p = put(p, "E_off_J", 0.01, "J", "CALIBRATION_REQUIRED", [0, 1e3]);
p = put(p, "I_limit_A", 2000, "A", "ASSUMED", [0, 1e7]);
end

function p = group_inverter()
p = empty_group();
p = put(p, "S_rated_VA", 1e6, "VA", "ASSUMED", [1, 1e12]);
p = put(p, "V_LL_rated_V", 480, "V", "ASSUMED", [1, 1e6]);
p = put(p, "eta_nominal", 0.97, "1", "ASSUMED", [0.1, 1]);
p = put(p, "Kp_P", 1e-4, "1/W", "ASSUMED", [0, 1]);
p = put(p, "Ki_P_1_Ws", 1e-5, "1/(W s)", "ASSUMED", [0, 1]);
p = put(p, "Kp_Q", 1e-4, "1/var", "ASSUMED", [0, 1]);
p = put(p, "Ki_Q_1_vars", 1e-5, "1/(var s)", "ASSUMED", [0, 1]);
end

function p = group_transformer()
p = empty_group();
p = put(p, "N_primary", 1000, "1", "ASSUMED", [1, 1e6]);
p = put(p, "N_secondary", 20, "1", "ASSUMED", [1, 1e6]);
p = put(p, "R_primary_Ohm", 0.01, "Ohm", "ASSUMED", [0, 1e4]);
p = put(p, "R_secondary_Ohm", 1e-4, "Ohm", "ASSUMED", [0, 1e4]);
p = put(p, "k_Steinmetz", 1, "W/(Hz^alpha T^beta m3)", "CALIBRATION_REQUIRED", [0, 1e6]);
p = put(p, "alpha_Steinmetz", 1.5, "1", "CALIBRATION_REQUIRED", [1, 3]);
p = put(p, "beta_Steinmetz", 2.2, "1", "CALIBRATION_REQUIRED", [1, 4]);
p = put(p, "V_core_m3", 0.1, "m3", "ASSUMED", [1e-6, 1e3]);
p = put(p, "R_thermal_K_W", 0.02, "K/W", "ASSUMED", [1e-8, 1e4]);
p = put(p, "C_thermal_J_K", 1e6, "J/K", "ASSUMED", [1, 1e12]);
end

function p = group_electrical_protection()
p = empty_group();
p = put(p, "I_trip_A", 2500, "A", "ASSUMED", [0, 1e8]);
p = put(p, "t_overcurrent_trip_s", 0.1, "s", "ASSUMED", [0, 1e5]);
p = put(p, "R_precharge_Ohm", 10, "Ohm", "ASSUMED", [1e-6, 1e6]);
p = put(p, "t_reconnect_s", 300, "s", "ASSUMED", [0, 1e7]);
end

function p = group_sensors()
p = empty_group();
p = put(p, "tau_sensor_s", 0.1, "s", "ASSUMED", [0, 1e5]);
p = put(p, "sigma_voltage_V", 0.005, "V", "ASSUMED", [0, 1e3]);
p = put(p, "sigma_current_A", 0.1, "A", "ASSUMED", [0, 1e6]);
p = put(p, "sigma_temperature_K", 0.1, "K", "ASSUMED", [0, 100]);
p = put(p, "k_sensor_drift_unit_s", 0, "1/s", "CALIBRATION_REQUIRED", [-1, 1]);
end

function p = group_supervisory_controls()
p = empty_group();
p = put(p, "SOC_min", 0.05, "1", "ASSUMED", [0, 1]);
p = put(p, "SOC_max", 0.95, "1", "ASSUMED", [0, 1]);
p = put(p, "T_derate_K", 318.15, "K", "ASSUMED", [250, 500]);
p = put(p, "T_trip_K", 328.15, "K", "ASSUMED", [250, 500]);
p = put(p, "qualification_time_s", 2, "s", "ASSUMED", [0, 1e5]);
p = put(p, "transition_rest_s", 60, "s", "ASSUMED", [0, 1e6]);
p = put(p, "Kp_I", 0.1, "1", "ASSUMED", [0, 1e5]);
p = put(p, "Ki_I_1_s", 0.01, "1/s", "ASSUMED", [0, 1e5]);
end

function p = group_grid()
p = empty_group();
p = put(p, "V_grid_base_V", 12470, "V", "ASSUMED", [1, 1e7]);
p = put(p, "f_nominal_Hz", 60, "Hz", "REFERENCE_CONDITION", [40, 70]);
p = put(p, "K_frequency_droop_W_Hz", 2e5, "W/Hz", "ASSUMED", [0, 1e12]);
p = put(p, "K_voltage_droop_var_V", 100, "var/V", "ASSUMED", [0, 1e9]);
p = put(p, "ramp_up_limit_W_s", 1e5, "W/s", "ASSUMED", [0, 1e12]);
p = put(p, "ramp_down_limit_W_s", 1e5, "W/s", "ASSUMED", [0, 1e12]);
p = put(p, "standards_profile_version", 1, "1", "ASSUMED", [1, 1e6]);
end

function p = group_aging_degradation()
p = empty_group();
p = put(p, "k_aging_ref_1_s", 1e-10, "1/s", "CALIBRATION_REQUIRED", [0, 1]);
p = put(p, "E_a_aging_J_mol", 40000, "J/mol", "CALIBRATION_REQUIRED", [0, 2e5]);
p = put(p, "k_area_loss_1_s", 1e-11, "1/s", "CALIBRATION_REQUIRED", [0, 1]);
p = put(p, "k_catalyst_loss_1_s", 1e-11, "1/s", "CALIBRATION_REQUIRED", [0, 1]);
p = put(p, "k_resistance_growth_Ohm_s", 1e-12, "Ohm/s", "CALIBRATION_REQUIRED", [0, 1]);
p = put(p, "r_Fe_irreversible_mol_s", 1e-12, "mol/s", "CALIBRATION_REQUIRED", [0, 1]);
end

function p = group_fault_detection()
p = empty_group();
p = put(p, "detection_delay_s", 1, "s", "ASSUMED", [0, 1e5]);
p = put(p, "reset_delay_s", 60, "s", "ASSUMED", [0, 1e7]);
p = put(p, "R_short_fault_Ohm", 1e-3, "Ohm", "ASSUMED", [1e-9, 1e6]);
p = put(p, "sensor_bias_trip_sigma", 5, "1", "ASSUMED", [0, 1e3]);
p = put(p, "H2_trip_fraction", 0.04, "1", "ASSUMED", [0, 1]);
end

function p = empty_group()
p = struct("meta", struct());
end

function p = put(p, name, value, unit, classification, valid_range, reference_id)
arguments
    p (1, 1) struct
    name (1, 1) string
    value
    unit (1, 1) string
    classification (1, 1) string
    valid_range (1, 2) double
    reference_id (1, 1) string = "NONE"
end
p.(name) = value;
p.meta.(name) = meta(unit, classification, valid_range, ...
    "IRONAIR-MATLAB development reference configuration", reference_id);
end

function result = meta(unit, classification, valid_range, applicability, reference_id)
if nargin < 5
    reference_id = "NONE";
end
result = ironair_parameter_metadata(unit, classification, valid_range, ...
    applicability, reference_id);
end
