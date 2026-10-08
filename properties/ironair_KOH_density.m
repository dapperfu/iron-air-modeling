function [rho_kg_m3, diagnostics] = ironair_KOH_density(c_KOH_mol_m3, T_K, p)
%IRONAIR_KOH_DENSITY Return an assumed aqueous KOH density.
%   [RHO_KG_M3, DIAGNOSTICS] = IRONAIR_KOH_DENSITY(C_KOH_MOL_M3, T_K, P)
%   evaluates a linear concentration and temperature correction about water.
%
%   Inputs:
%     c_KOH_mol_m3 - KOH concentration, mol/m3.
%     T_K          - Temperature, K.
%     p            - Complete parameter structure.
%
%   Outputs:
%     rho_kg_m3   - Density, kg/m3.
%     diagnostics - Extrapolation diagnostics.
%
%   Equation: ELY-012
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

% ELY-012
rho_kg_m3 = p.electrolyte.rho_water_ref_kg_m3 ...
    + p.electrolyte.rho_c_coeff_kg_mol .* c_KOH_mol_m3 ...
    - p.electrolyte.rho_temp_coeff_kg_m3K .* (T_K - p.constants.T_ref_K);

diagnostics = struct("concentration", d_c, "temperature", d_T, ...
    "classification", "ASSUMED");
end
