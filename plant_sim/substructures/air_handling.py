"""32 Air handling: fan + manifold + stacked-ORR distribution."""

from __future__ import annotations

from collections.abc import Mapping

import numpy as np
from numpy.typing import NDArray

from plant_sim.components import air_system as air_mod
from plant_sim.components.orr import stacked_orr_flows
from plant_sim.params import PlantParams, default_params
from plant_sim.substructures.compose import CoupledSubstructure


def _fan_rhs(t, y, u, p):  # type: ignore[no-untyped-def]
    return air_mod.fan_rhs(t, y, u, p)


def _couple(t: float, y: NDArray[np.float64], u: Mapping[str, float], p: PlantParams, parts: dict[str, NDArray[np.float64]]) -> dict[str, Mapping[str, float]]:
    mdot = 1.2e-5 * float(parts["fan"][0])
    r_orr = float(u.get("r_orr_mol_s", 1e-6))
    return {
        "air": {"mdot_air_kg_s": mdot, "r_orr_mol_s": r_orr, "r_oer_mol_s": float(u.get("r_oer_mol_s", 0.0)), "T_K": p.T_ep_sim_K},
        "fan": {"I_fan_A": float(u.get("I_fan_A", 1.0))},
    }


class AirHandling(CoupledSubstructure):
    def __init__(self, p: PlantParams | None = None) -> None:
        p = p or default_params()
        super().__init__(
            name="air_handling",
            pieces=[
                ("air", 5, air_mod.air_rhs, air_mod.air_y0(p)),
                ("fan", 1, _fan_rhs, np.array([40.0])),
            ],
            couple=_couple,
            params=p,
        )

    def stacked_distribution(self, compensate: bool = True):
        return stacked_orr_flows(self.params, 4e-4, compensate, self.params.T_ep_sim_K)
