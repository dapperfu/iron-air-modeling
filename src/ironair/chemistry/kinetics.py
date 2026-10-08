"""Butler-Volmer electrode kinetics.

Positive current density is anodic.

i = i0 * availability * area_factor
    * (a_red * exp(alpha_a F eta / RT) - a_ox * exp(-alpha_c F eta / RT))

@relation(IA-CHM-007, scope=module)
"""

from __future__ import annotations

import math

from ironair.constants import constants
from ironair.exceptions import DomainError, InvalidPhysicalState
from ironair.properties import arrhenius_rate

EXP_ARG_MAX: float = 80.0


def _clip_exp(argument: float) -> float:
    return math.exp(min(max(argument, -EXP_ARG_MAX), EXP_ARG_MAX))


def butler_volmer_current_density_a_m2(
    eta_V: float,
    i0_A_m2: float,
    alpha_a: float,
    alpha_c: float,
    temperature_K: float,
    activity_ox: float = 1.0,
    activity_red: float = 1.0,
    availability: float = 1.0,
) -> float:
    """Nonlinear Butler-Volmer current density (A/m2).

    @relation(IA-CHM-007, scope=function)
    """
    if temperature_K <= 0.0:
        raise DomainError("temperature must be positive")
    if i0_A_m2 < 0.0:
        raise DomainError("exchange-current density must be nonnegative")
    if alpha_a <= 0.0 or alpha_c <= 0.0:
        raise DomainError("transfer coefficients must be positive")
    if activity_ox < 0.0 or activity_red < 0.0 or availability < 0.0:
        raise InvalidPhysicalState("activities and availability must be nonnegative")
    if availability == 0.0 or i0_A_m2 == 0.0:
        return 0.0
    rt = constants.R_J_MOL_K * temperature_K
    fa = constants.F_C_MOL / rt
    anodic = activity_red * _clip_exp(alpha_a * fa * eta_V)
    cathodic = activity_ox * _clip_exp(-alpha_c * fa * eta_V)
    return i0_A_m2 * availability * (anodic - cathodic)


def faradaic_current_A(
    current_density_a_m2: float,
    area_m2: float,
) -> float:
    """I = i * A.

    @relation(IA-CHM-007, scope=function)
    """
    if area_m2 < 0.0:
        raise DomainError("electrode area must be nonnegative")
    return current_density_a_m2 * area_m2


def temperature_scaled_i0_a_m2(
    i0_ref_A_m2: float,
    activation_energy_j_mol: float,
    temperature_K: float,
) -> float:
    """Arrhenius exchange-current density.

    @relation(IA-CHM-007, scope=function)
    @relation(IA-CON-003, scope=function)
    """
    return arrhenius_rate(i0_ref_A_m2, activation_energy_j_mol, temperature_K)
