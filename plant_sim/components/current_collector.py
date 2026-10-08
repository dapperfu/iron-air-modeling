"""Current collector ODE (IA-COL-001).

@relation(IA-COL-001, scope=module)

V_ohm = I * R(T, degradation). No fake lag state for resistance.
Collectors: anode branch-plus-primary, ORR dual-face tabs, Ni-coated-steel with
EPDM compression (US FIGS. 4B-4C), SS mesh in iron ribs (EP), can-negative (US Claim 5).
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
from ironair.properties import iron_conductivity_s_m  # noqa: E402

SPECS = (
    StateSpec("T_K", "K", "collector temperature"),
    StateSpec("deg", "1", "contact degradation state", nonnegative=True),
)


def default_y0(p: PlantParams | None = None) -> NDArray[np.float64]:
    p = p or default_params()
    return np.array([p.T_ep_sim_K, 0.0], dtype=np.float64)


def collector_resistance_ohm(T: float, deg: float, p: PlantParams) -> float:
    r_T = p.R_col_ref_ohm * (1.0 + p.alpha_R_T_1_K * (T - p.T_ref_K))
    return r_T * (1.0 + 4.0 * max(deg, 0.0))


def collector_rhs(
    t: float,
    y: NDArray[np.float64],
    u: Mapping[str, float],
    p: PlantParams,
) -> NDArray[np.float64]:
    """Collector thermal and contact-degradation RHS.

    @relation(IA-COL-001, scope=function)
    """
    T, deg = y
    I_A = float(u.get("I_cell_A", 0.0))
    T_amb = float(u.get("T_amb_K", p.T_ep_sim_K))
    R = collector_resistance_ohm(T, deg, p)
    q = I_A**2 * R
    mCp = 0.4 * 500.0
    dT = (q + 8.0 * p.A_geom_m2 * (T_amb - T)) / mCp
    ddeg = p.k_deg_1_s * (1.0 + 0.02 * abs(I_A))
    _ = t
    return np.array([dT, ddeg], dtype=np.float64)


def collector_outputs(
    t: float,
    y: NDArray[np.float64],
    u: Mapping[str, float],
    p: PlantParams,
) -> dict[str, float]:
    T, deg = y
    I_A = float(u.get("I_cell_A", 0.0))
    R = collector_resistance_ohm(T, deg, p)
    return {
        "R_ohm": R,
        "V_ohm_V": I_A * R,
        "T_K": float(T),
        "degradation": float(deg),
        "sigma_fe_S_m": iron_conductivity_s_m(min(max(T, 274.0), 372.0)),
        "t_s": t,
    }


class CurrentCollector(RHSComponent):
    """IA-COL-001 current collector.

    @relation(IA-COL-001, scope=class)
    """

    def __init__(self, p: PlantParams | None = None, y0: NDArray[np.float64] | None = None, name: str = "collector") -> None:
        p = p or default_params()
        y0 = default_y0(p) if y0 is None else y0

        def rhs(t, y, inputs, context):  # type: ignore[no-untyped-def]
            return collector_rhs(t, y, inputs, p)

        def out(t, y, inputs, context):  # type: ignore[no-untyped-def]
            return collector_outputs(t, y, inputs, p)

        super().__init__(
            name=name,
            requirement_ids=("IA-COL-001", "IA-SYS-025"),
            specs=SPECS,
            y0=y0,
            rhs_fn=rhs,
            out_fn=out,
            input_names=("I_cell_A", "T_amb_K"),
            output_names=("R_ohm", "V_ohm_V"),
            params=p,
        )
