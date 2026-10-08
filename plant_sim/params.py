"""Patent- and requirements-aligned physical parameters.

Defaults:
  25 C / 1 atm (US12308414B2 room-temperature and STP definitions)
  6 M KOH at 303 K (EP4602674A1 FIGS. 19-26 simulation reference)
  960 mAh/g Fe to Fe(OH)2 and 320 mAh/g Fe to Fe3O4 (EP4602674A1 [0042]-[0043])

@relation(IA-SYS-020, scope=module)
@relation(IA-SYS-021, scope=module)
@relation(IA-SYS-022, scope=module)
@relation(IA-SCN-PAT-PO2, scope=module)
@relation(IA-FE-001, scope=module)
"""

from __future__ import annotations

from dataclasses import dataclass, field, replace

import numpy as np

from plant_sim.bootstrap import setup_path

setup_path()

from ironair.constants import constants  # noqa: E402
from ironair.properties import (  # noqa: E402
    koh_conductivity_s_m,
    koh_density_kg_m3,
    koh_heat_capacity_j_kg_k,
    koh_viscosity_pa_s,
    koh_water_activity,
)


def theoretical_capacity_mah_g_fe(n_electrons_per_fe: float) -> float:
    """Faraday capacity of metallic iron in mAh per gram.

    Q = n F / M_Fe / 3.6  with F in C/mol and M_Fe in kg/mol.
    n = 2 yields ~960 mAh/g (Fe to Fe(OH)2).
    n = 2/3 yields ~320 mAh/g (three Fe(OH)2 to Fe3O4).
    """
    coulomb_per_kg = n_electrons_per_fe * constants.F_C_MOL / constants.M_FE_KG_MOL
    # 1 mAh = 3.6 C, and 1 kg = 1000 g → mAh/g
    return coulomb_per_kg / 3.6 / 1000.0


CAPACITY_FE_OH2_MAH_G: float = theoretical_capacity_mah_g_fe(2.0)
CAPACITY_MAGNETITE_MAH_G: float = theoretical_capacity_mah_g_fe(2.0 / 3.0)


@dataclass(frozen=True, slots=True)
class PlantParams:
    """SI parameters for isolated components and the assembled plant."""

    # Ambient / reference (US12308414B2 STP)
    T_ref_K: float = constants.T_REF_K
    T_ep_sim_K: float = 303.15
    P_atm_Pa: float = constants.P_REF_PA
    g_m_s2: float = 9.80665

    # Electrolyte (IA-SYS-021)
    c_KOH_mol_m3: float = 6000.0
    electrolyte_recipe: str = "6M_KOH"

    # Geometric defaults, 5 cm x 5 cm anode (SSS003 asymmetric 100/300 h example)
    A_geom_m2: float = 0.05 * 0.05
    L_anode_m: float = 0.04
    loading_g_cm2: float = 3.0
    vf_electrolyte_charged: float = 0.70
    porosity_rib: float = 0.60
    chan_frac: float = 0.40

    # EP4602674A1 channel windows (Claims 1, 16-17 and related)
    channel_length_m: float = 0.020
    channel_width_m: float = 0.010
    channel_spacing_m: float = 0.020
    channel_length_min_m: float = 0.003
    channel_length_max_m: float = 0.050
    channel_width_min_m: float = 0.001
    channel_width_max_m: float = 0.040
    channel_spacing_min_m: float = 0.010
    channel_spacing_max_m: float = 0.050
    loading_min_g_cm2: float = 1.0
    loading_max_g_cm2: float = 7.0
    vf_min: float = 0.50
    vf_max: float = 0.90

    # LODES duration scaling (US12308414B2 Lc vs Ld)
    t_charge_s: float = 100.0 * 3600.0
    t_discharge_s: float = 100.0 * 3600.0
    L_charge_m: float = 0.04
    L_discharge_m: float = 0.05

    # Kinetics (engineering, Arrhenius-scaled from 298.15 K)
    i0_fe_A_m2: float = 8.0
    i0_mag_A_m2: float = 1.5
    i0_her_A_m2: float = 0.04
    i0_orr_A_m2: float = 0.8
    i0_oer_A_m2: float = 0.5
    alpha_a: float = 0.5
    alpha_c: float = 0.5
    Ea_fe_J_mol: float = 4.5e4
    Ea_her_J_mol: float = 5.0e4
    Ea_orr_J_mol: float = 4.0e4
    Ea_oer_J_mol: float = 5.5e4

    # Double-layer / interfacial
    C_dl_orr_F_m2: float = 0.20
    C_dl_oer_F_m2: float = 0.15

    # GDL
    n_gdl_nodes: int = 8
    L_gdl_m: float = 4.0e-4
    eps_gdl: float = 0.75
    s_flood_drain_1_s: float = 0.02
    k_flood_m_s: float = 1.0e-5

    # Separator
    L_sep_m: float = 2.0e-4
    eps_sep: float = 0.55
    tortuosity_sep: float = 1.8
    k_o2_block: float = 50.0

    # Current collector
    R_col_ref_ohm: float = 2.0e-4
    alpha_R_T_1_K: float = 0.0039
    k_deg_1_s: float = 1.0e-8

    # Thermal
    m_fe_kg: float = field(init=False, default=0.0)
    Cp_fe_J_kg_K: float = 450.0
    h_conv_W_m2_K: float = 12.0
    A_thermal_m2: float = 0.08
    m_vessel_kg: float = 25.0
    Cp_steel_J_kg_K: float = 500.0

    # Air
    V_manifold_m3: float = 0.02
    V_headspace_m3: float = 0.05
    x_O2_air: float = 0.2095
    x_CO2_air: float = 4.2e-4
    pO2_discharge_min_atm: float = 0.01
    pO2_discharge_max_atm: float = 100.0
    pO2_charge_min_atm: float = 0.001
    pO2_charge_max_atm: float = 100.0

    # Hydraulics
    V_reservoir_m3: float = 0.08
    pump_tau_s: float = 2.0
    valve_tau_s: float = 1.0

    # Electrical
    C_dc_F: float = 0.02
    n_cells_series: int = 12
    n_cells_parallel: int = 4
    n_stacks: int = 2
    inverter_eta: float = 0.96
    grid_V_rms: float = 480.0
    grid_f_Hz: float = 60.0

    # Carbonation
    k_carb_m3_mol_s: float = 2.0e-4

    # Passivation
    k_pass_m4_mol: float = 8.0e-10
    delta_pass_ref_m: float = 5.0e-8

    # Stacked ORR
    n_orr_stack: int = 6
    stack_depth_m: float = 0.6

    # Fan
    J_fan_kg_m2: float = 0.004
    b_fan_Nms: float = 0.002
    k_fan_Nm_A: float = 0.08

    extra: dict[str, float] = field(default_factory=dict)

    def __post_init__(self) -> None:
        area_cm2 = self.A_geom_m2 * 1.0e4
        mass_g = self.loading_g_cm2 * area_cm2
        object.__setattr__(self, "m_fe_kg", mass_g / 1000.0)

    @property
    def n_Fe0_mol(self) -> float:
        return self.m_fe_kg / constants.M_FE_KG_MOL

    @property
    def Q_step1_C(self) -> float:
        return 2.0 * constants.F_C_MOL * self.n_Fe0_mol

    @property
    def Q_step2_C(self) -> float:
        return (2.0 / 3.0) * constants.F_C_MOL * self.n_Fe0_mol

    @property
    def I_discharge_100h_A(self) -> float:
        return self.Q_step1_C / (100.0 * 3600.0)

    def koh_state(self, temperature_K: float | None = None) -> dict[str, float]:
        T = self.T_ep_sim_K if temperature_K is None else temperature_K
        c = self.c_KOH_mol_m3
        return {
            "T_K": T,
            "c_KOH_mol_m3": c,
            "density_kg_m3": koh_density_kg_m3(T, c),
            "sigma_S_m": koh_conductivity_s_m(T, c),
            "mu_Pa_s": koh_viscosity_pa_s(T, c),
            "Cp_J_kg_K": koh_heat_capacity_j_kg_k(T, c),
            "a_H2O": koh_water_activity(T, c),
            "a_OH": max(c / 1000.0, 1e-12),
        }

    def with_duration(self, t_charge_h: float, t_discharge_h: float) -> PlantParams:
        """Map LODES hours to anode thickness (US ~3-5 cm / 100 h, 4-6 cm / 300 h)."""
        L_c = 0.04 * (t_charge_h / 100.0)
        L_d = 0.05 * (t_discharge_h / 100.0)
        return replace(
            self,
            t_charge_s=t_charge_h * 3600.0,
            t_discharge_s=t_discharge_h * 3600.0,
            L_charge_m=float(np.clip(L_c, 0.01, 0.12)),
            L_discharge_m=float(np.clip(L_d, 0.01, 0.12)),
            L_anode_m=float(np.clip(max(L_c, L_d), 0.01, 0.12)),
        )

    def with_recipe(self, name: str) -> PlantParams:
        recipes = {
            "6M_KOH": 6000.0,
            "5.5M_KOH_0.5M_LiOH": 6000.0,
            "6M_NaOH": 6000.0,
            "5M_NaOH_1M_KOH": 6000.0,
            "7M_KOH": 7000.0,
            "8M_KOH": 8000.0,
            "4M_KOH": 4000.0,
        }
        if name not in recipes:
            raise ValueError(f"unknown electrolyte recipe {name}")
        return replace(self, c_KOH_mol_m3=recipes[name], electrolyte_recipe=name)


def default_params() -> PlantParams:
    return PlantParams()
