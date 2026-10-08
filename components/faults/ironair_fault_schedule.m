function [faults, diagnostics] = ironair_fault_schedule(t, schedule, p)
%IRONAIR_FAULT_SCHEDULE Map deterministic onset times to physical modifiers.
%   Requirements: SRS017.

arguments
    t (1, 1) double
    schedule (1, 1) struct
    p (1, 1) struct
end

names = string(fieldnames(schedule));
active = struct();
records = struct("name", {}, "onset_s", {}, "detected", {}, "mitigation", {}, ...
    "recovery_s", {});
for index = 1:numel(names)
    item = schedule.(names(index));
    is_on = t >= item.onset_s && t <= item.onset_s + item.duration_s;
    active.(names(index)) = is_on;
    if is_on
        rec = struct("name", names(index), "onset_s", item.onset_s, ...
            "detected", t >= item.onset_s + p.fault_detection.detection_delay_s, ...
            "mitigation", "protective_derate_or_trip", ...
            "recovery_s", item.onset_s + item.duration_s);
        records(end + 1) = rec; %#ok<AGROW>
    end
end

faults = struct();
faults.fan_failed = flag(active, "fan_failure");
faults.pump_failed = flag(active, "pump_failure");
faults.Q_leak_m3_s = p.electrolyte_circulation.Q_leak_m3_s;
if flag(active, "electrolyte_leak")
    faults.Q_leak_m3_s = 1e-6;
end
faults.oxygen_starvation = flag(active, "oxygen_starvation");
faults.R_short_Ohm = inf;
if flag(active, "cell_short")
    faults.R_short_Ohm = p.fault_detection.R_short_fault_Ohm;
end
faults.open_circuit = flag(active, "open_circuit");
faults.sensor_failed = flag(active, "sensor_failure");
faults.sensor_bias = flag(active, "sensor_bias");
faults.cooling_failed = flag(active, "cooling_failure");
faults.grid_undervoltage = flag(active, "grid_undervoltage");
faults.grid_overvoltage = flag(active, "grid_overvoltage");
faults.grid_underfrequency = flag(active, "grid_underfrequency");
faults.grid_overfrequency = flag(active, "grid_overfrequency");
faults.controller_failed = flag(active, "supervisory_controller_failure");
faults.active_records = records;
diagnostics = struct("t", t, "n_active", numel(records));
end

function tf = flag(active, name)
tf = isfield(active, name) && active.(name);
end
