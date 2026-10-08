"""Concentration- and temperature-dependent material properties.

Correlations are documented literature or engineering fits for this Python
baseline. They are not recovered from prior MATLAB sources.

Valid KOH domain: 273.15 K to 373.15 K, 0 to 12 mol/L.

@relation(IA-CON-003, scope=module)
"""

from __future__ import annotations

import math

from ironair.constants import constants
from ironair.exceptions import DomainError

T_MIN_K: float = 273.15
T_MAX_K: float = 373.15
C_KOH_MIN_MOL_M3: float = 0.0
C_KOH_MAX_MOL_M3: float = 12000.0
WATER_DENSITY_REF_KG_M3: float = 997.0
KOH_CONDUCTIVITY_PEAK_MOL_M3: float = 7000.0


def _check_domain(temperature_K: float, c_koh_mol_m3: float) -> None:
    if not (T_MIN_K <= temperature_K <= T_MAX_K):
        raise DomainError(f"temperature {temperature_K} K outside [{T_MIN_K}, {T_MAX_K}]")
    if not (C_KOH_MIN_MOL_M3 <= c_koh_mol_m3 <= C_KOH_MAX_MOL_M3):
        raise DomainError(
            f"c_KOH {c_koh_mol_m3} mol/m3 outside [{C_KOH_MIN_MOL_M3}, {C_KOH_MAX_MOL_M3}]"
        )


def koh_density_kg_m3(temperature_K: float, c_koh_mol_m3: float) -> float:
    """KOH aqueous density (kg/m3).

    Engineering polynomial in molarity and temperature, anchored at dilute-water
    density near 298.15 K. Literature classification: engineering design assumption.

    @relation(IA-CON-003, scope=function)
    """
    _check_domain(temperature_K, c_koh_mol_m3)
    m_mol_l = c_koh_mol_m3 / 1000.0
    dT = temperature_K - constants.T_REF_K
    return WATER_DENSITY_REF_KG_M3 + 46.0 * m_mol_l - 0.9 * m_mol_l * m_mol_l - 0.35 * dT


def koh_conductivity_s_m(temperature_K: float, c_koh_mol_m3: float) -> float:
    """KOH ionic conductivity (S/m).

    Unimodal in concentration with a peak near 7 mol/L and Arrhenius-like
    temperature increase. Engineering design assumption pending calibration.

    @relation(IA-CON-003, scope=function)
    """
    _check_domain(temperature_K, c_koh_mol_m3)
    m_mol_l = c_koh_mol_m3 / 1000.0
    sigma_25 = 22.0 * m_mol_l * math.exp(-((m_mol_l - 7.0) ** 2) / 32.0)
    return max(sigma_25 * math.exp(0.018 * (temperature_K - constants.T_REF_K)), 0.0)


def koh_viscosity_pa_s(temperature_K: float, c_koh_mol_m3: float) -> float:
    """KOH dynamic viscosity (Pa*s).

    @relation(IA-CON-003, scope=function)
    """
    _check_domain(temperature_K, c_koh_mol_m3)
    m_mol_l = c_koh_mol_m3 / 1000.0
    mu_water = 2.414e-5 * 10.0 ** (247.8 / (temperature_K - 140.0))
    return mu_water * (1.0 + 0.12 * m_mol_l + 0.015 * m_mol_l * m_mol_l)


def koh_heat_capacity_j_kg_k(temperature_K: float, c_koh_mol_m3: float) -> float:
    """KOH solution specific heat (J/(kg*K)).

    @relation(IA-CON-003, scope=function)
    """
    _check_domain(temperature_K, c_koh_mol_m3)
    m_mol_l = c_koh_mol_m3 / 1000.0
    return 4180.0 - 55.0 * m_mol_l + 0.2 * (temperature_K - constants.T_REF_K)


def koh_water_activity(temperature_K: float, c_koh_mol_m3: float) -> float:
    """Water activity in aqueous KOH, dimensionless.

    Decreases with KOH mole fraction. Engineering design assumption.

    @relation(IA-CON-003, scope=function)
    """
    _check_domain(temperature_K, c_koh_mol_m3)
    density = koh_density_kg_m3(temperature_K, c_koh_mol_m3)
    n_koh = c_koh_mol_m3
    n_h2o = (density - n_koh * constants.M_KOH_KG_MOL) / constants.M_H2O_KG_MOL
    if n_h2o <= 0.0:
        raise DomainError("KOH concentration leaves nonphysical water content")
    x_h2o = n_h2o / (n_h2o + n_koh)
    osmotic = 1.0 + 0.08 * (c_koh_mol_m3 / 1000.0)
    activity = x_h2o * math.exp(-osmotic * (1.0 - x_h2o))
    return min(max(activity, 1e-8), 1.0)


def dissolved_oxygen_solubility_mol_m3(
    temperature_K: float,
    c_koh_mol_m3: float,
    p_o2_pa: float,
) -> float:
    """Henry-like O2 solubility with KOH salting-out (mol/m3).

    @relation(IA-CON-003, scope=function)
    """
    _check_domain(temperature_K, c_koh_mol_m3)
    if p_o2_pa < 0.0:
        raise DomainError(f"p_O2 {p_o2_pa} Pa is negative")
    henry_298 = 1.3e-5 * 101325.0
    henry = henry_298 * math.exp(-1700.0 * (1.0 / temperature_K - 1.0 / constants.T_REF_K))
    sechenov = math.exp(-0.12 * (c_koh_mol_m3 / 1000.0))
    return henry * (p_o2_pa / constants.P_REF_PA) * sechenov


def oxygen_diffusivity_m2_s(temperature_K: float, c_koh_mol_m3: float) -> float:
    """Dissolved oxygen diffusivity (m2/s).

    @relation(IA-CON-003, scope=function)
    """
    _check_domain(temperature_K, c_koh_mol_m3)
    d25 = 2.0e-9 / (1.0 + 0.15 * (c_koh_mol_m3 / 1000.0))
    return d25 * (temperature_K / constants.T_REF_K)


def gas_phase_diffusivity_m2_s(temperature_K: float, pressure_pa: float) -> float:
    """Binary gas diffusivity scaling for O2-N2 (m2/s).

    @relation(IA-CON-003, scope=function)
    """
    if temperature_K <= 0.0:
        raise DomainError("temperature must be positive")
    if pressure_pa <= 0.0:
        raise DomainError("pressure must be positive")
    d_ref = 2.0e-5
    return d_ref * (temperature_K / constants.T_REF_K) ** 1.75 * (constants.P_REF_PA / pressure_pa)


def iron_conductivity_s_m(temperature_K: float) -> float:
    """Metallic iron electronic conductivity (S/m).

    @relation(IA-CON-003, scope=function)
    """
    if not (T_MIN_K <= temperature_K <= T_MAX_K):
        raise DomainError(f"temperature {temperature_K} K outside iron conductivity domain")
    return 1.0e7 / (1.0 + 0.005 * (temperature_K - constants.T_REF_K))


def thermal_conductivity_w_m_k(temperature_K: float, material: str = "electrolyte") -> float:
    """Thermal conductivity (W/(m*K)) for named lumped materials.

    @relation(IA-CON-003, scope=function)
    """
    if not (T_MIN_K <= temperature_K <= T_MAX_K):
        raise DomainError(f"temperature {temperature_K} K outside thermal conductivity domain")
    table = {
        "electrolyte": 0.60,
        "iron": 80.0,
        "separator": 0.30,
        "gdl": 0.40,
        "steel": 16.0,
        "air": 0.026,
    }
    if material not in table:
        raise DomainError(f"unknown material {material}")
    return table[material]


def arrhenius_rate(
    k_ref: float,
    activation_energy_j_mol: float,
    temperature_K: float,
) -> float:
    """Temperature-scaled rate or exchange-current prefactor.

    @relation(IA-CON-003, scope=function)
    """
    if temperature_K <= 0.0:
        raise DomainError("temperature must be positive")
    if k_ref < 0.0:
        raise DomainError("rate prefactor must be nonnegative")
    return k_ref * math.exp(
        -activation_energy_j_mol
        / constants.R_J_MOL_K
        * (1.0 / temperature_K - 1.0 / constants.T_REF_K)
    )
