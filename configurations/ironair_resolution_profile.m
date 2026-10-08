function profile = ironair_resolution_profile(name)
%IRONAIR_RESOLUTION_PROFILE Return deterministic accuracy/runtime settings.
%   PROFILE = IRONAIR_RESOLUTION_PROFILE(NAME) returns one of the `smoke`,
%   `standard`, or `reference` resolution presets used by every fidelity.
%
%   Input:
%     name - Preset name.
%
%   Output fields and units:
%     rel_tol                  - Relative solver tolerance, dimensionless.
%     abs_tol_scale            - State tolerance multiplier, dimensionless.
%     max_step_s               - Maximum integration step, s.
%     output_interval_s        - Nominal result logging interval, s.
%     electrode_control_volumes- Level 3 cells, dimensionless count.
%     electrolyte_volumes      - Level 2/3 volumes, dimensionless count.
%     oxygen_control_volumes   - GDL/air volumes, dimensionless count.
%     representative_groups    - Distributed cell groups, count.
%
%   Requirements: SRS001.3, SRS018, SRS023.

arguments
    name (1, 1) string {mustBeMember(name, ...
        ["smoke", "standard", "reference"])} = "standard"
end

switch name
    case "smoke"
        profile = make_profile(name, 1e-4, 10, 300, 300, 3, 2, 3, 2);
    case "standard"
        profile = make_profile(name, 1e-6, 1, 60, 60, 12, 6, 12, 6);
    case "reference"
        profile = make_profile(name, 1e-8, 0.1, 10, 10, 40, 20, 40, 20);
end
end

function profile = make_profile(name, rel_tol, abs_tol_scale, max_step_s, ...
        output_interval_s, electrode_control_volumes, electrolyte_volumes, ...
        oxygen_control_volumes, representative_groups)
profile = struct( ...
    "name", name, ...
    "rel_tol", rel_tol, ...
    "abs_tol_scale", abs_tol_scale, ...
    "max_step_s", max_step_s, ...
    "output_interval_s", output_interval_s, ...
    "electrode_control_volumes", electrode_control_volumes, ...
    "electrolyte_volumes", electrolyte_volumes, ...
    "oxygen_control_volumes", oxygen_control_volumes, ...
    "representative_groups", representative_groups);
end
