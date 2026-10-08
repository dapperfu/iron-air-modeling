"""Concatenate lower-level component RHS functions into a substructure ODE."""

from __future__ import annotations

from collections.abc import Callable, Mapping, Sequence
from typing import Any

import numpy as np
from numpy.typing import NDArray
from scipy.integrate import solve_ivp

from plant_sim.params import PlantParams, default_params

Rhs = Callable[[float, NDArray[np.float64], Mapping[str, float], PlantParams], NDArray[np.float64]]


class CoupledSubstructure:
    """Join N component RHS callables sharing the same coupling dict builder."""

    def __init__(
        self,
        name: str,
        pieces: Sequence[tuple[str, int, Rhs, NDArray[np.float64]]],
        couple: Callable[[float, NDArray[np.float64], Mapping[str, float], PlantParams, dict[str, NDArray[np.float64]]], dict[str, Mapping[str, float]]],
        params: PlantParams | None = None,
    ) -> None:
        self.name = name
        self.params = params or default_params()
        self.pieces = list(pieces)
        self.couple = couple
        self.offsets: list[tuple[str, int, int, Rhs]] = []
        i = 0
        y0s = []
        for key, n, rhs, y0 in pieces:
            self.offsets.append((key, i, i + n, rhs))
            y0s.append(np.asarray(y0, dtype=float))
            i += n
        self._y0 = np.concatenate(y0s)
        self.n_states = i

    def y0(self) -> NDArray[np.float64]:
        return self._y0.copy()

    def split(self, y: NDArray[np.float64]) -> dict[str, NDArray[np.float64]]:
        return {key: y[a:b] for key, a, b, _ in self.offsets}

    def rhs(self, t: float, y: NDArray[np.float64], u: Mapping[str, float] | None = None) -> NDArray[np.float64]:
        u = u or {}
        parts = self.split(y)
        u_map = self.couple(t, y, u, self.params, parts)
        dy = np.zeros_like(y)
        for key, a, b, fn in self.offsets:
            dy[a:b] = fn(t, parts[key], u_map[key], self.params)
        return dy

    def simulate(self, t_span: tuple[float, float], u: Mapping[str, float] | Callable[[float], Mapping[str, float]] | None = None, n_eval: int = 250, method: str = "BDF") -> dict[str, Any]:
        def u_at(t: float) -> Mapping[str, float]:
            if u is None:
                return {}
            if callable(u):
                return u(t)
            return u

        def fun(t: float, y: NDArray[np.float64]) -> NDArray[np.float64]:
            return self.rhs(t, y, u_at(t))

        t_eval = np.linspace(t_span[0], t_span[1], n_eval)
        sol = solve_ivp(fun, t_span, self.y0(), method=method, t_eval=t_eval, rtol=1e-6, atol=1e-8)
        if not sol.success:
            raise RuntimeError(sol.message)
        y = np.asarray(sol.y, dtype=float)
        if not np.all(np.isfinite(y)):
            raise RuntimeError(f"{self.name} produced NaNs")
        return {"t": np.asarray(sol.t), "y": y, "parts": [self.split(y[:, i]) for i in range(y.shape[1])]}
