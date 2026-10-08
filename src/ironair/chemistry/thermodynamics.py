"""Reaction thermodynamics derived from Nernst potentials.

DeltaG = -n F E_eq
q_rev = T * DeltaS * r
q_irrev = eta * I   (J/s); anodic or cathodic dissipation is I*eta with sign
                     reported as heat generation eta*I for the electrode convention
                     q_irrev = I * eta (positive when driving anodic current with
                     positive eta, or cathodic current with negative eta).

@relation(IA-CHM-009, scope=module)
"""

from __future__ import annotations

from dataclasses import dataclass

from ironair.constants import constants
from ironair.exceptions import DomainError


@dataclass(frozen=True, slots=True)
class ReactionThermo:
    """Thermodynamic state of one electrochemical reaction.

    @relation(IA-CHM-009, scope=class)
    """

    n_electrons: float
    e_eq_V: float
    delta_g_j_mol: float
    delta_h_j_mol: float
    delta_s_j_mol_k: float
    reversible_heat_w: float
    irreversible_heat_w: float
    equilibrium_cell_potential_v: float | None = None


def gibbs_from_potential_j_mol(e_eq_V: float, n_electrons: float) -> float:
    """DeltaG = -n F E.

    @relation(IA-CHM-009, scope=function)
    """
    return -n_electrons * constants.F_C_MOL * e_eq_V


def reaction_entropy_j_mol_k(
    e_eq_V: float,
    de_dT_V_per_K: float,
    n_electrons: float,
) -> float:
    """DeltaS = n F (dE/dT).

    @relation(IA-CHM-009, scope=function)
    """
    return n_electrons * constants.F_C_MOL * de_dT_V_per_K


def reaction_enthalpy_j_mol(delta_g_j_mol: float, temperature_K: float, delta_s_j_mol_k: float) -> float:
    """DeltaH = DeltaG + T DeltaS.

    @relation(IA-CHM-009, scope=function)
    """
    if temperature_K <= 0.0:
        raise DomainError("temperature must be positive")
    return delta_g_j_mol + temperature_K * delta_s_j_mol_k


def reversible_heat_w(temperature_K: float, delta_s_j_mol_k: float, rate_mol_s: float) -> float:
    """q_rev = T * DeltaS * r (W). Positive r is the defined reaction direction.

    @relation(IA-CHM-009, scope=function)
    """
    return temperature_K * delta_s_j_mol_k * rate_mol_s


def irreversible_heat_w(eta_V: float, current_A: float) -> float:
    """q_irrev = eta * I (W). Dissipative when eta and I have the same sign.

    @relation(IA-CHM-009, scope=function)
    """
    return eta_V * current_A


def electrochemical_thermo(
    e_eq_V: float,
    n_electrons: float,
    temperature_K: float,
    de_dT_V_per_K: float,
    rate_mol_s: float,
    eta_V: float,
    current_A: float,
    equilibrium_cell_potential_v: float | None = None,
) -> ReactionThermo:
    """Assemble Gibbs, enthalpy, entropy, and heat terms.

    @relation(IA-CHM-009, scope=function)
    """
    delta_g = gibbs_from_potential_j_mol(e_eq_V, n_electrons)
    delta_s = reaction_entropy_j_mol_k(e_eq_V, de_dT_V_per_K, n_electrons)
    delta_h = reaction_enthalpy_j_mol(delta_g, temperature_K, delta_s)
    return ReactionThermo(
        n_electrons=n_electrons,
        e_eq_V=e_eq_V,
        delta_g_j_mol=delta_g,
        delta_h_j_mol=delta_h,
        delta_s_j_mol_k=delta_s,
        reversible_heat_w=reversible_heat_w(temperature_K, delta_s, rate_mol_s),
        irreversible_heat_w=irreversible_heat_w(eta_V, current_A),
        equilibrium_cell_potential_v=equilibrium_cell_potential_v,
    )
