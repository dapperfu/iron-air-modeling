function report = ironair_results_postprocess(results)
%IRONAIR_RESULTS_POSTPROCESS Headless conservation and energy ledgers.
%   Equation: SYS-004, SYS-005, CELL-007, CELL-008
%   Requirements: SRS020, SRS023.

arguments
    results (1, 1) struct
end

log = ironair_results_logger(results);
E_import = 0;
E_export = 0;
if isfield(log, "t_sample_s") && isfield(log, "P_grid_import_W")
    E_import = trapz_safe(log.t_sample_s, log.P_grid_import_W);
    E_export = trapz_safe(log.t_sample_s, log.P_grid_export_W);
end
if E_import > 1e-6
    eta_round_trip_AC = E_export / E_import;
else
    eta_round_trip_AC = NaN;
end
P_pos = 0;
P_neg = 0;
if isfield(log, "P_cell_W")
    P_pos = max(log.P_cell_W, 0);
    P_neg = max(-log.P_cell_W, 0);
end
if isfield(log, "t_sample_s")
    E_discharge_J = trapz_safe(log.t_sample_s, P_pos);
    E_charge_J = trapz_safe(log.t_sample_s, P_neg);
else
    E_discharge_J = 0;
    E_charge_J = 0;
end
if E_charge_J > 1e-9
    eta_E = E_discharge_J / E_charge_J;
else
    eta_E = NaN;
end
E_chem = E_discharge_J;
report = struct("log", log, "E_chem_J", E_chem, "E_import_J", E_import, ...
    "E_export_J", E_export, "eta_round_trip_AC", eta_round_trip_AC, ...
    "eta_E", eta_E, "eta_C", NaN);
end

function z = trapz_safe(t, y)
if numel(t) < 2
    z = 0;
else
    z = trapz(t, y);
end
end
