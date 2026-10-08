"""Assemble component ODEs into one SciPy initial-value problem.

@relation(IA-ODE-003, scope=module)
@relation(IA-ODE-004, scope=module)
@relation(IA-SYS-005, scope=module)
"""

from __future__ import annotations

from collections.abc import Callable, Sequence
from dataclasses import dataclass
from importlib.metadata import PackageNotFoundError, version
from typing import Any

import numpy as np
from numpy.typing import NDArray
from scipy.integrate import solve_ivp

from ironair.exceptions import SolverFailure
from ironair.ode.protocol import DynamicComponentProtocol, Inputs
from ironair.simulation.diagnostics import SolverDiagnostics

InputFn = Callable[[float], Inputs]
DEFAULT_METHOD: str = "BDF"
STIFF_METHODS: frozenset[str] = frozenset({"BDF", "Radau", "LSODA"})


def _package_version() -> str:
    try:
        return version("ironair")
    except PackageNotFoundError:
        return "0.0.0+unknown"


@dataclass(slots=True)
class SimulationResult:
    """Trajectories, names, and solver diagnostics.

    @relation(IA-ODE-003, scope=class)
    @relation(IA-TST-011, scope=class)
    """

    t: NDArray[np.float64]
    y: NDArray[np.float64]
    state_names: tuple[str, ...]
    state_units: tuple[str, ...]
    diagnostics: SolverDiagnostics
    metadata: dict[str, Any]

    def to_dataframe(self):  # type: ignore[no-untyped-def]
        """Convert trajectories to a pandas DataFrame.

        @relation(IA-NBK-003, scope=function)
        """
        import pandas as pd

        data = {"t_s": self.t}
        for i, name in enumerate(self.state_names):
            data[name] = self.y[i]
        return pd.DataFrame(data)


class CoupledSystem:
    """Global ODE assembled from DynamicComponentProtocol objects.

    @relation(IA-ODE-003, scope=class)
    @relation(IA-SYS-002, scope=class)
    """

    def __init__(
        self,
        components: Sequence[DynamicComponentProtocol],
        *,
        default_method: str = DEFAULT_METHOD,
    ) -> None:
        if not components:
            raise ValueError("CoupledSystem requires at least one component")
        self.components = tuple(components)
        self.default_method = default_method
        self._index: list[tuple[int, int]] = []
        names: list[str] = []
        units: list[str] = []
        atol: list[float] = []
        offset = 0
        for component in self.components:
            n = len(component.state_specs())
            self._index.append((offset, offset + n))
            for spec in component.state_specs():
                names.append(f"{component.name}.{spec.name}")
                units.append(spec.unit)
                atol.append(spec.abs_tol)
            offset += n
        self.state_names = tuple(names)
        self.state_units = tuple(units)
        self.atol_vector = np.array(atol, dtype=np.float64)
        self.n_states = offset

    def state_index_map(self) -> dict[str, tuple[int, int]]:
        """Map component name to [start, end) indices.

        @relation(IA-ODE-003, scope=function)
        """
        return {c.name: idx for c, idx in zip(self.components, self._index, strict=True)}

    def y0(self) -> NDArray[np.float64]:
        """Concatenate component initial conditions.

        @relation(IA-ODE-002, scope=function)
        """
        return np.concatenate([c.y0() for c in self.components])

    def split(self, y: NDArray[np.float64]) -> list[NDArray[np.float64]]:
        return [y[a:b] for a, b in self._index]

    def rhs(
        self,
        t: float,
        y: NDArray[np.float64],
        inputs: Inputs | None = None,
        context: dict[str, Any] | None = None,
    ) -> NDArray[np.float64]:
        """Evaluate concatenated derivatives.

        @relation(IA-ODE-001, scope=function)
        @relation(IA-ODE-003, scope=function)
        """
        inp: Inputs = inputs or {}
        ctx: dict[str, Any] = context if context is not None else {}
        pieces = []
        for component, local in zip(self.components, self.split(y), strict=True):
            pieces.append(component.rhs(t, local, inp, ctx))
        return np.concatenate(pieces)

    def simulate(
        self,
        t_span: tuple[float, float],
        *,
        t_eval: NDArray[np.float64] | None = None,
        inputs: InputFn | Inputs | None = None,
        method: str | None = None,
        rtol: float = 1e-6,
        atol: float | NDArray[np.float64] | None = None,
        events: Sequence[Callable[..., float]] | None = None,
        dense_output: bool = False,
        seed: int | None = None,
        context: dict[str, Any] | None = None,
    ) -> SimulationResult:
        """Integrate with SciPy. Default method is stiff BDF.

        @relation(IA-ODE-003, scope=function)
        @relation(IA-ODE-004, scope=function)
        @relation(IA-ODE-005, scope=function)
        @relation(IA-ODE-006, scope=function)
        @relation(IA-TST-011, scope=function)
        """
        solver = method or self.default_method
        abs_tol = self.atol_vector if atol is None else atol
        ctx = context if context is not None else {}
        if seed is not None:
            rng = np.random.default_rng(seed)
            ctx = {**ctx, "rng": rng, "seed": seed}

        def input_at(t: float) -> Inputs:
            if inputs is None:
                return {}
            if callable(inputs):
                return inputs(t)
            return inputs

        def fun(t: float, y: NDArray[np.float64]) -> NDArray[np.float64]:
            return self.rhs(t, y, input_at(t), ctx)

        solution = solve_ivp(
            fun,
            t_span,
            self.y0(),
            method=solver,
            t_eval=t_eval,
            rtol=rtol,
            atol=abs_tol,
            events=events,
            dense_output=dense_output,
            vectorized=False,
        )
        if not solution.success:
            raise SolverFailure(solution.message)
        residuals: dict[str, float] = {}
        y_end = solution.y[:, -1]
        t_end = float(solution.t[-1])
        inp_end = input_at(t_end)
        for component, local in zip(self.components, self.split(y_end), strict=True):
            for key, value in component.conservation_residuals(t_end, local, inp_end, ctx).items():
                residuals[f"{component.name}.{key}"] = value
        diagnostics = SolverDiagnostics(
            method=solver,
            success=bool(solution.success),
            message=str(solution.message),
            nfev=int(solution.nfev),
            njev=int(getattr(solution, "njev", 0) or 0),
            nlu=int(getattr(solution, "nlu", 0) or 0),
            status=int(solution.status),
            conservation_residuals=residuals,
        )
        metadata = {
            "ironair_version": _package_version(),
            "seed": seed,
            "rtol": rtol,
            "method": solver,
            "t_span": t_span,
        }
        return SimulationResult(
            t=np.asarray(solution.t, dtype=np.float64),
            y=np.asarray(solution.y, dtype=np.float64),
            state_names=self.state_names,
            state_units=self.state_units,
            diagnostics=diagnostics,
            metadata=metadata,
        )
