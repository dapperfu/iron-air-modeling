function [mu_Pa_s, diagnostics] = ironair_KOH_viscosity(c_KOH_mol_m3, T_K, p)
%IRONAIR_KOH_VISCOSITY Return an assumed KOH dynamic viscosity.
%   [MU_PA_S, DIAGNOSTICS] = IRONAIR_KOH_VISCOSITY(C_KOH_MOL_M3, T_K, P)
%   increases viscosity with concentration and decreases it with temperature.
%
%   Inputs:
%     c_KOH_mol_m3 - KOH concentration, mol/m3.
%     T_K          - Temperature, K.
%     p            - Complete parameter structure.
%
%   Outputs:
%     mu_Pa_s     - Dynamic viscosity, Pa s.
%     diagnostics - Extrapolation diagnostics.
%
%   Equation: ELY-013
%   Requirements: SRS002.4, SRS005.3.

arguments
    c_KOH_mol_m3 double
    T_K double
    p (1, 1) struct
end

policy = ironair_property_policy(p);
[c_KOH_mol_m3, d_c] = ironair_property_guard(c_KOH_mol_m3, ...
    [p.electrolyte.c_property_min_mol_m3, p.electrolyte.c_property_max_mol_m3], ...
    policy, "c_KOH_mol_m3");
[T_K, d_T] = ironair_property_guard(T_K, ...
    [p.electrolyte.T_property_min_K, p.electrolyte.T_property_max_K], ...
    policy, "T_K");

% ELY-013
mu_Pa_s = p.electrolyte.mu_ref_Pa_s .* ...
    (1 + p.electrolyte.mu_c_coeff_m3_mol .* c_KOH_mol_m3) .* ...
    exp(p.electrolyte.mu_temp_coeff_1_K .* (p.constants.T_ref_K - T_K));

diagnostics = struct("concentration", d_c, "temperature", d_T, ...
    "classification", "ASSUMED");
end
