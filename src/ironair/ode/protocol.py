"""Common dynamic-component protocol.

@relation(IA-ODE-001, scope=module)
@relation(IA-SYS-003, scope=module)
"""

from __future__ import annotations

from collections.abc import Mapping, Sequence
from typing import Any, Protocol, runtime_checkable

import numpy as np
from numpy.typing import NDArray

from ironair.ode.state import StateSpec
from ironair.parameters import ParameterSet

Inputs = Mapping[str, float]
Context = Mapping[str, Any]


@runtime_checkable
class DynamicComponentProtocol(Protocol):
    """Structural interface required of every dynamic component.

    @relation(IA-ODE-001, scope=class)
    @relation(IA-SYS-003, scope=class)
    """

    name: str
    requirement_ids: tuple[str, ...]
    reduced_order: bool

    def state_specs(self) -> tuple[StateSpec, ...]:
        """Named layout of the local state vector."""
        ...

    def y0(self) -> NDArray[np.float64]:
        """Initial conditions as a 1-D NumPy array."""
        ...

    def parameters(self) -> ParameterSet:
        """Typed physical parameters."""
        ...

    def input_names(self) -> Sequence[str]:
        """Required input keys."""
        ...

    def output_names(self) -> Sequence[str]:
        """Keys produced by outputs()."""
        ...

    def rhs(
        self,
        t: float,
        y: NDArray[np.float64],
        inputs: Inputs,
        context: Context,
    ) -> NDArray[np.float64]:
        """Return dy/dt. Must be deterministic and free of hidden mutation."""
        ...

    def outputs(
        self,
        t: float,
        y: NDArray[np.float64],
        inputs: Inputs,
        context: Context,
    ) -> dict[str, float]:
        """Algebraic outputs including constitutive relations."""
        ...

    def conservation_residuals(
        self,
        t: float,
        y: NDArray[np.float64],
        inputs: Inputs,
        context: Context,
    ) -> dict[str, float]:
        """Named conservation residuals (0 is exact)."""
        ...
