function tests = test_traceability_coverage
tests = functiontests(localfunctions);
end

function test_equation_ids_appear_in_source(test_case)
root = fileparts(fileparts(mfilename("fullpath")));
groups = {"FE", 16; "HER", 5; "AIR", 9; "GDL", 6; "ELY", 15; "SEP", 4; ...
    "COL", 4; "CELL", 10; "THM", 9; "AIRSYS", 10; "FLD", 10; "HEX", 4; ...
    "STK", 6; "MOD", 5; "DC", 4; "CONV", 6; "INV", 7; "TRF", 4; ...
    "GRID", 6; "CTRL", 6; "EST", 6; "DEG", 6; "FLT", 6; "SYS", 7};
ids = strings(0, 1);
for group = 1:size(groups, 1)
    for number = 1:groups{group, 2}
        ids(end + 1) = sprintf("%s-%03d", groups{group, 1}, number); %#ok<AGROW>
    end
end
verifyEqual(test_case, numel(ids), 171);
blob = "";
files = dir(fullfile(root, "**", "*.m"));
for index = 1:numel(files)
    blob = blob + string(fileread(fullfile(files(index).folder, files(index).name)));
end
for id = ids
    verifyTrue(test_case, contains(blob, id), "Missing equation id " + id);
end
end
