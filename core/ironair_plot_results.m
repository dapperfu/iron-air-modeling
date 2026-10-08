function ironair_plot_results(results)
%IRONAIR_PLOT_RESULTS Base-MATLAB headless-safe plots of cell voltage and SOC.
%   Requirements: SRS020.

arguments
    results (1, 1) struct
end

log = ironair_results_logger(results);
if ~isfield(log, "t_sample_s")
    return
end
fig = figure("Visible", "off");
subplot(2, 1, 1);
plot(log.t_sample_s, log.V_cell_V);
ylabel("V_cell (V)");
subplot(2, 1, 2);
plot(log.t_sample_s, log.SOC);
ylabel("SOC");
xlabel("t (s)");
results_dir = "results";
if ~isfolder(results_dir)
    mkdir(results_dir);
end
saveas(fig, fullfile(results_dir, "ironair_cell_traces.png"));
close(fig);
end
