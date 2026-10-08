function M = ironair_system_mass_matrix(p)
%IRONAIR_SYSTEM_MASS_MATRIX Return the ODE mass matrix for SYS-006.
%   Requirements: SRS018.

arguments
    p (1, 1) struct
end

[x0, ~] = ironair_system_initial_state(p, 0);
M = speye(numel(x0));
end
