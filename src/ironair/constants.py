"""Immutable physical constants for ironair.

Values are CODATA 2018 / IUPAC standard masses, not recovered from prior models.

@relation(IA-CON-001, scope=module)
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Final


@dataclass(frozen=True, slots=True)
class Constants:
    """Frozen SI constants used throughout the package.

    @relation(IA-CON-001, scope=class)
    """

    F_C_MOL: float = 96485.3321233100184
    """Faraday constant (C/mol), CODATA 2018."""

    R_J_MOL_K: float = 8.314462618
    """Molar gas constant (J/(mol*K)), CODATA 2018."""

    T_REF_K: float = 298.15
    """Reference temperature (K)."""

    P_REF_PA: float = 101325.0
    """Reference pressure (Pa)."""

    M_FE_KG_MOL: float = 0.055845
    """Molar mass of Fe (kg/mol)."""

    M_O2_KG_MOL: float = 0.0319988
    """Molar mass of O2 (kg/mol)."""

    M_H2O_KG_MOL: float = 0.01801528
    """Molar mass of H2O (kg/mol)."""

    M_KOH_KG_MOL: float = 0.05610564
    """Molar mass of KOH (kg/mol)."""

    M_H2_KG_MOL: float = 0.00201588
    """Molar mass of H2 (kg/mol)."""

    M_K_KG_MOL: float = 0.0390983
    """Molar mass of K (kg/mol)."""

    M_FEOH2_KG_MOL: float = 0.08985956
    """Molar mass of Fe(OH)2 (kg/mol)."""

    M_FE3O4_KG_MOL: float = 0.2315322
    """Molar mass of Fe3O4 (kg/mol)."""

    M_CO2_KG_MOL: float = 0.0440095
    """Molar mass of CO2 (kg/mol)."""

    M_CO3_KG_MOL: float = 0.0600089
    """Molar mass of CO3 (kg/mol)."""

    M_OH_KG_MOL: float = 0.01700734
    """Molar mass of OH (kg/mol)."""


constants: Final[Constants] = Constants()

F_C_MOL: Final[float] = constants.F_C_MOL
R_J_MOL_K: Final[float] = constants.R_J_MOL_K
T_REF_K: Final[float] = constants.T_REF_K
P_REF_PA: Final[float] = constants.P_REF_PA
M_FE_KG_MOL: Final[float] = constants.M_FE_KG_MOL
M_O2_KG_MOL: Final[float] = constants.M_O2_KG_MOL
M_H2O_KG_MOL: Final[float] = constants.M_H2O_KG_MOL
M_KOH_KG_MOL: Final[float] = constants.M_KOH_KG_MOL

__all__ = [
    "Constants",
    "constants",
    "F_C_MOL",
    "R_J_MOL_K",
    "T_REF_K",
    "P_REF_PA",
    "M_FE_KG_MOL",
    "M_O2_KG_MOL",
    "M_H2O_KG_MOL",
    "M_KOH_KG_MOL",
]
