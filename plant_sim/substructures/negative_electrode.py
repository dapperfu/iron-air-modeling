"""10 Negative electrode: iron + HER + collector + local electrolyte."""

from __future__ import annotations

from collections.abc import Mapping

import numpy as np
from numpy.typing import NDArray

from plant_sim.components import current_collector as col_mod
from plant_sim.components import electrolyte as ely_mod
from plant_sim.components import her as her_mod
from plant_sim.components import iron_anode as fe_mod
from plant_sim.params import PlantParams, default_params
from plant_sim.substructures.compose import CoupledSubstructure


def _couple(
    t: float, y: NDArray[np.float64], u: Mapping[str, float], p: PlantParams, parts: dict[str, NDArray[np.float64]]
) -> dict[str, Mapping[str, float]]:
    I = float(u.get("I_fe_A", -p.I_discharge_100h_A))
    T = float(parts["fe"][3])
    V = max(float(parts["ely"][5]), 1e-8)
    a_oh = max(float(parts["ely"][0]) / V / 1000.0, 1e-6)
    return {
        "fe": {"I_fe_A": I, "T_amb_K": float(u.get("T_amb_K", p.T_ep_sim_K)), "a_oh": a_oh, "a_h2o": 0.72},
        "her": {
            "I_fe_A": I,
            "T_K": T,
            "L_path_m": p.L_anode_m * (1.0 - 0.6 * p.chan_frac),
            "a_oh": a_oh,
            "a_h2o": 0.72,
        },
        "col": {"I_cell_A": I, "T_amb_K": float(u.get("T_amb_K", p.T_ep_sim_K))},
        "ely": {
            "r_iron_mol_s": I / (2.0 * 96485.3321233100184),
            "r_her_mol_s": 0.0,
            "fill_m3_s": 0.0,
            "T_amb_K": T,
            "q_heat_W": abs(I) * 0.05,
        },
    }


class NegativeElectrode(CoupledSubstructure):
    def __init__(self, p: PlantParams | None = None) -> None:
        p = p or default_params()
        super().__init__(
            name="negative_electrode",
            pieces=[
                ("fe", 8, fe_mod.iron_anode_rhs, fe_mod.default_y0(p)),
                ("her", 3, her_mod.her_rhs, her_mod.default_y0(p)),
                ("col", 2, col_mod.collector_rhs, col_mod.default_y0(p)),
                ("ely", 7, ely_mod.electrolyte_rhs, ely_mod.default_y0(p, filled=True)),
            ],
            couple=_couple,
            params=p,
        )
