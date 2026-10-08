function count = ironair_migrate_equation_requirements(source_path, output_path, force)
%IRONAIR_MIGRATE_EQUATION_REQUIREMENTS One-time Markdown-to-StrictDoc migration.
%   COUNT = IRONAIR_MIGRATE_EQUATION_REQUIREMENTS(SOURCE_PATH, OUTPUT_PATH,
%   FORCE) extracts every equation requirement from the approved migration
%   input and writes an authoritative StrictDoc document.
%
%   Inputs:
%     source_path - Markdown migration input path.
%     output_path - Destination .sdoc path.
%     force       - Logical overwrite authorization.
%
%   Output:
%     count       - Number of migrated equation requirements.
%
%   This migration utility uses only base MATLAB. The generated .sdoc file,
%   not the Markdown input, becomes authoritative after review.
%
%   Requirements: SRS021, SRS024.

arguments
    source_path (1, 1) string = "ChatGPT_Plan.md"
    output_path (1, 1) string = fullfile("requirements", "equations", ...
        "IRONAIR_EQUATIONS.sdoc")
    force (1, 1) logical = false
end

if isfile(output_path) && ~force
    error("ironair:requirements:OutputExists", ...
        "Refusing to overwrite authoritative requirements: %s", output_path);
end
if ~isfile(source_path)
    error("ironair:requirements:SourceMissing", ...
        "Migration input does not exist: %s", source_path);
end

text = fileread(source_path);
marker = "# IRONAIR-MATLAB: Complete Equation-to-Requirement";
marker_index = strfind(text, marker);
if isempty(marker_index)
    error("ironair:requirements:MarkerMissing", ...
        "Equation specification marker was not found.");
end
text = text(marker_index(1):end);

expression = "(?m)^## ([A-Z]+-[0-9]{3}): ([^\r\n]+)\r?$";
[starts, ends, tokens] = regexp(text, expression, "start", "end", "tokens");
count = numel(tokens);
uids = string(cellfun(@(token) token{1}, tokens, "UniformOutput", false));
if count ~= 171 || numel(unique(uids)) ~= count || ...
        uids(1) ~= "FE-001" || uids(end) ~= "SYS-007"
    error("ironair:requirements:EquationCount", ...
        "Expected 171 unique IDs from FE-001 through SYS-007 but found %d.", ...
        count);
end

output_folder = fileparts(output_path);
if ~isfolder(output_folder)
    mkdir(output_folder);
end
file_id = fopen(output_path, "w");
if file_id < 0
    error("ironair:requirements:OpenFailed", ...
        "Unable to open output file: %s", output_path);
end
cleanup = onCleanup(@() fclose(file_id));

fprintf(file_id, "[DOCUMENT]\n");
fprintf(file_id, "TITLE: IRONAIR-MATLAB Equation Requirements\n");
fprintf(file_id, "UID: DOC-IRONAIR-EQUATIONS\n");
fprintf(file_id, "VERSION: 1.0.0\n\n");

for index = 1:count
    uid = string(tokens{index}{1});
    title = strtrim(string(tokens{index}{2}));
    if index < count
        section_end = starts(index + 1) - 1;
    else
        completion_marker = strfind(text(ends(index) + 1:end), ...
            "# SECTION 25: EQUATION TRACEABILITY REQUIREMENTS");
        if isempty(completion_marker)
            section_end = strlength(text);
        else
            section_end = ends(index) + completion_marker(1) - 1;
        end
    end
    body = string(text(ends(index) + 1:section_end));
    body = strip(body);
    body = replace(body, "<<<", "less-than less-than less-than");
    body = replace(body, sprintf("\r\n"), newline);
    body = "| " + replace(body, newline, newline + "| ");

    prefix = string(text(1:starts(index) - 1));
    file_tokens = regexp(prefix, "`([^`\r\n]+\.m)`", "tokens");
    if isempty(file_tokens)
        implementation_file = "";
    else
        implementation_file = string(file_tokens{end}{1});
    end

    requirement_tokens = regexp(body, "SRS[0-9]{3}(?:\.[0-9]+)?", "match");
    parent_uids = unique(string(requirement_tokens), "stable");
    classification = classify_equation(uid, title, body);
    test_file = grouped_test_file(uid);

    fprintf(file_id, "[REQUIREMENT]\n");
    fprintf(file_id, "UID: %s\n", uid);
    fprintf(file_id, "TITLE: %s\n", title);
    fprintf(file_id, "STATEMENT: >>>\n%s\n<<<\n", body);
    fprintf(file_id, "COMMENT: Classification: %s\n", classification);
    if ~isempty(parent_uids) || strlength(implementation_file) > 0
        fprintf(file_id, "RELATIONS:\n");
        for parent_index = 1:numel(parent_uids)
            fprintf(file_id, "- TYPE: Parent\n");
            fprintf(file_id, "  VALUE: %s\n", parent_uids(parent_index));
        end
        if strlength(implementation_file) > 0
            fprintf(file_id, "- TYPE: File\n");
            fprintf(file_id, "  VALUE: %s\n", implementation_file);
        end
        fprintf(file_id, "- TYPE: File\n");
        fprintf(file_id, "  VALUE: %s\n", test_file);
    end
    fprintf(file_id, "\n");
end

clear cleanup;
end

function classification = classify_equation(uid, title, body)
text = lower(title + " " + body);
if startsWith(uid, "CTRL-") || startsWith(uid, "GRID-") || ...
        contains(text, "controller") || contains(text, "trip condition")
    classification = "control law";
elseif contains(text, "balance") || contains(text, "inventory") || ...
        contains(text, "conservation") || contains(text, "production rate") || ...
        contains(text, "consumption") || contains(text, "generation")
    classification = "conservation law";
elseif contains(text, "empirical") || contains(text, "approximation") || ...
        contains(text, "affinity") || contains(text, "steinmetz")
    classification = "empirical approximation";
else
    classification = "constitutive equation";
end
end

function path = grouped_test_file(uid)
prefix = extractBefore(uid, "-");
electrochemical = ["FE", "HER", "AIR", "GDL", "ELY", "SEP", "COL", "CELL"];
balance_of_plant = ["THM", "AIRSYS", "FLD", "HEX"];
electrical = ["STK", "MOD", "DC", "CONV", "INV", "TRF"];
controls = ["GRID", "CTRL", "EST", "DEG", "FLT"];
if any(prefix == electrochemical)
    group = "electrochemistry";
elseif any(prefix == balance_of_plant)
    group = "balance_of_plant";
elseif any(prefix == electrical)
    group = "electrical";
elseif any(prefix == controls)
    group = "controls";
else
    group = "system";
end
path = "tests/test_equations_" + group + ".m";
end
