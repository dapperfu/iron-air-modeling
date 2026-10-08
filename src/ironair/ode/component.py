"""Concrete dynamic-component helper implementing the protocol.

@relation(IA-ODE-001, scope=module)
@relation(IA-SDD-002, scope=module)
"""

from __future__ import annotations

from collections.abc import Mapping, Sequence
from dataclasses import dataclass, field
from typing import Any

import numpy as np
from numpy.typing import NDArray

from ironair.exceptions import InvalidPhysicalState
from ironair.ode.state import StateSpec, validate_state_vector
from ironair.parameters import ParameterSet


@dataclass(slots=True)
class DynamicComponent:
    """Reusable ODE component with validated state metadata.

    Subclasses assign specs, parameters, and implement _rhs/_outputs.

    @relation(IA-ODE-001, scope=class)
    @relation(IA-SYS-003, scope=class)
    """

    name: str
    requirement_ids: tuple[str, ...]
    _specs: tuple[StateSpec, ...]
    _parameters: ParameterSet
    _y0: NDArray[np.float64]
    _input_names: tuple[str, ...] = ()
    _output_names: tuple[str, ...] = ()
    reduced_order: bool = False
    _extra: dict[str, Any] = field(default_factory=dict)

    def __post_init__(self) -> None:
        self._y0 = validate_state_vector(np.array(self._y0, dtype=np.float64, copy=True), self._specs)
        names = [spec.name for spec in self._specs]
        if len(names) != len(set(names)):
            raise InvalidPhysicalState(f"{self.name}: duplicate state names")

    def state_specs(self) -> tuple[StateSpec, ...]:
        """Return state metadata.

        @relation(IA-ODE-002, scope=function)
        """
        return self._specs

    def y0(self) -> NDArray[np.float64]:
        """Return a copy of the initial state.

        @relation(IA-ODE-002, scope=function)
        """
        return np.array(self._y0, dtype=np.float64, copy=True)

    def parameters(self) -> ParameterSet:
        """Return the parameter set.

        @relation(IA-CON-002, scope=function)
        """
        return self._parameters

    def input_names(self) -> Sequence[str]:
        return self._input_names

    def output_names(self) -> Sequence[str]:
        return self._output_names

    def rhs(
        self,
        t: float,
        y: NDArray[np.float64],
        inputs: Mapping[str, float],
        context: Mapping[str, Any],
    ) -> NDArray[np.float64]:
        """Validate y and delegate to _rhs without mutating parameters.

        @relation(IA-ODE-001, scope=function)
        """
        state = validate_state_vector(y, self._specs)
        derivative = np.asarray(self._rhs(t, state, inputs, context), dtype=np.float64)
        if derivative.shape != state.shape:
            raise InvalidPhysicalState(f"{self.name}: rhs shape {derivative.shape} != {state.shape}")
        return derivative

    def outputs(
        self,
        t: float,
        y: NDArray[np.float64],
        inputs: Mapping[str, float],
        context: Mapping[str, Any],
    ) -> dict[str, float]:
        """Algebraic outputs.

        @relation(IA-SYS-003, scope=function)
        """
        state = validate_state_vector(y, self._specs)
        return dict(self._outputs(t, state, inputs, context))

    def conservation_residuals(
        self,
        t: float,
        y: NDArray[np.float64],
        inputs: Mapping[str, float],
        context: Mapping[str, Any],
    ) -> dict[str, float]:
        """Default: no extra residuals.

        @relation(IA-SYS-003, scope=function)
        """
        validate_state_vector(y, self._specs)
        return {}

    def _rhs(
        self,
        t: float,
        y: NDArray[np.float64],
        inputs: Mapping[str, float],
        context: Mapping[str, Any],
    ) -> NDArray[np.float64]:
        raise NotImplementedError

    def _outputs(
        self,
        t: float,
        y: NDArray[np.float64],
        inputs: Mapping[str, float],
        context: Mapping[str, Any],
    ) -> dict[str, float]:
        return {}
