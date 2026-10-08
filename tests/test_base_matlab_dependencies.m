function tests = test_base_matlab_dependencies
tests = functiontests(localfunctions);
end

function setupOnce(test_case)
root = fileparts(fileparts(mfilename("fullpath")));
test_case.TestData.root = root;
end

function test_no_prohibited_language_tokens(test_case)
root = test_case.TestData.root;
files = [dir(fullfile(root, "**", "*.m"))];
forbidden = ["simulink", "simscape", "pyrun", "coder.ceval", "loadlibrary", ...
    "fsolve(", "optimoptions", "mex(", "javaObject"];
skip_names = ["test_base_matlab_dependencies.m", "ironair_dependency_audit.m"];
for index = 1:numel(files)
    if any(files(index).name == skip_names)
        continue
    end
    text = fileread(fullfile(files(index).folder, files(index).name));
    lower_text = lower(text);
    for token = forbidden
        verifyFalse(test_case, contains(lower_text, lower(token)), ...
            files(index).name + " contains " + token);
    end
    system_hits = regexp(lower_text, "(?<![a-z0-9_])system\(", "once");
    verifyTrue(test_case, isempty(system_hits), ...
        files(index).name + " contains system(");
end
end

function test_source_files_are_matlab_only(test_case)
root = test_case.TestData.root;
bad = [dir(fullfile(root, "components", "**", "*.slx")); ...
    dir(fullfile(root, "core", "**", "*.py")); ...
    dir(fullfile(root, "components", "**", "*.c"))];
verifyEqual(test_case, numel(bad), 0);
end
