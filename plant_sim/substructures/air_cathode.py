"""11 Air cathode: ORR + OER + GDL + air inventory."""

from __future__ import annotations

from collections.abc import Mapping

import numpy as np
from numpy.typing import NDArray

from plant_sim.components import air_system as air_mod
from plant_sim.components import gdl as gdl_mod
from plant_sim.components import oer as oer_mod
from plant_sim.components import orr as orr_mod
from plant_sim.params import PlantParams, default_params
from plant_sim.substructures.compose import CoupledSubstructure, Rhs


def _oer_rhs(t: float, y: NDArray[np.float64], u: Mapping[str, float], p: PlantParams) -> NDArray[np.float64]:
    return oer_mod.oer_rhs(t, y, u, p, layout="interdigitated")


def _couple(t: float, y: NDArray[np.float64], u: Mapping[str, float], p: PlantParams, parts: dict[str, NDArray[np.float64]]) -> dict[str, Mapping[str, float]]:
    I_dch = float(u.get("I_orr_A", -p.I_discharge_100h_A))
    I_chg = float(u.get("I_oer_A", 0.0))
    T = float(u.get("T_K", p.T_ep_sim_K))
    n_air = max(float(np.sum(parts["air"][1:])), 1e-12)
    x_O2 = float(parts["air"][1]) / n_air
    c_tpb = float(parts["gdl"][p.n_gdl_nodes - 1])
    r_orr = abs(min(I_dch, 0.0)) / (4.0 * 96485.3321233100184)
    r_oer = max(I_chg, 0.0) / (4.0 * 96485.3321233100184)
    return {
        "orr": {"I_orr_A": I_dch, "T_K": T, "c_O2_gdl_mol_m3": c_tpb, "p_O2_Pa": x_O2 * float(parts["air"][0]), "a_oh": 6.0, "a_h2o": 0.72},
        "oer": {"I_oer_A": I_chg, "T_K": T, "a_oh": 6.0, "a_h2o": 0.72, "p_O2_Pa": x_O2 * float(parts["air"][0]), "oer_isolated": float(u.get("oer_isolated", 0.0))},
        "gdl": {"T_K": T, "P_Pa": float(parts["air"][0]), "x_O2": x_O2, "r_orr_mol_s": r_orr, "hydraulic_head_m": float(u.get("hydraulic_head_m", 0.1)), "oer_dryout": 0.2 if I_chg > 0 else 0.0},
        "air": {"mdot_air_kg_s": float(u.get("mdot_air_kg_s", 0.002)), "r_orr_mol_s": r_orr, "r_oer_mol_s": r_oer, "T_K": T},
    }


class AirCathode(CoupledSubstructure):
    def __init__(self, p: PlantParams | None = None) -> None:
        p = p or default_params()
        oer_fn: Rhs = _oer_rhs
        super().__init__(
            name="air_cathode",
            pieces=[
                ("orr", 3, orr_mod.orr_rhs, orr_mod.default_y0(p)),
                ("oer", 3, oer_fn, oer_mod.default_y0(p)),
                ("gdl", p.n_gdl_nodes + 2, gdl_mod.gdl_rhs, gdl_mod.default_y0(p)),
                ("air", 5, air_mod.air_rhs, air_mod.air_y0(p)),
            ],
            couple=_couple,
            params=p,
        )
