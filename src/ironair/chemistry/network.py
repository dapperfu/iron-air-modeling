"""Shared stoichiometric reaction network.

dn/dt = S @ r + B @ q

SDRS reactions:
- Fe + 2 OH- <-> Fe(OH)2 + 2 e-
- 3 Fe(OH)2 + 2 OH- <-> Fe3O4 + 4 H2O + 2 e-  (electrochemical magnetite)
- O2 + 2 H2O + 4 e- -> 4 OH-
- 4 OH- -> O2 + 2 H2O + 4 e-
- 2 H2O + 2 e- -> H2 + 2 OH-
- CO2 + 2 OH- -> CO3^2- + H2O  (carbonation, no electrons)

Positive iron and magnetite rates are anodic (oxidation).

@relation(IA-CHM-001, scope=module)
@relation(IA-SDD-003, scope=module)
@relation(IA-SDD-005, scope=module)
"""

from __future__ import annotations

from dataclasses import dataclass, field
from enum import IntEnum

import numpy as np
from numpy.typing import NDArray

from ironair.chemistry.species import (
    ELEMENT_MATRIX,
    IONIC_CHARGE,
    N_SPECIES,
    SPECIES_NAMES,
    Species,
)
from ironair.constants import constants
from ironair.exceptions import ConservationError, InvalidPhysicalState


class Reaction(IntEnum):
    """Ordered reactions.

    @relation(IA-CHM-001, scope=class)
    @relation(IA-CHM-002, scope=class)
    @relation(IA-CHM-003, scope=class)
    @relation(IA-CHM-004, scope=class)
    @relation(IA-CHM-005, scope=class)
    @relation(IA-CHM-006, scope=class)
    """

    IRON = 0
    MAGNETITE = 1
    ORR = 2
    OER = 3
    HER = 4
    CARBONATION = 5


N_REACTIONS: int = len(Reaction)
REACTION_NAMES: tuple[str, ...] = tuple(r.name for r in Reaction)

# Electrons produced per unit reaction extent (positive = oxidation)
ELECTRONS_PRODUCED: NDArray[np.float64] = np.array(
    [2.0, 2.0, -4.0, 4.0, -2.0, 0.0],
    dtype=np.float64,
)

# S[species, reaction]
STOICHIOMETRY: NDArray[np.float64] = np.zeros((N_SPECIES, N_REACTIONS), dtype=np.float64)

# IRON: Fe + 2 OH- -> Fe(OH)2 + 2 e-
STOICHIOMETRY[Species.FE, Reaction.IRON] = -1.0
STOICHIOMETRY[Species.OH, Reaction.IRON] = -2.0
STOICHIOMETRY[Species.FEOH2, Reaction.IRON] = 1.0

# MAGNETITE: 3 Fe(OH)2 + 2 OH- -> Fe3O4 + 4 H2O + 2 e-
STOICHIOMETRY[Species.FEOH2, Reaction.MAGNETITE] = -3.0
STOICHIOMETRY[Species.OH, Reaction.MAGNETITE] = -2.0
STOICHIOMETRY[Species.FE3O4, Reaction.MAGNETITE] = 1.0
STOICHIOMETRY[Species.H2O, Reaction.MAGNETITE] = 4.0

# ORR: O2 + 2 H2O + 4 e- -> 4 OH-
STOICHIOMETRY[Species.O2, Reaction.ORR] = -1.0
STOICHIOMETRY[Species.H2O, Reaction.ORR] = -2.0
STOICHIOMETRY[Species.OH, Reaction.ORR] = 4.0

# OER: 4 OH- -> O2 + 2 H2O + 4 e-
STOICHIOMETRY[Species.OH, Reaction.OER] = -4.0
STOICHIOMETRY[Species.O2, Reaction.OER] = 1.0
STOICHIOMETRY[Species.H2O, Reaction.OER] = 2.0

# HER: 2 H2O + 2 e- -> H2 + 2 OH-
STOICHIOMETRY[Species.H2O, Reaction.HER] = -2.0
STOICHIOMETRY[Species.H2, Reaction.HER] = 1.0
STOICHIOMETRY[Species.OH, Reaction.HER] = 2.0

# CARBONATION: CO2 + 2 OH- -> CO3^2- + H2O
STOICHIOMETRY[Species.CO2, Reaction.CARBONATION] = -1.0
STOICHIOMETRY[Species.OH, Reaction.CARBONATION] = -2.0
STOICHIOMETRY[Species.CO3, Reaction.CARBONATION] = 1.0
STOICHIOMETRY[Species.H2O, Reaction.CARBONATION] = 1.0

# Identity boundary map: q is molar inflow of each species
BOUNDARY_MAP: NDArray[np.float64] = np.eye(N_SPECIES, dtype=np.float64)


def faraday_rate_mol_s(current_A: float, n_electrons: float) -> float:
    """Convert electrical current to molar reaction rate via Faraday's law.

    r = I / (n F). Sign follows current (anodic positive).

    @relation(IA-CHM-002, scope=function)
    """
    if n_electrons == 0.0:
        raise InvalidPhysicalState("n_electrons must be nonzero for Faraday mapping")
    return current_A / (n_electrons * constants.F_C_MOL)


def current_from_rate_A(rate_mol_s: float, n_electrons: float) -> float:
    """I = n F r.

    @relation(IA-CHM-002, scope=function)
    """
    return n_electrons * constants.F_C_MOL * rate_mol_s


@dataclass(frozen=True, slots=True)
class ReactionNetwork:
    """Stoichiometric network with elemental conservation checks.

    @relation(IA-CHM-001, scope=class)
    @relation(IA-CHM-010, scope=class)
    """

    S: NDArray[np.float64] = field(default_factory=lambda: STOICHIOMETRY.copy())
    B: NDArray[np.float64] = field(default_factory=lambda: BOUNDARY_MAP.copy())
    electrons: NDArray[np.float64] = field(default_factory=lambda: ELECTRONS_PRODUCED.copy())

    def inventory_derivative(
        self,
        rates_mol_s: NDArray[np.float64],
        boundary_mol_s: NDArray[np.float64] | None = None,
    ) -> NDArray[np.float64]:
        """dn/dt = S @ r + B @ q.

        @relation(IA-CHM-001, scope=function)
        """
        rates = np.asarray(rates_mol_s, dtype=np.float64)
        if rates.shape != (N_REACTIONS,):
            raise InvalidPhysicalState(f"rate vector shape {rates.shape}")
        boundary = (
            np.zeros(N_SPECIES, dtype=np.float64)
            if boundary_mol_s is None
            else np.asarray(boundary_mol_s, dtype=np.float64)
        )
        if boundary.shape != (N_SPECIES,):
            raise InvalidPhysicalState(f"boundary vector shape {boundary.shape}")
        return self.S @ rates + self.B @ boundary

    def elemental_residuals(self, dn_dt: NDArray[np.float64]) -> NDArray[np.float64]:
        """Element production rates. Closed-system reactions must yield ~0.

        @relation(IA-CHM-010, scope=function)
        @relation(IA-TST-001, scope=function)
        """
        return ELEMENT_MATRIX @ np.asarray(dn_dt, dtype=np.float64)

    def charge_residual(self, rates_mol_s: NDArray[np.float64]) -> float:
        """Ionic charge production minus electron production (should be 0).

        @relation(IA-CHM-010, scope=function)
        @relation(IA-TST-002, scope=function)
        """
        rates = np.asarray(rates_mol_s, dtype=np.float64)
        ionic = float(IONIC_CHARGE @ (self.S @ rates))
        electrons = float(self.electrons @ rates)
        return ionic - electrons

    def assert_stoichiometry(self, atol: float = 1e-12) -> None:
        """Require E @ S = 0 and charge/electron balance for every reaction.

        @relation(IA-CHM-001, scope=function)
        @relation(IA-CHM-010, scope=function)
        @relation(IA-TST-001, scope=function)
        """
        residual = ELEMENT_MATRIX @ self.S
        if float(np.max(np.abs(residual))) > atol:
            raise ConservationError(f"elemental stoichiometry residual {residual}")
        for j, reaction in enumerate(Reaction):
            ionic = float(IONIC_CHARGE @ self.S[:, j])
            electrons = float(self.electrons[j])
            if abs(ionic - electrons) > atol:
                raise ConservationError(f"{reaction.name}: ionic charge {ionic} != electrons {electrons}")


DEFAULT_NETWORK: ReactionNetwork = ReactionNetwork()
DEFAULT_NETWORK.assert_stoichiometry()

__all__ = [
    "BOUNDARY_MAP",
    "DEFAULT_NETWORK",
    "ELECTRONS_PRODUCED",
    "N_REACTIONS",
    "REACTION_NAMES",
    "Reaction",
    "ReactionNetwork",
    "SPECIES_NAMES",
    "STOICHIOMETRY",
    "current_from_rate_A",
    "faraday_rate_mol_s",
]
