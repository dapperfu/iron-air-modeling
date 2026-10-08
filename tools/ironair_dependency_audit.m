function report = ironair_dependency_audit()
%IRONAIR_DEPENDENCY_AUDIT Scan production MATLAB sources for prohibited tokens.
ironair_setup();
root = fileparts(fileparts(mfilename("fullpath")));
files = dir(fullfile(root, "**", "*.m"));
forbidden = ["simulink", "simscape", "pyrun", "coder.ceval"];
hits = strings(0, 1);
skip_dirs = ["tests", "tools"];
for index = 1:numel(files)
    folder = string(files(index).folder);
    if contains(folder, skip_dirs) || files(index).name == "ironair_dependency_audit.m"
        continue
    end
    text = lower(fileread(fullfile(files(index).folder, files(index).name)));
    for token = forbidden
        if contains(text, token)
            hits(end + 1, 1) = files(index).name + ":" + token; %#ok<AGROW>
        end
    end
end
report = struct("n_files", numel(files), "hits", hits, "clean", isempty(hits));
end
