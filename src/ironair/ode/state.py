"""Named state-vector metadata.

@relation(IA-ODE-002, scope=module)
"""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np
from numpy.typing import NDArray

from ironair.exceptions import InvalidPhysicalState


@dataclass(frozen=True, slots=True)
class StateSpec:
    """One entry in a component state vector.

    @relation(IA-ODE-002, scope=class)
    """

    name: str
    unit: str
    description: str
    nonnegative: bool = False
    abs_tol: float = 1e-8


def validate_state_vector(y: NDArray[np.float64], specs: tuple[StateSpec, ...]) -> NDArray[np.float64]:
    """Check length, finiteness, and optional nonnegativity.

    @relation(IA-ODE-002, scope=function)
    @relation(IA-TST-004, scope=function)
    """
    vector = np.asarray(y, dtype=np.float64)
    if vector.ndim != 1:
        raise InvalidPhysicalState("state vector must be 1-D")
    if vector.size != len(specs):
        raise InvalidPhysicalState(f"state length {vector.size} != {len(specs)} specs")
    if not np.all(np.isfinite(vector)):
        raise InvalidPhysicalState("state vector contains non-finite values")
    for value, spec in zip(vector, specs, strict=True):
        if spec.nonnegative and value < 0.0:
            raise InvalidPhysicalState(f"{spec.name} is negative: {value} {spec.unit}")
    return vector
