"""33 Electrical balance: tabs/stacking, DC bus, inverter, transformer, grid."""

from __future__ import annotations

from collections.abc import Mapping

import numpy as np
from numpy.typing import NDArray

from plant_sim.components import electrical as el_mod
from plant_sim.params import PlantParams, default_params
from plant_sim.substructures.compose import CoupledSubstructure


def _dc(t, y, u, p):  # type: ignore[no-untyped-def]
    return el_mod.DCBus(p)._rhs(t, y, u, {})


def _cnv(t, y, u, p):  # type: ignore[no-untyped-def]
    return el_mod.DCDCConverter(p)._rhs(t, y, u, {})


def _inv(t, y, u, p):  # type: ignore[no-untyped-def]
    return el_mod.GridInverter(p)._rhs(t, y, u, {})


def _trf(t, y, u, p):  # type: ignore[no-untyped-def]
    return el_mod.Transformer(p)._rhs(t, y, u, {})


def _grd(t, y, u, p):  # type: ignore[no-untyped-def]
    return el_mod.GridInterface(p)._rhs(t, y, u, {})


def _couple(t: float, y: NDArray[np.float64], u: Mapping[str, float], p: PlantParams, parts: dict[str, NDArray[np.float64]]) -> dict[str, Mapping[str, float]]:
    P = float(u.get("P_grid_W", 500.0))
    Vdc = float(parts["dc"][0])
    return {
        "dc": {"P_net_W": P - Vdc * float(u.get("I_stack_A", 5.0))},
        "cnv": {"v_in_V": Vdc, "duty": 0.55, "R_load_ohm": 8.0},
        "inv": {"P_ref_W": P, "Q_ref_var": float(u.get("Q_ref_var", 0.0))},
        "trf": {"v_grid_V": p.grid_V_rms, "f_Hz": p.grid_f_Hz, "I_rms_A": abs(P) / max(p.grid_V_rms, 1.0)},
        "grid": {"P_grid_W": P, "v_grid_V": p.grid_V_rms, "f_Hz": p.grid_f_Hz},
    }


class ElectricalBalance(CoupledSubstructure):
    def __init__(self, p: PlantParams | None = None) -> None:
        p = p or default_params()
        super().__init__(
            name="electrical_balance",
            pieces=[
                ("dc", 1, _dc, np.array([float(p.n_cells_series) * 1.2])),
                ("cnv", 2, _cnv, np.array([1.0, 48.0])),
                ("inv", 2, _inv, np.array([0.0, 0.0])),
                ("trf", 2, _trf, np.array([0.5, p.T_ref_K])),
                ("grid", 1, _grd, np.array([0.0])),
            ],
            couple=_couple,
            params=p,
        )
