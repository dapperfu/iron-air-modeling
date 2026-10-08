function [H_O2_mol_m3Pa, diagnostics] = ironair_O2_solubility(c_KOH_mol_m3, T_K, p)
%IRONAIR_O2_SOLUBILITY Return an assumed Henry coefficient for oxygen.
%   [H_O2_MOL_M3PA, DIAGNOSTICS] = IRONAIR_O2_SOLUBILITY(C_KOH_MOL_M3, T_K, P)
%   applies a van't Hoff temperature factor and a Setschenow salt factor.
%
%   Inputs:
%     c_KOH_mol_m3 - KOH concentration, mol/m3.
%     T_K          - Temperature, K.
%     p            - Complete parameter structure.
%
%   Outputs:
%     H_O2_mol_m3Pa - Henry coefficient, mol/(m3 Pa).
%     diagnostics   - Extrapolation diagnostics.
%
%   Equation: ELY-014
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

R = p.constants.R_J_molK;
T_ref = p.constants.T_ref_K;
H_O2_mol_m3Pa = p.gas_properties.H_O2_ref_mol_m3Pa .* ...
    exp(-(p.gas_properties.O2_solution_enthalpy_J_mol ./ R) .* ...
    (1 ./ T_K - 1 ./ T_ref)) .* ...
    exp(-p.gas_properties.O2_salting_coeff_m3_mol .* c_KOH_mol_m3);

diagnostics = struct("concentration", d_c, "temperature", d_T, ...
    "classification", "CALIBRATION_REQUIRED");
end
