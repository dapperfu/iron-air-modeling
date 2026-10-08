"""20 Cell stack: series cells + stacked submerged ORR equal-ΔP geometry (US Claim 1)."""

from __future__ import annotations

from collections.abc import Mapping

import numpy as np
from numpy.typing import NDArray

from plant_sim.components.orr import stacked_orr_flows
from plant_sim.params import PlantParams, default_params
from plant_sim.plant import PlantModel
from plant_sim.substructures.dual_electrode_cell import DualElectrodeCell


class CellStack:
    def __init__(self, p: PlantParams | None = None, n_cells: int = 6) -> None:
        self.params = p or default_params()
        self.n_cells = n_cells
        self.cell = DualElectrodeCell(self.params)
        self.plant = PlantModel(self.params)

    def equal_pressure_drop(self, Q_total: float = 5e-4, compensate: bool = True) -> dict[str, NDArray[np.float64]]:
        return stacked_orr_flows(self.params, Q_total, compensate, self.params.T_ep_sim_K)

    def rhs(self, t: float, y: NDArray[np.float64], u: Mapping[str, float] | None = None) -> NDArray[np.float64]:
        """n_cells copies of the dual-electrode cell with shared current (series)."""
        n = self.cell.n_states
        dy = np.zeros_like(y)
        u = u or {}
        for i in range(self.n_cells):
            sl = y[i * n : (i + 1) * n]
            dy[i * n : (i + 1) * n] = self.cell.rhs(t, sl, u)
        return dy

    def y0(self) -> NDArray[np.float64]:
        return np.tile(self.cell.y0(), self.n_cells)

    def simulate(self, t_span: tuple[float, float], u: Mapping[str, float] | None = None, n_eval: int = 200) -> dict:
        from scipy.integrate import solve_ivp

        def fun(t: float, y: NDArray[np.float64]) -> NDArray[np.float64]:
            return self.rhs(t, y, u or {"mode": -1.0, "I_cell_A": self.params.I_discharge_100h_A})

        t_eval = np.linspace(t_span[0], t_span[1], n_eval)
        sol = solve_ivp(fun, t_span, self.y0(), method="BDF", t_eval=t_eval, rtol=1e-5, atol=1e-8)
        if not sol.success:
            raise RuntimeError(sol.message)
        y = np.asarray(sol.y, dtype=float)
        if not np.all(np.isfinite(y)):
            raise RuntimeError("stack NaNs")
        return {"t": np.asarray(sol.t), "y": y, "n_cells": self.n_cells}
