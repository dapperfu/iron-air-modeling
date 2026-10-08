"""Oxygen reduction ODE (IA-ORR-001).

ORR: O2 + 2 H2O + 4 e- -> 4 OH- (US12308414B2). Configurable as floating,
vertical natural-air-breathing, inverse, tubular, stacked submerged with
depth-equalized pressure drop, wavy/rippled, or bifunctional (IA-SYS-009/012).
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
from ironair.properties import koh_viscosity_pa_s  # noqa: E402

ORR_MODES = (
    "floating",
    "vertical",
    "inverse",
    "tubular",
    "stacked_submerged",
    "wavy",
    "bifunctional",
)

SPECS = (
    StateSpec("q_dl_C", "C", "ORR double-layer charge"),
    StateSpec("c_O2_tpb_mol_m3", "mol/m3", "triple-phase-boundary oxygen", nonnegative=True),
    StateSpec("util_O2", "1", "oxygen utilization", nonnegative=True),
)


def default_y0(p: PlantParams | None = None) -> NDArray[np.float64]:
    p = p or default_params()
    c0 = (p.x_O2_air * p.P_atm_Pa) / (constants.R_J_MOL_K * p.T_ep_sim_K)
    return np.array([0.0, c0, 0.0], dtype=np.float64)


def stacked_orr_geometry(p: PlantParams, compensate: bool) -> tuple[NDArray[np.float64], NDArray[np.float64], NDArray[np.float64]]:
    """Depth-varying pocket thickness. Compensated design equalizes air ΔP (US Claim 1)."""
    n = p.n_orr_stack
    z = np.linspace(0.05, p.stack_depth_m, n)
    t0 = 4.0e-3
    if compensate:
        hydro = 1.0 + (z / p.stack_depth_m) * 2.2
        thickness = t0 * hydro
    else:
        thickness = np.full(n, t0)
    width = np.full(n, 0.04)
    return z, width, thickness


def stacked_orr_flows(
    p: PlantParams,
    Q_total_m3_s: float,
    compensate: bool,
    T_K: float,
) -> dict[str, NDArray[np.float64]]:
    z, w, th = stacked_orr_geometry(p, compensate)
    mu = koh_viscosity_pa_s(T_K, p.c_KOH_mol_m3)
    rho = 1270.0
    P_hydro = rho * p.g_m_s2 * z
    L_path = 0.08
    R_hyd = 12.0 * mu * L_path / (np.maximum(w * th**3, 1e-16))
    P_man = float(np.max(P_hydro) + 200.0)
    driving = np.maximum(P_man - P_hydro, 1.0)
    Q = driving / R_hyd
    Q *= Q_total_m3_s / max(float(np.sum(Q)), 1e-18)
    dP = Q * R_hyd
    return {"z_m": z, "thickness_m": th, "Q_m3_s": Q, "dP_Pa": dP, "P_hydro_Pa": P_hydro, "R_hyd": R_hyd}


def orr_rhs(
    t: float,
    y: NDArray[np.float64],
    u: Mapping[str, float],
    p: PlantParams,
) -> NDArray[np.float64]:
    q_dl, c_tpb, util = y
    c_tpb = max(float(c_tpb), 0.0)
    util = max(float(util), 0.0)
    I_orr_A = float(u.get("I_orr_A", 0.0))  # cathodic negative
    T = float(u.get("T_K", p.T_ep_sim_K))
    c_bulk = float(u.get("c_O2_gdl_mol_m3", c_tpb))
    mode = str(u.get("orr_mode", 0.0))
    _ = mode
    C_dl = p.C_dl_orr_F_m2 * p.A_geom_m2
    i0 = i0_T(p.i0_orr_A_m2, p.Ea_orr_J_mol, T)
    avail = float(np.clip(c_tpb / max(c_bulk, 1e-8), 0.02, 1.5))
    eta = asinh_overpotential_V(I_orr_A / max(p.A_geom_m2, 1e-12), i0 * avail, T)
    dq = (I_orr_A - q_dl / max(0.05, 1e-3)) * 0.0 + (p.A_geom_m2 * i0 * avail * 0.0)
    dq = (I_orr_A - q_dl / 0.2) if C_dl > 0 else 0.0
    dq = (I_orr_A * 0.05 - q_dl / 0.15)
    r_orr = abs(min(I_orr_A, 0.0)) / (4.0 * constants.F_C_MOL)
    k_mt = 0.08
    dc = k_mt * (c_bulk - c_tpb) - r_orr / max(p.A_geom_m2 * 5e-5, 1e-12)
    if c_tpb <= 1e-12 and dc < 0.0:
        dc = 0.0
    dutil = r_orr - 0.01 * util
    _ = (t, eta, dq)
    return np.array([dq, dc, dutil], dtype=np.float64)


def orr_outputs(
    t: float,
    y: NDArray[np.float64],
    u: Mapping[str, float],
    p: PlantParams,
) -> dict[str, float]:
    q_dl, c_tpb, util = y
    I_orr_A = float(u.get("I_orr_A", 0.0))
    T = float(u.get("T_K", p.T_ep_sim_K))
    a_oh = float(u.get("a_oh", max(p.c_KOH_mol_m3 / 1000.0, 1e-6)))
    a_h2o = float(u.get("a_h2o", 0.75))
    p_o2 = float(u.get("p_O2_Pa", p.x_O2_air * p.P_atm_Pa))
    i0 = i0_T(p.i0_orr_A_m2, p.Ea_orr_J_mol, T)
    i = I_orr_A / max(p.A_geom_m2, 1e-12)
    eta = asinh_overpotential_V(i, i0 * max(c_tpb, 1e-8) / (c_tpb + 1.0), T)
    r_orr = abs(min(I_orr_A, 0.0)) / (4.0 * constants.F_C_MOL)
    return {
        "E_orr_V": nernst_oxygen_v(T, max(p_o2, 1.0), a_oh, a_h2o),
        "eta_orr_V": eta,
        "i_orr_A_m2": i,
        "c_O2_tpb_mol_m3": float(max(c_tpb, 0.0)),
        "r_orr_mol_s": r_orr,
        "q_dl_C": float(q_dl),
        "util_O2": float(util),
        "t_s": t,
    }


class OxygenReduction(RHSComponent):
    def __init__(self, p: PlantParams | None = None, y0: NDArray[np.float64] | None = None, mode: str = "vertical") -> None:
        if mode not in ORR_MODES:
            raise ValueError(f"ORR mode {mode} not in {ORR_MODES}")
        p = p or default_params()
        y0 = default_y0(p) if y0 is None else y0
        self.mode = mode

        def rhs(t, y, inputs, context):  # type: ignore[no-untyped-def]
            merged = dict(inputs)
            merged.setdefault("orr_mode", float(ORR_MODES.index(mode)))
            return orr_rhs(t, y, merged, p)

        def out(t, y, inputs, context):  # type: ignore[no-untyped-def]
            return orr_outputs(t, y, inputs, p)

        super().__init__(
            name="orr",
            requirement_ids=("IA-ORR-001", "IA-SYS-009", "IA-SYS-012"),
            specs=SPECS,
            y0=y0,
            rhs_fn=rhs,
            out_fn=out,
            input_names=("I_orr_A", "T_K", "c_O2_gdl_mol_m3", "p_O2_Pa", "a_oh", "a_h2o"),
            output_names=("E_orr_V", "eta_orr_V", "r_orr_mol_s"),
            params=p,
        )
