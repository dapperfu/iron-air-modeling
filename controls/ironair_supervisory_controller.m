function [dx, outputs, diagnostics] = ironair_supervisory_controller(t, x, inputs, p)
%IRONAIR_SUPERVISORY_CONTROLLER Eighteen-mode plant supervisor and current PI.
%   [DX, OUTPUTS, DIAGNOSTICS] = IRONAIR_SUPERVISORY_CONTROLLER(T, X, INPUTS, P)
%
%   State x:
%     integral_e_I_As (leading element; extra entries are ignored)
%
%   Discrete modes 1-18 are algebraic. Priority, hysteresis, and
%   qualification use the supplied Boolean guards.
%
%   Charging and discharging limits are nonnegative magnitudes.
%   Equation: CTRL-001 through CTRL-006
%   Requirements: SRS014, SRS015.

arguments
    t (1, 1) double
    x (:, 1) double
    inputs (1, 1) struct
    p (1, 1) struct
end

ctrl = p.supervisory_controls;
integral_e_I = x(1);
% CTRL-001
SOC_valid = (inputs.SOC >= ctrl.SOC_min) && (inputs.SOC <= ctrl.SOC_max);
P_charge_converter = pick_limit(inputs, "P_charge_converter_limit_W", ...
    "P_charge_converter_limit", inf);
P_charge_echem = pick_limit(inputs, "P_charge_electrochemical_limit_W", ...
    "P_charge_electrochemical_limit", inf);
P_charge_thermal = pick_limit(inputs, "P_charge_thermal_limit_W", ...
    "P_charge_thermal_limit", inf);
P_charge_grid = pick_limit(inputs, "P_charge_grid_limit_W", ...
    "P_charge_grid_limit", inf);
% CTRL-002
P_charge_allowed = min([P_charge_converter, P_charge_echem, ...
    P_charge_thermal, P_charge_grid]);
P_discharge_converter = pick_limit(inputs, "P_discharge_converter_limit_W", ...
    "P_discharge_converter_limit", inf);
P_discharge_oxygen = pick_limit(inputs, "P_discharge_oxygen_limit_W", ...
    "P_discharge_oxygen_limit", inf);
P_discharge_echem = pick_limit(inputs, "P_discharge_electrochemical_limit_W", ...
    "P_discharge_electrochemical_limit", inf);
P_discharge_thermal = pick_limit(inputs, "P_discharge_thermal_limit_W", ...
    "P_discharge_thermal_limit", inf);
% CTRL-003
P_discharge_allowed = min([P_discharge_converter, P_discharge_oxygen, ...
    P_discharge_echem, P_discharge_thermal]);
P_rated = 0;
if isfield(inputs, "P_rated_W")
    P_rated = inputs.P_rated_W;
elseif isfield(p, "reference")
    P_rated = p.reference.P_AC_rated_W;
end
I_limit = 1;
if isfield(inputs, "I_limit_A")
    I_limit = inputs.I_limit_A;
end
% CTRL-005
f_thermal = min(1, max(0, (ctrl.T_trip_K - inputs.T_cell_K) ./ ...
    (ctrl.T_trip_K - ctrl.T_derate_K)));
P_allowed_thermal = f_thermal .* P_rated;
% CTRL-004
e_I = inputs.I_ref_A - inputs.I_measured_A;
[u_I, dintegral_e_I_dt] = ironair_pi_antiwindup(e_I, integral_e_I, ctrl.Kp_I, ...
    ctrl.Ki_I_1_s, -I_limit, I_limit);
grid_ready = flag(inputs, "grid_ready", true);
thermal_ready = flag(inputs, "thermal_ready", true);
fluid_ready = flag(inputs, "fluid_ready", true);
electrodes_ready = flag(inputs, "electrodes_ready", true);
% CTRL-006
allow_transition = grid_ready && thermal_ready && fluid_ready && electrodes_ready;
mode = select_mode(inputs, SOC_valid, f_thermal, allow_transition);

dx = dintegral_e_I_dt;
outputs = struct( ...
    "SOC_valid", SOC_valid, ...
    "P_charge_allowed_W", P_charge_allowed, ...
    "P_discharge_allowed_W", P_discharge_allowed, ...
    "f_thermal", f_thermal, ...
    "P_allowed_thermal_W", P_allowed_thermal, ...
    "e_I_A", e_I, ...
    "u_I", u_I, ...
    "dintegral_e_I_dt", dintegral_e_I_dt, ...
    "allow_transition", allow_transition, ...
    "mode", mode, ...
    "mode_name", mode_name(mode));
diagnostics = struct("t", t, "priority_applied", true, ...
    "anti_chatter", allow_transition);
end

function value = pick_limit(inputs, name_w, name, default_value)
value = default_value;
if isfield(inputs, name_w)
    value = inputs.(name_w);
elseif isfield(inputs, name)
    value = inputs.(name);
end
end

function value = flag(inputs, name, default_value)
value = default_value;
if isfield(inputs, name)
    value = logical(inputs.(name));
end
end

function mode = select_mode(inputs, SOC_valid, f_thermal, allow_transition)
% Priority: fail-safe modes first, then derates, then commanded operation.
if flag(inputs, "controller_failed", false)
    mode = 17;
    return
end
if flag(inputs, "shutdown", false)
    mode = 18;
    return
end
if flag(inputs, "grid_fault", false) || ~flag(inputs, "grid_ready", true)
    mode = 16;
    return
end
if flag(inputs, "H2_fault", false)
    mode = 12;
    return
end
if flag(inputs, "electrolyte_fault", false)
    mode = 11;
    return
end
if ~flag(inputs, "thermal_ready", true) || f_thermal <= 0
    mode = 9;
    return
end
if ~SOC_valid && isfield(inputs, "SOC") && inputs.SOC < 0.5
    mode = 6;
    return
end
if ~SOC_valid
    mode = 7;
    return
end
if flag(inputs, "oxygen_limited", false)
    mode = 10;
    return
end
if f_thermal < 1
    mode = 8;
    return
end
if ~allow_transition
    mode = 13;
    return
end
command = "idle";
if isfield(inputs, "command")
    command = string(inputs.command);
end
switch command
    case "discharge"
        mode = 3;
    case "charge"
        mode = 4;
    case "rest"
        mode = 5;
    case "standby"
        mode = 2;
    case "reconnect"
        mode = 14;
    case "ramp"
        mode = 15;
    otherwise
        mode = 1;
end
end

function name = mode_name(mode)
names = ["idle", "standby", "discharge", "charge", "rest", ...
    "soc_low_hold", "soc_high_hold", "thermal_derate", "thermal_trip", ...
    "oxygen_limited", "electrolyte_fault", "hydrogen_fault", "grid_wait", ...
    "reconnect", "ramp", "grid_fault", "controller_failed", "shutdown"];
name = names(mode);
end
