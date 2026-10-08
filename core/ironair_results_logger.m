function log = ironair_results_logger(results)
%IRONAIR_RESULTS_LOGGER Structured time-series log from a coupled run.
%   Requirements: SRS020.

arguments
    results (1, 1) struct
end

log = struct();
log.t_s = results.t_s;
log.seed = 1;
log.status = "ok";
if isfield(results, "solver_failed") && results.solver_failed
    log.status = "solver_failed";
end
if isfield(results, "outputs") && ~isempty(results.outputs)
    n = numel(results.outputs);
    log.V_cell_V = zeros(n, 1);
    log.I_cell_A = zeros(n, 1);
    log.P_cell_W = zeros(n, 1);
    log.SOC = zeros(n, 1);
    log.T_cell_K = zeros(n, 1);
    log.P_grid_export_W = zeros(n, 1);
    log.P_grid_import_W = zeros(n, 1);
    for k = 1:n
        out = results.outputs{k};
        log.V_cell_V(k) = out.cell.V_cell_V;
        log.I_cell_A(k) = out.cell.I_cell_A;
        log.P_cell_W(k) = out.cell.P_cell_W;
        log.SOC(k) = out.cell.SOC;
        if isfield(out.thermal, "T_cell_K")
            log.T_cell_K(k) = out.thermal.T_cell_K;
        else
            log.T_cell_K(k) = out.thermal.T_K(1);
        end
        if isfield(out, "P_grid_export_W")
            log.P_grid_export_W(k) = out.P_grid_export_W;
            log.P_grid_import_W(k) = out.P_grid_import_W;
        end
    end
    log.t_sample_s = results.t_sample_s;
end
end
