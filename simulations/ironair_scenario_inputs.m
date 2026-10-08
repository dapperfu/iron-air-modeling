function inputs = ironair_scenario_inputs(t, scenario_name, p)
%IRONAIR_SCENARIO_INPUTS Plant commands for the coupled operating scenarios.
%   INPUTS = IRONAIR_SCENARIO_INPUTS(T, SCENARIO_NAME, P)
%
%   Current is discharge-positive amperes per cell.
%
%   Requirements: SRS001, SRS014, SRS018.

arguments
    t (1, 1) double
    scenario_name (1, 1) string
    p (1, 1) struct
end

switch scenario_name
    case "discharge"
        I_cell = 1;
    case "charge"
        I_cell = -1;
    case "rest"
        I_cell = 0;
    case "switching"
        phase_s = mod(t, 30);
        if phase_s < 10
            I_cell = 1;
        elseif phase_s < 20
            I_cell = 0;
        else
            I_cell = -1;
        end
    case "hundred_hour"
        phase_s = mod(t, 9 * 3600);
        if phase_s < 4 * 3600
            I_cell = 1;
        elseif phase_s < 8 * 3600
            I_cell = -1;
        else
            I_cell = 0;
        end
    case "oxygen_starvation"
        I_cell = 1;
    case "zero_flow"
        I_cell = 1;
    case "thermal_extreme"
        I_cell = 1;
    case "grid_disturbance"
        I_cell = 1;
    case "degradation"
        I_cell = 1;
    case "faults"
        I_cell = 1;
    otherwise
        error("ironair:scenario:Unknown", ...
            "Unknown scenario %s.", scenario_name);
end

T_amb = p.reference.T_initial_K;
if scenario_name == "thermal_extreme"
    T_amb = 333.15;
end

inputs = struct( ...
    "I_cell_command_A", I_cell, ...
    "T_ambient_K", T_amb, ...
    "T_coolant_in_K", T_amb, ...
    "V_grid_V", p.grid.V_grid_base_V, ...
    "V_grid_measured_V", p.grid.V_grid_base_V, ...
    "f_grid_Hz", p.grid.f_nominal_Hz, ...
    "P_scheduled_W", I_cell .* p.reference.E_cell_nominal_V .* ...
        p.stack.N_series .* p.stack.N_parallel, ...
    "dP_requested_dt", 0, ...
    "fault_name", local_fault_name(scenario_name), ...
    "sensor_noise", 0, ...
    "phi_power_rad", 0, ...
    "V_LL_V", p.inverter.V_LL_rated_V, ...
    "f_transformer_Hz", p.grid.f_nominal_Hz, ...
    "B_peak_T", 1.2);
end

function name = local_fault_name(scenario_name)
name = "none";
if scenario_name == "oxygen_starvation"
    name = "oxygen_starvation";
elseif scenario_name == "faults"
    name = "fan_failed";
end
end
