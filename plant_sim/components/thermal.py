"""Thermal network and heat exchanger (IA-THM-001, IA-HEX-001).

@relation(IA-THM-001, scope=module)
@relation(IA-HEX-001, scope=module)

Nodes: electrode cluster, electrolyte, vessel wall, lid, coolant cavity
(US FIGS. 1E-1F, 9A). Heat exchanger for cavity coolant / lid loops.
"""

from __future__ import annotations

from collections.abc import Mapping

import numpy as np
from numpy.typing import NDArray

from plant_sim.bootstrap import setup_path
from plant_sim.components.base import RHSComponent
from plant_sim.params import PlantParams, default_params

setup_path()

from ironair.ode.state import StateSpec  # noqa: E402
from ironair.properties import thermal_conductivity_w_m_k  # noqa: E402

SPECS = (
    StateSpec("T_electrode_K", "K", "lumped electrode temperature"),
    StateSpec("T_electrolyte_K", "K", "bulk electrolyte temperature"),
    StateSpec("T_vessel_K", "K", "vessel wall temperature"),
    StateSpec("T_lid_K", "K", "lid temperature"),
    StateSpec("T_coolant_K", "K", "cavity coolant temperature"),
)

HEX_SPECS = (
    StateSpec("T_hot_K", "K", "hot-side fluid temperature"),
    StateSpec("T_cold_K", "K", "cold-side fluid temperature"),
)


def default_y0(p: PlantParams | None = None) -> NDArray[np.float64]:
    p = p or default_params()
    T = p.T_ep_sim_K
    return np.array([T, T, T, T, T - 1.0], dtype=np.float64)


def thermal_rhs(
    t: float,
    y: NDArray[np.float64],
    u: Mapping[str, float],
    p: PlantParams,
) -> NDArray[np.float64]:
    """Five-node vessel thermal network RHS.

    @relation(IA-THM-001, scope=function)
    """
    Te, Tel, Tv, Tl, Tc = y
    q_rxn = float(u.get("q_reaction_W", 0.0))
    q_joule = float(u.get("q_joule_W", 0.0))
    T_amb = float(u.get("T_amb_K", p.T_ref_K))
    mdot_cool = float(u.get("mdot_coolant_kg_s", 0.05))
    k_ely = thermal_conductivity_w_m_k(min(max(Tel, 274.0), 372.0), "electrolyte")
    k_steel = thermal_conductivity_w_m_k(min(max(Tv, 274.0), 372.0), "steel")
    UA_e = 40.0 * p.A_geom_m2
    UA_v = 8.0 * p.A_thermal_m2 * (k_steel / 16.0)
    UA_l = 6.0 * p.A_thermal_m2
    UA_c = 25.0 * p.A_thermal_m2
    C_e = max(p.m_fe_kg, 0.1) * p.Cp_fe_J_kg_K
    C_el = 15.0 * 3800.0
    C_v = p.m_vessel_kg * p.Cp_steel_J_kg_K
    C_l = 8.0 * p.Cp_steel_J_kg_K
    C_c = 12.0 * 4180.0
    dTe = (q_rxn + q_joule + UA_e * (Tel - Te)) / C_e
    dTel = (UA_e * (Te - Tel) + (k_ely * p.A_geom_m2 / 0.03) * (Tv - Tel)) / C_el
    dTv = (UA_v * (T_amb - Tv) + UA_c * (Tc - Tv) + 12.0 * (Tel - Tv)) / C_v
    dTl = (UA_l * (T_amb - Tl) + 10.0 * (Tv - Tl)) / C_l
    dTc = (mdot_cool * 4180.0 * (T_amb - Tc) + UA_c * (Tv - Tc)) / C_c
    _ = t
    return np.array([dTe, dTel, dTv, dTl, dTc], dtype=np.float64)


def thermal_outputs(
    t: float,
    y: NDArray[np.float64],
    u: Mapping[str, float],
    p: PlantParams,
) -> dict[str, float]:
    Te, Tel, Tv, Tl, Tc = y
    T_amb = float(u.get("T_amb_K", p.T_ref_K))
    return {
        "T_electrode_K": float(Te),
        "T_electrolyte_K": float(Tel),
        "T_vessel_K": float(Tv),
        "T_lid_K": float(Tl),
        "T_coolant_K": float(Tc),
        "T_max_K": float(max(Te, Tel, Tv, Tl, Tc)),
        "dT_vessel_amb_K": float(Tv - T_amb),
        "t_s": t,
    }


class ThermalNetwork(RHSComponent):
    """IA-THM-001 thermal network.

    @relation(IA-THM-001, scope=class)
    """

    def __init__(self, p: PlantParams | None = None, y0: NDArray[np.float64] | None = None) -> None:
        p = p or default_params()
        y0 = default_y0(p) if y0 is None else y0

        def rhs(t, y, inputs, context):  # type: ignore[no-untyped-def]
            return thermal_rhs(t, y, inputs, p)

        def out(t, y, inputs, context):  # type: ignore[no-untyped-def]
            return thermal_outputs(t, y, inputs, p)

        super().__init__(
            name="thermal",
            requirement_ids=("IA-THM-001", "IA-SYS-011"),
            specs=SPECS,
            y0=y0,
            rhs_fn=rhs,
            out_fn=out,
            input_names=("q_reaction_W", "q_joule_W", "T_amb_K", "mdot_coolant_kg_s"),
            output_names=("T_electrode_K", "T_vessel_K", "T_max_K"),
            params=p,
        )


def hex_rhs(
    t: float,
    y: NDArray[np.float64],
    u: Mapping[str, float],
    p: PlantParams,
) -> NDArray[np.float64]:
    """Two-stream heat-exchanger RHS.

    @relation(IA-HEX-001, scope=function)
    """
    Th, Tc = y
    m_h = float(u.get("mdot_hot_kg_s", 0.04))
    m_c = float(u.get("mdot_cold_kg_s", 0.05))
    T_h_in = float(u.get("T_hot_in_K", p.T_ep_sim_K + 8.0))
    T_c_in = float(u.get("T_cold_in_K", p.T_ref_K))
    UA = 40.0
    q = UA * (Th - Tc)
    Ch = max(m_h, 1e-4) * 4180.0
    Cc = max(m_c, 1e-4) * 4180.0
    dTh = (m_h * 4180.0 * (T_h_in - Th) - q) / (Ch * 8.0)
    dTc = (m_c * 4180.0 * (T_c_in - Tc) + q) / (Cc * 8.0)
    _ = (t, p)
    return np.array([dTh, dTc], dtype=np.float64)


class HeatExchanger(RHSComponent):
    """IA-HEX-001 heat exchanger.

    @relation(IA-HEX-001, scope=class)
    """

    def __init__(self, p: PlantParams | None = None) -> None:
        p = p or default_params()
        y0 = np.array([p.T_ep_sim_K + 5.0, p.T_ref_K + 1.0], dtype=np.float64)

        def rhs(t, y, inputs, context):  # type: ignore[no-untyped-def]
            return hex_rhs(t, y, inputs, p)

        def out(t, y, inputs, context):  # type: ignore[no-untyped-def]
            return {"T_hot_K": float(y[0]), "T_cold_K": float(y[1]), "q_W": 40.0 * (y[0] - y[1]), "t_s": t}

        super().__init__(
            name="heat_exchanger",
            requirement_ids=("IA-HEX-001",),
            specs=HEX_SPECS,
            y0=y0,
            rhs_fn=rhs,
            out_fn=out,
            input_names=("mdot_hot_kg_s", "mdot_cold_kg_s", "T_hot_in_K", "T_cold_in_K"),
            output_names=("T_hot_K", "T_cold_K", "q_W"),
            params=p,
        )
