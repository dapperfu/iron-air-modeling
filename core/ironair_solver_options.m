function options = ironair_solver_options(profile, state_scale, event_function, j_pattern)
%IRONAIR_SOLVER_OPTIONS Build deterministic stiff-solver configuration.
%   OPTIONS = IRONAIR_SOLVER_OPTIONS(PROFILE, STATE_SCALE, EVENT_FUNCTION,
%   J_PATTERN) creates an ODE options structure with state-specific absolute
%   tolerances, bounded maximum step, optional events, and Jacobian sparsity.
%
%   Inputs:
%     profile        - Structure from ironair_resolution_profile.
%     state_scale    - Positive characteristic magnitude of each state.
%     event_function - Function handle or [].
%     j_pattern      - Logical/sparse Jacobian pattern or [].
%
%   Output:
%     options - Structure accepted by ode15s and ode45.
%
%   Units: STATE_SCALE uses each corresponding state unit; solver tolerances
%   inherit those units.
%   Requirements: SRS018, SRS023.

arguments
    profile (1, 1) struct
    state_scale (:, 1) double {mustBePositive}
    event_function = []
    j_pattern = []
end

required = ["rel_tol", "abs_tol_scale", "max_step_s"];
if ~all(isfield(profile, required))
    error("ironair:solver:InvalidProfile", ...
        "Resolution profile is missing solver settings.");
end

machine_floor = sqrt(eps);
abs_tol = max(machine_floor, ...
    profile.rel_tol .* profile.abs_tol_scale .* state_scale);
options = odeset( ...
    "RelTol", profile.rel_tol, ...
    "AbsTol", abs_tol, ...
    "MaxStep", profile.max_step_s, ...
    "Stats", "off");

if ~isempty(event_function)
    if ~isa(event_function, "function_handle")
        error("ironair:solver:InvalidEventFunction", ...
            "event_function must be a function handle or empty.");
    end
    options = odeset(options, "Events", event_function);
end
if ~isempty(j_pattern)
    if ~ismatrix(j_pattern) || size(j_pattern, 1) ~= numel(state_scale) || ...
            size(j_pattern, 2) ~= numel(state_scale)
        error("ironair:solver:InvalidJPattern", ...
            "j_pattern must be square with one row per state.");
    end
    options = odeset(options, "JPattern", sparse(logical(j_pattern)));
end
end
