"""Element, charge, and stoichiometry checks on inventories and rates.

@relation(IA-CHM-010, scope=module)
@relation(IA-TST-001, scope=module)
"""

from __future__ import annotations

import numpy as np
from numpy.typing import NDArray

from ironair.chemistry.network import DEFAULT_NETWORK, N_REACTIONS, ReactionNetwork
from ironair.chemistry.species import ELEMENT_MATRIX, Element, N_SPECIES
from ironair.exceptions import ConservationError, InvalidPhysicalState

ELEMENT_NAMES: tuple[str, ...] = tuple(e.name for e in Element)


def elemental_inventory(n_mol: NDArray[np.float64]) -> dict[str, float]:
    """Map element name to mole inventory.

    @relation(IA-CHM-010, scope=function)
    """
    n = np.asarray(n_mol, dtype=np.float64)
    if n.shape != (N_SPECIES,):
        raise InvalidPhysicalState("inventory length mismatch")
    atoms = ELEMENT_MATRIX @ n
    return {name: float(atoms[i]) for i, name in enumerate(ELEMENT_NAMES)}


def closed_system_element_residual(
    rates_mol_s: NDArray[np.float64],
    network: ReactionNetwork = DEFAULT_NETWORK,
) -> dict[str, float]:
    """Element production from reactions with q = 0.

    @relation(IA-CHM-010, scope=function)
    @relation(IA-TST-001, scope=function)
    """
    rates = np.asarray(rates_mol_s, dtype=np.float64)
    if rates.shape != (N_REACTIONS,):
        raise InvalidPhysicalState("rate length mismatch")
    dn_dt = network.inventory_derivative(rates)
    residual = network.elemental_residuals(dn_dt)
    return {name: float(residual[i]) for i, name in enumerate(ELEMENT_NAMES)}


def assert_closed_conservation(
    rates_mol_s: NDArray[np.float64],
    atol: float = 1e-12,
    network: ReactionNetwork = DEFAULT_NETWORK,
) -> None:
    """Raise if elements or charge are not conserved.

    @relation(IA-CHM-010, scope=function)
    @relation(IA-TST-001, scope=function)
    @relation(IA-TST-002, scope=function)
    """
    residuals = closed_system_element_residual(rates_mol_s, network)
    for name, value in residuals.items():
        if abs(value) > atol:
            raise ConservationError(f"{name} residual {value}")
    charge = network.charge_residual(np.asarray(rates_mol_s, dtype=np.float64))
    if abs(charge) > atol:
        raise ConservationError(f"charge residual {charge}")
