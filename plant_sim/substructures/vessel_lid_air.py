"""22 Vessel, multi-function lid, air delivery, inverse-air, DRI pellet bed.

@relation(IA-ENC-001, scope=module)
"""

from __future__ import annotations

from collections.abc import Mapping

import numpy as np
from numpy.typing import NDArray

from plant_sim.components import air_system as air_mod
from plant_sim.components import iron_anode as fe_mod
from plant_sim.components import thermal as th_mod
from plant_sim.params import PlantParams, default_params
from plant_sim.substructures.compose import CoupledSubstructure


def _couple(t: float, y: NDArray[np.float64], u: Mapping[str, float], p: PlantParams, parts: dict[str, NDArray[np.float64]]) -> dict[str, Mapping[str, float]]:
    """Couple iron, lid air, fan, and vessel thermal nodes.

    @relation(IA-ENC-001, scope=function)
    """
    I = float(u.get("I_fe_A", 0.0))
    T = float(parts["fe"][3])
    mdot = 1.2e-5 * float(parts["fan"][0])
    return {
        "fe": {"I_fe_A": I, "T_amb_K": float(u.get("T_amb_K", p.T_ref_K)), "a_oh": 6.0, "a_h2o": 0.72},
        "air": {"mdot_air_kg_s": mdot, "r_orr_mol_s": abs(min(I, 0.0)) / (4 * 96485.33), "r_oer_mol_s": max(I, 0.0) / (4 * 96485.33), "T_K": T},
        "fan": {"I_fan_A": float(u.get("I_fan_A", 0.6))},
        "th": {"q_reaction_W": abs(I) * 0.1, "q_joule_W": I**2 * 0.002, "T_amb_K": float(u.get("T_amb_K", p.T_ref_K)), "mdot_coolant_kg_s": 0.04},
    }


class VesselLidAir(CoupledSubstructure):
    """IA-ENC-001 vessel, lid, and secondary-containment air path.

    @relation(IA-ENC-001, scope=class)
    """

    def __init__(self, p: PlantParams | None = None, dri: bool = True) -> None:
        p = p or default_params()
        self.dri = dri
        y_fe = fe_mod.default_y0(p)
        if dri:
            y_fe[5] = 0.38  # packed DRI bed porosity (US Claim 18 / FIG. 3)

        def fan_rhs(t, y, u, params):  # type: ignore[no-untyped-def]
            return air_mod.fan_rhs(t, y, u, params)

        super().__init__(
            name="vessel_lid_air",
            pieces=[
                ("fe", 8, fe_mod.iron_anode_rhs, y_fe),
                ("air", 5, air_mod.air_rhs, air_mod.air_y0(p)),
                ("fan", 1, fan_rhs, np.array([25.0])),
                ("th", 5, th_mod.thermal_rhs, th_mod.default_y0(p)),
            ],
            couple=_couple,
            params=p,
        )
