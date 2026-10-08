"""31 Electrolyte circulation BOP: pump + valve + pipe + reservoir + loop."""

from __future__ import annotations

from collections.abc import Mapping

import numpy as np
from numpy.typing import NDArray

from plant_sim.components import hydraulics as hyd_mod
from plant_sim.params import PlantParams, default_params
from plant_sim.substructures.compose import CoupledSubstructure


def _pump_rhs(t, y, u, p):  # type: ignore[no-untyped-def]
    return hyd_mod.Pump(p)._rhs(t, y, u, {})


def _res_rhs(t, y, u, p):  # type: ignore[no-untyped-def]
    return hyd_mod.Reservoir(p)._rhs(t, y, u, {})


def _valve_rhs(t, y, u, p):  # type: ignore[no-untyped-def]
    return hyd_mod.Valve(p)._rhs(t, y, u, {})


def _pipe_rhs(t, y, u, p):  # type: ignore[no-untyped-def]
    return hyd_mod.Pipe(p)._rhs(t, y, u, {})


def _couple(t: float, y: NDArray[np.float64], u: Mapping[str, float], p: PlantParams, parts: dict[str, NDArray[np.float64]]) -> dict[str, Mapping[str, float]]:
    mdot = float(parts["flow"][0])
    return {
        "flow": {"omega_pump_rad_s": float(parts["pump"][0]), "valve_pos": float(parts["valve"][0]), "T_ely_K": p.T_ep_sim_K},
        "pump": {"I_pump_A": float(u.get("I_pump_A", 2.0))},
        "res": {"mdot_in_kg_s": mdot, "mdot_out_kg_s": 0.98 * mdot, "T_in_K": float(parts["flow"][2])},
        "valve": {"valve_cmd": float(u.get("valve_cmd", 0.8)), "dP_Pa": float(parts["flow"][1]) - p.P_atm_Pa},
        "pipe": {"c_in_mol_m3": p.c_KOH_mol_m3, "T_in_K": float(parts["res"][2]), "tau_s": 6.0},
    }


class HydraulicsBOP(CoupledSubstructure):
    def __init__(self, p: PlantParams | None = None) -> None:
        p = p or default_params()
        super().__init__(
            name="hydraulics_bop",
            pieces=[
                ("flow", 3, hyd_mod.flow_rhs, np.array([0.04, p.P_atm_Pa + 1.5e4, p.T_ep_sim_K])),
                ("pump", 1, _pump_rhs, np.array([50.0])),
                ("res", 3, _res_rhs, hyd_mod.Reservoir(p).y0()),
                ("valve", 1, _valve_rhs, np.array([0.2])),
                ("pipe", 2, _pipe_rhs, np.array([p.c_KOH_mol_m3, p.T_ep_sim_K])),
            ],
            couple=_couple,
            params=p,
        )
