"""Separator ODE (IA-SEP-001).

Hydrophilic macroporous separator that blocks dissolved O2 / bubbles from the
iron electrode without a large ionic-resistance penalty (US FIG. 4A; EP Claim 2).
R_ionic = L / (sigma A s^1.5 / tau).
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
from ironair.properties import koh_conductivity_s_m, oxygen_diffusivity_m2_s  # noqa: E402

SPECS = (
    StateSpec("T_K", "K", "separator temperature"),
    StateSpec("saturation", "1", "electrolyte saturation", nonnegative=True),
    StateSpec("c_O2_mol_m3", "mol/m3", "dissolved oxygen in separator", nonnegative=True),
    StateSpec("deg", "1", "separator degradation", nonnegative=True),
)


def default_y0(p: PlantParams | None = None) -> NDArray[np.float64]:
    p = p or default_params()
    return np.array([p.T_ep_sim_K, 0.95, 1e-4, 0.0], dtype=np.float64)


def ionic_resistance_ohm(T: float, c_KOH: float, s: float, deg: float, p: PlantParams) -> float:
    sigma = koh_conductivity_s_m(min(max(T, 274.0), 372.0), min(max(c_KOH, 0.0), 12000.0))
    s_eff = max(s, 0.05) ** 1.5
    return p.L_sep_m * p.tortuosity_sep * (1.0 + 3.0 * deg) / (sigma * p.A_geom_m2 * s_eff * p.eps_sep + 1e-18)


def separator_rhs(
    t: float,
    y: NDArray[np.float64],
    u: Mapping[str, float],
    p: PlantParams,
) -> NDArray[np.float64]:
    T, s, c_O2, deg = y
    T_ely = float(u.get("T_ely_K", p.T_ep_sim_K))
    c_O2_ely = float(u.get("c_O2_ely_mol_m3", 0.0))
    I_A = float(u.get("I_cell_A", 0.0))
    c_KOH = float(u.get("c_KOH_mol_m3", p.c_KOH_mol_m3))
    fill = float(u.get("s_wet", s))
    D = oxygen_diffusivity_m2_s(min(max(T, 274.0), 372.0), min(max(c_KOH, 0.0), 12000.0))
    D_eff = D * p.eps_sep / p.tortuosity_sep / p.k_o2_block
    dc = D_eff * (c_O2_ely - c_O2) / max(p.L_sep_m, 1e-6) ** 2 * p.L_sep_m - 0.02 * c_O2
    ds = 0.4 * (fill - s)
    R = ionic_resistance_ohm(T, c_KOH, s, deg, p)
    q = I_A**2 * R
    mCp = 800.0 * p.A_geom_m2 * p.L_sep_m * 2000.0
    dT = (q + 50.0 * (T_ely - T)) / max(mCp, 1.0)
    ddeg = 2e-9 * abs(I_A) + 1e-8 * max(c_O2 - 1e-3, 0.0)
    _ = t
    return np.array([dT, ds, dc, ddeg], dtype=np.float64)


def separator_outputs(
    t: float,
    y: NDArray[np.float64],
    u: Mapping[str, float],
    p: PlantParams,
) -> dict[str, float]:
    T, s, c_O2, deg = y
    c_KOH = float(u.get("c_KOH_mol_m3", p.c_KOH_mol_m3))
    I_A = float(u.get("I_cell_A", 0.0))
    R = ionic_resistance_ohm(T, c_KOH, s, deg, p)
    return {
        "R_ionic_ohm": R,
        "V_ionic_V": I_A * R,
        "T_K": float(T),
        "saturation": float(np.clip(s, 0.0, 1.0)),
        "c_O2_mol_m3": float(max(c_O2, 0.0)),
        "O2_crossover_flux_mol_m2_s": float(c_O2) * 1e-8,
        "degradation": float(deg),
        "t_s": t,
    }


class Separator(RHSComponent):
    def __init__(self, p: PlantParams | None = None, y0: NDArray[np.float64] | None = None) -> None:
        p = p or default_params()
        y0 = default_y0(p) if y0 is None else y0

        def rhs(t, y, inputs, context):  # type: ignore[no-untyped-def]
            return separator_rhs(t, y, inputs, p)

        def out(t, y, inputs, context):  # type: ignore[no-untyped-def]
            return separator_outputs(t, y, inputs, p)

        super().__init__(
            name="separator",
            requirement_ids=("IA-SEP-001", "IA-SYS-025"),
            specs=SPECS,
            y0=y0,
            rhs_fn=rhs,
            out_fn=out,
            input_names=("T_ely_K", "c_KOH_mol_m3", "I_cell_A", "s_wet", "c_O2_ely_mol_m3"),
            output_names=("R_ionic_ohm", "V_ionic_V", "c_O2_mol_m3"),
            params=p,
        )
