function pathsAdded = addpath_IronAir()
%ADDPATH_IRONAIR Add iron-air-modeling code and model directories to the MATLAB path.
%
%   addpath_IronAir
%   paths = addpath_IronAir()
%
% Intended for use from a local startup.m (not part of this repository), e.g.:
%   run('C:/projects/iron-air-modeling/addpath_IronAir.m');
%
% Adds the project root and subdirectories that contain MATLAB/Simulink
% code and models. Excludes VCS, Python venv, and generated documentation.

root = fileparts(mfilename('fullpath'));

candidates = { ...
    root, ...
    fullfile(root, 'src'), ...
    fullfile(root, 'tools'), ...
    fullfile(root, 'models'), ...
    fullfile(root, 'tests'), ...
    fullfile(root, 'data'), ...
    fullfile(root, 'data', 'mock') ...
    };

srcTree = filter_genpath(genpath(fullfile(root, 'src')));
paths = unique([candidates(:); srcTree(:)], 'stable');
paths = paths(cellfun(@isfolder, paths));

addpath(paths{:});

if nargout > 0
    pathsAdded = paths;
end
end

function dirs = filter_genpath(gp)
% Split genpath output and drop excluded path segments.
if isempty(gp)
    dirs = {};
    return;
end
parts = strsplit(gp, pathsep);
parts = parts(~cellfun(@isempty, parts));
exclude = {'.git', '.svn', '.venv', 'venv', '__pycache__', ...
    'docs', 'requirements_html', 'slprj', 'sccprj'};
keep = true(size(parts));
for i = 1:numel(parts)
    segs = strsplit(parts{i}, filesep);
    if any(ismember(lower(segs), exclude))
        keep(i) = false;
    end
end
dirs = parts(keep);
dirs = dirs(:);
end
