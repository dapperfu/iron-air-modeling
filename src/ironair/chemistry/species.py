"""Chemical species inventories for the shared iron-air network.

@relation(IA-CHM-001, scope=module)
"""

from __future__ import annotations

from enum import IntEnum

import numpy as np
from numpy.typing import NDArray


class Species(IntEnum):
    """Ordered species in the stoichiometric network.

    @relation(IA-CHM-001, scope=class)
    """

    FE = 0
    FEOH2 = 1
    FE3O4 = 2
    OH = 3
    H2O = 4
    O2 = 5
    H2 = 6
    K = 7
    CO3 = 8
    CO2 = 9


class Element(IntEnum):
    """Conserved elemental rows.

    @relation(IA-CHM-010, scope=class)
    """

    FE = 0
    O = 1
    H = 2
    K = 3
    C = 4


N_SPECIES: int = len(Species)
N_ELEMENTS: int = len(Element)

SPECIES_NAMES: tuple[str, ...] = tuple(s.name for s in Species)

# Elemental composition E[element, species]
ELEMENT_MATRIX: NDArray[np.float64] = np.array(
    [
        # Fe FeOH2 Fe3O4 OH H2O O2 H2 K CO3 CO2
        [1, 1, 3, 0, 0, 0, 0, 0, 0, 0],  # Fe
        [0, 2, 4, 1, 1, 2, 0, 0, 3, 2],  # O
        [0, 2, 0, 1, 2, 0, 2, 0, 0, 0],  # H
        [0, 0, 0, 0, 0, 0, 0, 1, 0, 0],  # K
        [0, 0, 0, 0, 0, 0, 0, 0, 1, 1],  # C
    ],
    dtype=np.float64,
)

IONIC_CHARGE: NDArray[np.float64] = np.array(
    [0.0, 0.0, 0.0, -1.0, 0.0, 0.0, 0.0, 1.0, -2.0, 0.0],
    dtype=np.float64,
)
