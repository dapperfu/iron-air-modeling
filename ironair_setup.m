function project = ironair_setup()
%IRONAIR_SETUP Add IRONAIR-MATLAB source folders to the MATLAB path.
%   PROJECT = IRONAIR_SETUP() resolves the repository root from this file,
%   adds only project source folders to the active MATLAB path, and returns
%   immutable path metadata. It does not modify the base workspace.
%
%   Output:
%     project.root             - Repository root path.
%     project.requirements_dir - Authoritative StrictDoc source directory.
%     project.results_dir      - Default generated-results directory.
%
%   Units: not applicable.
%   Assumptions: this file remains in the repository root.
%   Requirements: SRS001.2, SRS018, SRS024.

root = fileparts(mfilename("fullpath"));
source_folders = [
    "parameters"
    "properties"
    "components"
    "controls"
    "core"
    "configurations"
    "simulations"
    "scenarios"
    "tests"
    "tools"
    ];

for index = 1:numel(source_folders)
    folder = fullfile(root, source_folders(index));
    if isfolder(folder)
        addpath(genpath(folder));
    end
end

project = struct( ...
    "root", string(root), ...
    "requirements_dir", string(fullfile(root, "requirements")), ...
    "results_dir", string(fullfile(root, "results")));
end
