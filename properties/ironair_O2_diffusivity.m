function [D_O2_m2_s, diagnostics] = ironair_O2_diffusivity(c_KOH_mol_m3, T_K, p)
%IRONAIR_O2_DIFFUSIVITY Return an assumed dissolved-oxygen diffusivity.
%   [D_O2_M2_S, DIAGNOSTICS] = IRONAIR_O2_DIFFUSIVITY(C_KOH_MOL_M3, T_K, P)
%   scales a reference liquid diffusivity with Stokes-Einstein viscosity.
%
%   Inputs:
%     c_KOH_mol_m3 - KOH concentration, mol/m3.
%     T_K          - Temperature, K.
%     p            - Complete parameter structure.
%
%   Outputs:
%     D_O2_m2_s   - Liquid oxygen diffusivity, m2/s.
%     diagnostics - Extrapolation diagnostics.
%
%   Requirements: SRS002.4, SRS004.4, SRS005.3.

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

mu = ironair_KOH_viscosity(c_KOH_mol_m3, T_K, p);
mu_ref = ironair_KOH_viscosity(p.electrolyte.c_property_ref_mol_m3, ...
    p.constants.T_ref_K, p);
D_O2_m2_s = p.gas_properties.D_O2_liquid_ref_m2_s .* ...
    (T_K ./ p.constants.T_ref_K) .* (mu_ref ./ mu);

diagnostics = struct("concentration", d_c, "temperature", d_T, ...
    "classification", "CALIBRATION_REQUIRED");
end
