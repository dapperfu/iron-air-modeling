function [kappa_S_m, diagnostics] = ironair_KOH_conductivity(c_KOH_mol_m3, T_K, p)
%IRONAIR_KOH_CONDUCTIVITY Return an assumed KOH ionic conductivity.
%   [KAPPA_S_M, DIAGNOSTICS] = IRONAIR_KOH_CONDUCTIVITY(C_KOH_MOL_M3, T_K, P)
%   evaluates a documented engineering correlation, not validated commercial
%   electrolyte data.
%
%   Inputs:
%     c_KOH_mol_m3 - KOH concentration, mol/m3.
%     T_K          - Temperature, K.
%     p            - Complete parameter structure.
%
%   Outputs:
%     kappa_S_m   - Ionic conductivity, S/m.
%     diagnostics - Extrapolation diagnostics.
%
%   Equation: ELY-006
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

c_ref = p.electrolyte.c_property_ref_mol_m3;
frac = c_KOH_mol_m3 ./ c_ref;
% ELY-006: assumed peaked conductivity about the reference concentration.
kappa_S_m = p.electrolyte.kappa_ref_S_m .* max(0, frac .* (2 - frac)) .* ...
    (1 + p.electrolyte.kappa_temp_coeff_1_K .* (T_K - p.constants.T_ref_K));

diagnostics = struct("concentration", d_c, "temperature", d_T, ...
    "classification", "ASSUMED");
end
