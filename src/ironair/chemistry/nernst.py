"""Nernst equilibrium potentials for the SDRS couples.

Solid Fe, Fe(OH)2, and Fe3O4 have unit activity. Dissolved species use
relative activities; gases use p / P_REF.

E = E0 + (RT / nF) * ln(Q)

@relation(IA-CHM-008, scope=module)
"""

from __future__ import annotations

import math

from ironair.constants import constants
from ironair.exceptions import DomainError

# Literature alkaline standard potentials versus SHE at 298.15 K.
E0_FE_OH2_V: float = -0.877
E0_MAGNETITE_V: float = -0.912
E0_ORR_V: float = 0.401
E0_HER_V: float = -0.828


def _ln_term(value: float, name: str) -> float:
    if value <= 0.0:
        raise DomainError(f"{name} must be positive for Nernst logarithms")
    return math.log(value)


def nernst_iron_v(temperature_K: float, a_oh: float) -> float:
    """Fe + 2 OH- <-> Fe(OH)2 + 2 e-

    E = E0 - (RT/2F) ln(a_OH^2)

    @relation(IA-CHM-008, scope=function)
    @relation(IA-CHM-002, scope=function)
    """
    if temperature_K <= 0.0:
        raise DomainError("temperature must be positive")
    rt_nf = constants.R_J_MOL_K * temperature_K / (2.0 * constants.F_C_MOL)
    return E0_FE_OH2_V - rt_nf * _ln_term(a_oh * a_oh, "a_OH")


def nernst_magnetite_v(temperature_K: float, a_oh: float, a_h2o: float) -> float:
    """3 Fe(OH)2 + 2 OH- <-> Fe3O4 + 4 H2O + 2 e-

    E = E0 + (RT/2F) ln(a_H2O^4 / a_OH^2)

    @relation(IA-CHM-008, scope=function)
    @relation(IA-CHM-003, scope=function)
    """
    if temperature_K <= 0.0:
        raise DomainError("temperature must be positive")
    rt_nf = constants.R_J_MOL_K * temperature_K / (2.0 * constants.F_C_MOL)
    q = (a_h2o**4) / (a_oh * a_oh)
    return E0_MAGNETITE_V + rt_nf * _ln_term(q, "magnetite quotient")


def nernst_oxygen_v(temperature_K: float, p_o2_pa: float, a_oh: float, a_h2o: float) -> float:
    """O2 + 2 H2O + 4 e- -> 4 OH-

    E = E0 + (RT/4F) ln( (p_O2/Pref) * a_H2O^2 / a_OH^4 )

    @relation(IA-CHM-008, scope=function)
    @relation(IA-CHM-004, scope=function)
    """
    if temperature_K <= 0.0:
        raise DomainError("temperature must be positive")
    rt_nf = constants.R_J_MOL_K * temperature_K / (4.0 * constants.F_C_MOL)
    q = (p_o2_pa / constants.P_REF_PA) * (a_h2o * a_h2o) / (a_oh**4)
    return E0_ORR_V + rt_nf * _ln_term(q, "oxygen quotient")


def nernst_her_v(temperature_K: float, p_h2_pa: float, a_oh: float, a_h2o: float) -> float:
    """2 H2O + 2 e- -> H2 + 2 OH-

    E = E0 + (RT/2F) ln( (p_H2/Pref) * a_OH^2 / a_H2O^2 )

    @relation(IA-CHM-008, scope=function)
    @relation(IA-CHM-006, scope=function)
    """
    if temperature_K <= 0.0:
        raise DomainError("temperature must be positive")
    rt_nf = constants.R_J_MOL_K * temperature_K / (2.0 * constants.F_C_MOL)
    q = (p_h2_pa / constants.P_REF_PA) * (a_oh * a_oh) / (a_h2o * a_h2o)
    return E0_HER_V + rt_nf * _ln_term(q, "HER quotient")


def equilibrium_cell_potential_v(
    temperature_K: float,
    p_o2_pa: float,
    a_oh: float,
    a_h2o: float,
) -> float:
    """E_cell,eq = E_O2 - E_Fe for the principal iron-air couple.

    @relation(IA-CHM-008, scope=function)
    @relation(IA-CHM-009, scope=function)
    """
    return nernst_oxygen_v(temperature_K, p_o2_pa, a_oh, a_h2o) - nernst_iron_v(temperature_K, a_oh)
