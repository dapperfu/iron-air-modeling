"""Oxygen evolution ODE (IA-OER-001).

@relation(IA-OER-001, scope=module)

OER: 4 OH- -> O2 + 2 H2O + 4 e-. Layouts: planar, submerged, interdigitated
trunk-and-projection, corrugated, serpentine, discrete arrays, spiral bifilar,
pleated (EP4602674A1 Claims 1, 3, 12, 32, 38, 70, 77). During charge OER sits
closer to iron than ORR and is electrically isolatable (US FIGS. 5A-5B).
"""

from __future__ import annotations

from collections.abc import Mapping

import numpy as np
from numpy.typing import NDArray

from plant_sim.bootstrap import setup_path
from plant_sim.components.base import RHSComponent, asinh_overpotential_V, i0_T
from plant_sim.params import PlantParams, default_params

setup_path()

from ironair.chemistry.nernst import nernst_oxygen_v  # noqa: E402
from ironair.constants import constants  # noqa: E402
from ironair.ode.state import StateSpec  # noqa: E402

OER_LAYOUTS = (
    "planar",
    "submerged",
    "interdigitated",
    "corrugated",
    "serpentine",
    "discrete_array",
    "spiral_bifilar",
    "pleated",
)

LAYOUT_AREA_FACTOR = {
    "planar": 1.0,
    "submerged": 1.1,
    "interdigitated": 2.4,
    "corrugated": 1.6,
    "serpentine": 1.8,
    "discrete_array": 1.3,
    "spiral_bifilar": 2.1,
    "pleated": 2.8,
}

SPECS = (
    StateSpec("theta_cat", "1", "catalyst active fraction", nonnegative=True),
    StateSpec("n_O2_mol", "mol", "evolved oxygen inventory", nonnegative=True),
    StateSpec("theta_bubble", "1", "OER bubble coverage", nonnegative=True),
)


def default_y0(p: PlantParams | None = None) -> NDArray[np.float64]:
    return np.array([1.0, 1e-8, 0.02], dtype=np.float64)


def oer_rhs(
    t: float,
    y: NDArray[np.float64],
    u: Mapping[str, float],
    p: PlantParams,
    layout: str = "interdigitated",
) -> NDArray[np.float64]:
    """Four-electron OER Faraday and catalyst-state RHS.

    @relation(IA-OER-001, scope=function)
    """
    theta_cat, n_O2, theta_b = y
    I_oer_A = float(u.get("I_oer_A", 0.0))  # anodic positive on charge
    T = float(u.get("T_K", p.T_ep_sim_K))
    isolated = float(u.get("oer_isolated", 0.0))
    factor = LAYOUT_AREA_FACTOR.get(layout, 1.0)
    I_eff = 0.0 if isolated > 0.5 else I_oer_A
    r_oer = max(I_eff, 0.0) / (4.0 * constants.F_C_MOL)
    dn_O2 = r_oer
    # catalyst wear at high anodic overpotential
    i0 = i0_T(p.i0_oer_A_m2, p.Ea_oer_J_mol, T)
    eta = asinh_overpotential_V(I_eff / max(p.A_geom_m2 * factor, 1e-12), i0 * max(theta_cat, 0.05), T)
    dtheta_cat = -1.5e-6 * max(eta, 0.0) * theta_cat
    dtheta_b = 0.6 * r_oer * 800.0 - (0.08 + 0.4 * (layout in {"interdigitated", "spiral_bifilar", "pleated"})) * theta_b
    if theta_b <= 0.0 and dtheta_b < 0.0:
        dtheta_b = 0.0
    _ = t
    return np.array([dtheta_cat, dn_O2, dtheta_b], dtype=np.float64)


def oer_outputs(
    t: float,
    y: NDArray[np.float64],
    u: Mapping[str, float],
    p: PlantParams,
    layout: str = "interdigitated",
) -> dict[str, float]:
    theta_cat, n_O2, theta_b = y
    I_oer_A = float(u.get("I_oer_A", 0.0))
    T = float(u.get("T_K", p.T_ep_sim_K))
    a_oh = float(u.get("a_oh", max(p.c_KOH_mol_m3 / 1000.0, 1e-6)))
    a_h2o = float(u.get("a_h2o", 0.75))
    p_o2 = float(u.get("p_O2_Pa", p.P_atm_Pa))
    factor = LAYOUT_AREA_FACTOR.get(layout, 1.0)
    i0 = i0_T(p.i0_oer_A_m2, p.Ea_oer_J_mol, T)
    i = I_oer_A / max(p.A_geom_m2 * factor, 1e-12)
    eta = asinh_overpotential_V(i, i0 * max(theta_cat, 0.05), T)
    L_ionic = p.channel_spacing_m if layout in {"interdigitated", "spiral_bifilar"} else p.L_anode_m
    return {
        "E_oer_V": nernst_oxygen_v(T, max(p_o2, 1.0), a_oh, a_h2o),
        "eta_oer_V": eta,
        "i_oer_A_m2": i,
        "n_O2_mol": float(n_O2),
        "theta_cat": float(np.clip(theta_cat, 0.0, 1.0)),
        "theta_bubble": float(np.clip(theta_b, 0.0, 1.0)),
        "area_factor": factor,
        "L_ionic_m": L_ionic,
        "r_oer_mol_s": max(I_oer_A, 0.0) / (4.0 * constants.F_C_MOL),
        "t_s": t,
    }


class OxygenEvolution(RHSComponent):
    """IA-OER-001 oxygen evolution.

    @relation(IA-OER-001, scope=class)
    """

    def __init__(self, p: PlantParams | None = None, y0: NDArray[np.float64] | None = None, layout: str = "interdigitated") -> None:
        if layout not in OER_LAYOUTS:
            raise ValueError(f"OER layout {layout} not in {OER_LAYOUTS}")
        p = p or default_params()
        y0 = default_y0(p) if y0 is None else y0
        self.layout = layout

        def rhs(t, y, inputs, context):  # type: ignore[no-untyped-def]
            return oer_rhs(t, y, inputs, p, layout)

        def out(t, y, inputs, context):  # type: ignore[no-untyped-def]
            return oer_outputs(t, y, inputs, p, layout)

        super().__init__(
            name="oer",
            requirement_ids=("IA-OER-001", "IA-SYS-015"),
            specs=SPECS,
            y0=y0,
            rhs_fn=rhs,
            out_fn=out,
            input_names=("I_oer_A", "T_K", "a_oh", "a_h2o", "p_O2_Pa", "oer_isolated"),
            output_names=("E_oer_V", "eta_oer_V", "n_O2_mol"),
            params=p,
        )
