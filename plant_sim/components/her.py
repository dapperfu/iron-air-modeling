"""Hydrogen evolution ODE (IA-HER-001).

@relation(IA-HER-001, scope=module)

HER 2 H2O + 2 e- -> H2 + 2 OH- competes with iron recharge (EP4602674A1 [0044]-[0047]).
Vertical channels provide bubble egress; thick planar electrodes lose coulombic efficiency
when ionic path to the back exceeds front-surface HER.
"""

from __future__ import annotations

from collections.abc import Mapping
from typing import Any

import numpy as np
from numpy.typing import NDArray

from plant_sim.bootstrap import setup_path
from plant_sim.components.base import RHSComponent, asinh_overpotential_V, i0_T
from plant_sim.params import PlantParams, default_params

setup_path()

from ironair.chemistry.nernst import nernst_her_v  # noqa: E402
from ironair.constants import constants  # noqa: E402
from ironair.ode.state import StateSpec  # noqa: E402
from ironair.properties import koh_conductivity_s_m  # noqa: E402

SPECS = (
    StateSpec("n_H2_mol", "mol", "hydrogen inventory", nonnegative=True),
    StateSpec("theta_bubble", "1", "channel bubble holdup", nonnegative=True),
    StateSpec("p_H2_Pa", "Pa", "local hydrogen partial pressure", nonnegative=True),
)


def default_y0(p: PlantParams | None = None) -> NDArray[np.float64]:
    p = p or default_params()
    return np.array([1e-8, 0.02, 100.0], dtype=np.float64)


def her_current_split_A(
    I_charge_A: float,
    L_path_m: float,
    temperature_K: float,
    p: PlantParams,
    theta_bubble: float,
) -> tuple[float, float, float]:
    """Split cathodic charge current into iron reduction vs HER.

    Ionic resistance to the back of a thick electrode raises the fraction that
    goes to front-surface HER (EP [0047]). Channels shorten L_path.
    """
    I_c = max(-I_charge_A, 0.0)  # cathodic magnitude during charge (I_fe anodic-positive)
    if I_c <= 0.0:
        return 0.0, 0.0, 1.0
    sigma = koh_conductivity_s_m(temperature_K, p.c_KOH_mol_m3)
    R_ionic = L_path_m / (sigma * p.A_geom_m2 * max(p.porosity_rib, 0.05) ** 1.5 + 1e-12)
    i0_her = i0_T(p.i0_her_A_m2, p.Ea_her_J_mol, temperature_K)
    i0_fe = i0_T(p.i0_fe_A_m2, p.Ea_fe_J_mol, temperature_K)
    egress = 1.0 / (1.0 + 8.0 * theta_bubble)
    k_her = i0_her * p.A_geom_m2 * (1.0 + 4.0 * R_ionic) * (0.3 + 0.7 * (1.0 - p.chan_frac))
    k_fe = i0_fe * p.A_geom_m2 * egress / (1.0 + R_ionic * 50.0)
    I_her = I_c * k_her / (k_her + k_fe + 1e-18)
    I_fe_red = I_c - I_her
    ce = I_fe_red / (I_c + 1e-18)
    return I_her, I_fe_red, float(np.clip(ce, 0.0, 1.0))


def her_rhs(
    t: float,
    y: NDArray[np.float64],
    u: Mapping[str, float],
    p: PlantParams,
) -> NDArray[np.float64]:
    """HER inventory and bubble-holdup RHS.

    @relation(IA-HER-001, scope=function)
    """
    n_H2, theta, p_H2 = y
    I_fe_A = float(u.get("I_fe_A", 0.0))
    T = float(u.get("T_K", p.T_ep_sim_K))
    L_path = float(u.get("L_path_m", p.L_anode_m))
    p_head = float(u.get("p_headspace_Pa", p.P_atm_Pa))
    I_her, _I_fe, _ce = her_current_split_A(I_fe_A, L_path, T, p, theta)
    r_her = I_her / (2.0 * constants.F_C_MOL)
    dn_H2 = r_her
    vent = 0.15 * max(p_H2 - p_head * 0.001, 0.0) / constants.R_J_MOL_K / T * 1e-4
    dn_H2 -= vent
    dtheta = 0.4 * r_her * 1e3 - (0.05 + 2.0 * p.chan_frac) * theta
    if theta <= 0.0 and dtheta < 0.0:
        dtheta = 0.0
    V_hs = p.V_headspace_m3
    dp = (dn_H2 * constants.R_J_MOL_K * T / max(V_hs, 1e-6)) - 0.2 * (p_H2 - 1.0)
    _ = t
    return np.array([dn_H2, dtheta, dp], dtype=np.float64)


def her_outputs(
    t: float,
    y: NDArray[np.float64],
    u: Mapping[str, float],
    p: PlantParams,
) -> dict[str, float]:
    n_H2, theta, p_H2 = y
    I_fe_A = float(u.get("I_fe_A", 0.0))
    T = float(u.get("T_K", p.T_ep_sim_K))
    L_path = float(u.get("L_path_m", p.L_anode_m))
    a_oh = float(u.get("a_oh", max(p.c_KOH_mol_m3 / 1000.0, 1e-6)))
    a_h2o = float(u.get("a_h2o", 0.75))
    I_her, I_fe_red, ce = her_current_split_A(I_fe_A, L_path, T, p, theta)
    i_her = I_her / max(p.A_geom_m2, 1e-12)
    eta = asinh_overpotential_V(-i_her, i0_T(p.i0_her_A_m2, p.Ea_her_J_mol, T), T)
    return {
        "n_H2_mol": float(n_H2),
        "I_her_A": I_her,
        "I_fe_red_A": I_fe_red,
        "CE": ce,
        "theta_bubble": float(np.clip(theta, 0.0, 1.0)),
        "p_H2_Pa": float(max(p_H2, 1.0)),
        "E_her_V": nernst_her_v(T, max(p_H2, 1.0), a_oh, a_h2o),
        "eta_her_V": eta,
        "t_s": t,
    }


class HydrogenEvolution(RHSComponent):
    """IA-HER-001 hydrogen evolution.

    @relation(IA-HER-001, scope=class)
    """

    def __init__(self, p: PlantParams | None = None, y0: NDArray[np.float64] | None = None) -> None:
        p = p or default_params()
        y0 = default_y0(p) if y0 is None else y0

        def rhs(t, y, inputs, context):  # type: ignore[no-untyped-def]
            return her_rhs(t, y, inputs, p)

        def out(t, y, inputs, context):  # type: ignore[no-untyped-def]
            return her_outputs(t, y, inputs, p)

        super().__init__(
            name="her",
            requirement_ids=("IA-HER-001", "IA-SYS-020", "IA-SYS-023"),
            specs=SPECS,
            y0=y0,
            rhs_fn=rhs,
            out_fn=out,
            input_names=("I_fe_A", "T_K", "L_path_m", "a_oh", "a_h2o"),
            output_names=("I_her_A", "CE", "n_H2_mol"),
            params=p,
        )
