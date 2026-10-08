function path_out = ironair_generate_report(results, results_dir)
%IRONAIR_GENERATE_REPORT Write a text report and optional MAT file.
%   Requirements: SRS020, SRS024.

arguments
    results (1, 1) struct
    results_dir (1, 1) string = "results"
end

if ~isfolder(results_dir)
    mkdir(results_dir);
end
report = ironair_results_postprocess(results);
path_out = fullfile(results_dir, "ironair_report.txt");
fid = fopen(path_out, "w");
if fid < 0
    error("ironair:results:FileOpen", "Unable to write %s.", path_out);
end
cleaner = onCleanup(@() fclose(fid));
fprintf(fid, "IRONAIR-MATLAB report\n");
fprintf(fid, "status: %s\n", report.log.status);
fprintf(fid, "samples: %d\n", numel(report.log.t_s));
fprintf(fid, "E_import_J: %g\n", report.E_import_J);
fprintf(fid, "E_export_J: %g\n", report.E_export_J);
mat_path = fullfile(results_dir, "ironair_last_run.mat");
save(mat_path, "results", "report");
end
