function [a_H2O, diagnostics] = ironair_KOH_water_activity(c_KOH_mol_m3, T_K, p)
%IRONAIR_KOH_WATER_ACTIVITY Return an assumed KOH water activity.
%   [A_H2O, DIAGNOSTICS] = IRONAIR_KOH_WATER_ACTIVITY(C_KOH_MOL_M3, T_K, P)
%   decreases water activity with KOH concentration.
%
%   Inputs:
%     c_KOH_mol_m3 - KOH concentration, mol/m3.
%     T_K          - Temperature, K.
%     p            - Complete parameter structure.
%
%   Outputs:
%     a_H2O       - Dimensionless water activity.
%     diagnostics - Extrapolation diagnostics.
%
%   Requirements: SRS002.4, SRS005.3, SRS019.

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

a_H2O = max(p.hydrogen_evolution.water_activity_min, ...
    1 - p.electrolyte.water_activity_coeff_m3_mol .* c_KOH_mol_m3) ...
    + 0 .* T_K;

diagnostics = struct("concentration", d_c, "temperature", d_T, ...
    "classification", "ASSUMED");
end
