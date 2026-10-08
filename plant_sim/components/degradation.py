"""Degradation ODE (IA-DEG-001): ORR damage, PTFE loss, carbonate clog, passivation."""

from __future__ import annotations

from collections.abc import Mapping

import numpy as np
from numpy.typing import NDArray

from plant_sim.bootstrap import setup_path
from plant_sim.components.base import RHSComponent
from plant_sim.params import PlantParams, default_params

setup_path()

from ironair.ode.state import StateSpec  # noqa: E402

SPECS = (
    StateSpec("Q_lost_C", "C", "irreversible capacity loss", nonnegative=True),
    StateSpec("R_growth", "1", "ASR growth factor", nonnegative=True),
    StateSpec("k_orr_decay", "1", "ORR activity loss", nonnegative=True),
    StateSpec("ptfe_loss", "1", "PTFE hydrophobicity loss", nonnegative=True),
)


def default_y0() -> NDArray[np.float64]:
    return np.array([0.0, 0.0, 0.0, 0.0], dtype=np.float64)


def degradation_rhs(t: float, y: NDArray[np.float64], u: Mapping[str, float], p: PlantParams) -> NDArray[np.float64]:
    Q, Rg, kdec, ptfe = y
    I = float(u.get("I_cell_A", 0.0))
    eta_oer = float(u.get("eta_oer_V", 0.0))
    r_carb = float(u.get("r_carb_mol_s", 0.0))
    s_flood = float(u.get("saturation", 0.0))
    isolated = float(u.get("oer_isolated", 1.0))
    dQ = 1e-3 * abs(I) * (0.002 + 0.01 * kdec)
    dR = 2e-8 * abs(I) + 5e-6 * r_carb + 1e-7 * s_flood
    dorr = 3e-6 * max(eta_oer - 0.35, 0.0) * (1.0 - isolated)
    dptfe = 1e-7 * s_flood + 0.4 * dorr
    _ = (t, p, Q)
    return np.array([dQ, dR, dorr, dptfe], dtype=np.float64)


class Degradation(RHSComponent):
    def __init__(self, p: PlantParams | None = None) -> None:
        p = p or default_params()

        def rhs(t, y, inputs, context):  # type: ignore[no-untyped-def]
            return degradation_rhs(t, y, inputs, p)

        def out(t, y, inputs, context):  # type: ignore[no-untyped-def]
            Q, Rg, kdec, ptfe = y
            return {
                "Q_lost_C": float(Q),
                "ASR_growth": float(Rg),
                "orr_activity": float(np.clip(1.0 - kdec, 0.05, 1.0)),
                "ptfe_loss": float(np.clip(ptfe, 0.0, 1.0)),
                "CE_fade": float(np.clip(Rg * 0.15 + kdec * 0.4, 0.0, 0.9)),
                "t_s": t,
            }

        super().__init__(
            name="degradation",
            requirement_ids=("IA-DEG-001", "IA-SYS-023"),
            specs=SPECS,
            y0=default_y0(),
            rhs_fn=rhs,
            out_fn=out,
            input_names=("I_cell_A", "eta_oer_V", "r_carb_mol_s", "saturation", "oer_isolated"),
            output_names=("Q_lost_C", "ASR_growth", "orr_activity", "CE_fade"),
            params=p,
        )
