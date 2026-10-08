function [cp_J_kgK, diagnostics] = ironair_KOH_heat_capacity(c_KOH_mol_m3, T_K, p)
%IRONAIR_KOH_HEAT_CAPACITY Return an assumed KOH specific heat capacity.
%   [CP_J_KGK, DIAGNOSTICS] = IRONAIR_KOH_HEAT_CAPACITY(C_KOH_MOL_M3, T_K, P)
%   reduces water heat capacity with dissolved KOH.
%
%   Inputs:
%     c_KOH_mol_m3 - KOH concentration, mol/m3.
%     T_K          - Temperature, K.
%     p            - Complete parameter structure.
%
%   Outputs:
%     cp_J_kgK    - Specific heat capacity, J/(kg K).
%     diagnostics - Extrapolation diagnostics.
%
%   Requirements: SRS002.4, SRS005.3, SRS008.

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

cp_J_kgK = p.electrolyte.cp_water_ref_J_kgK ...
    - p.electrolyte.cp_c_coeff_J_m3_kgK_mol .* c_KOH_mol_m3 ...
    + 0 .* T_K;

diagnostics = struct("concentration", d_c, "temperature", d_T, ...
    "classification", "ASSUMED");
end
