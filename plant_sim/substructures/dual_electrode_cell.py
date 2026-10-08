"""12 Dual-electrode cell (US12308414B2): independent ORR/OER with iron anode.

@relation(IA-CEL-001, scope=module)
"""

from __future__ import annotations

from collections.abc import Mapping

import numpy as np
from numpy.typing import NDArray

from plant_sim.components import electrolyte as ely_mod
from plant_sim.components import gdl as gdl_mod
from plant_sim.components import her as her_mod
from plant_sim.components import iron_anode as fe_mod
from plant_sim.components import oer as oer_mod
from plant_sim.components import orr as orr_mod
from plant_sim.components import separator as sep_mod
from plant_sim.params import PlantParams, default_params
from plant_sim.substructures.compose import CoupledSubstructure, Rhs


def _oer_rhs(t: float, y: NDArray[np.float64], u: Mapping[str, float], p: PlantParams) -> NDArray[np.float64]:
    return oer_mod.oer_rhs(t, y, u, p, layout="interdigitated")


def _couple(
    t: float, y: NDArray[np.float64], u: Mapping[str, float], p: PlantParams, parts: dict[str, NDArray[np.float64]]
) -> dict[str, Mapping[str, float]]:
    """Charge closes iron-OER-source; discharge closes iron-ORR-load.

    @relation(IA-CEL-001, scope=function)
    """
    mode = float(u.get("mode", -1.0))
    I = float(u.get("I_cell_A", p.I_discharge_100h_A))
    T = float(parts["fe"][3])
    V = max(float(parts["ely"][5]), 1e-8)
    a_oh = max(float(parts["ely"][0]) / V / 1000.0, 1e-6)
    if mode >= 0.0:
        I_fe, I_orr, I_oer, iso = -abs(I), 0.0, abs(I), 0.0
    else:
        I_fe, I_orr, I_oer, iso = abs(I), -abs(I), 0.0, 1.0
    r_orr = abs(I_orr) / (4.0 * 96485.3321233100184)
    r_oer = abs(I_oer) / (4.0 * 96485.3321233100184)
    r_fe = I_fe / (2.0 * 96485.3321233100184)
    c_tpb = float(parts["gdl"][p.n_gdl_nodes - 1])
    return {
        "fe": {"I_fe_A": I_fe, "T_amb_K": T, "a_oh": a_oh, "a_h2o": 0.72},
        "her": {
            "I_fe_A": I_fe,
            "T_K": T,
            "L_path_m": p.L_anode_m * (1.0 - 0.6 * p.chan_frac),
            "a_oh": a_oh,
            "a_h2o": 0.72,
        },
        "orr": {
            "I_orr_A": I_orr,
            "T_K": T,
            "c_O2_gdl_mol_m3": c_tpb,
            "p_O2_Pa": p.x_O2_air * p.P_atm_Pa,
            "a_oh": a_oh,
            "a_h2o": 0.72,
        },
        "oer": {"I_oer_A": I_oer, "T_K": T, "a_oh": a_oh, "a_h2o": 0.72, "p_O2_Pa": p.P_atm_Pa, "oer_isolated": iso},
        "gdl": {
            "T_K": T,
            "P_Pa": p.P_atm_Pa,
            "x_O2": p.x_O2_air,
            "r_orr_mol_s": r_orr,
            "hydraulic_head_m": 0.1,
            "oer_dryout": 0.2 if I_oer > 0 else 0.0,
        },
        "ely": {
            "r_iron_mol_s": r_fe,
            "r_orr_mol_s": r_orr,
            "r_oer_mol_s": r_oer,
            "T_amb_K": T,
            "q_heat_W": abs(I) * 0.08,
        },
        "sep": {
            "T_ely_K": float(parts["ely"][4]),
            "c_KOH_mol_m3": float(parts["ely"][0]) / V,
            "I_cell_A": I_fe,
            "s_wet": float(parts["ely"][6]),
            "c_O2_ely_mol_m3": 0.01 * c_tpb,
        },
    }


class DualElectrodeCell(CoupledSubstructure):
    """IA-CEL-001 dual-electrode iron-air cell.

    @relation(IA-CEL-001, scope=class)
    """

    def __init__(self, p: PlantParams | None = None) -> None:
        p = p or default_params()
        oer_fn: Rhs = _oer_rhs
        super().__init__(
            name="dual_electrode_cell",
            pieces=[
                ("fe", 8, fe_mod.iron_anode_rhs, fe_mod.default_y0(p)),
                ("her", 3, her_mod.her_rhs, her_mod.default_y0(p)),
                ("orr", 3, orr_mod.orr_rhs, orr_mod.default_y0(p)),
                ("oer", 3, oer_fn, oer_mod.default_y0(p)),
                ("gdl", p.n_gdl_nodes + 2, gdl_mod.gdl_rhs, gdl_mod.default_y0(p)),
                ("ely", 7, ely_mod.electrolyte_rhs, ely_mod.default_y0(p)),
                ("sep", 4, sep_mod.separator_rhs, sep_mod.default_y0(p)),
            ],
            couple=_couple,
            params=p,
        )
