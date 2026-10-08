function c = ironair_physical_constants()
%IRONAIR_PHYSICAL_CONSTANTS Return immutable SI physical constants.
%   C = IRONAIR_PHYSICAL_CONSTANTS() returns CODATA constants, standard
%   reference conditions, molar masses, and reaction electron counts.
%
%   Output:
%     c - Scalar structure. Field names carry units where practical.
%
%   Assumptions: Fe/Fe(OH)2 uses a two-electron iron conversion.
%   Sources: SI 2019 exact constants, CODATA 2018 F and R, standard gravity,
%   and standard atomic/molecular molar masses.
%   Requirements: SRS002.1, SRS019.

c = struct();
c.F_C_mol = 96485.33212;
c.R_J_molK = 8.31446261815324;
c.N_A_mol = 6.02214076e23;
c.k_B_J_K = 1.380649e-23;
c.e_C = 1.602176634e-19;
c.T_ref_K = 298.15;
c.p_ref_Pa = 101325;
c.g_m_s2 = 9.80665;
c.sigma_SB_W_m2K4 = 5.670374419e-8;

c.M_Fe_kg_mol = 0.055845;
c.M_O2_kg_mol = 0.031998;
c.M_H2O_kg_mol = 0.01801528;
c.M_KOH_kg_mol = 0.0561056;
c.M_H2_kg_mol = 0.00201588;
c.M_CO2_kg_mol = 0.0440095;
c.M_K_kg_mol = 0.0390983;
c.M_C_kg_mol = 0.012011;

c.n_Fe_FeOH2 = 2;
c.n_ORR = 4;
c.n_OER = 4;
c.n_e_Fe = c.n_Fe_FeOH2;
c.n_e_ORR = c.n_ORR;
c.n_e_OER = c.n_OER;

c.Q_Fe_Ah_kg = c.n_Fe_FeOH2 * c.F_C_mol / ...
    (3600 * c.M_Fe_kg_mol);
c.source_classification = "PHYSICAL_CONSTANT";
c.reference_id = "CODATA-SI-2019";
end
