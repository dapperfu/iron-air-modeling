"""Iron electrode ODE (IA-FE-001).

@relation(IA-FE-001, scope=module)

States: n_Fe, n_FeOH2, n_Fe3O4, T, passivation thickness, porosity, a_rel, n_lost.

Discharge Fe -> Fe(OH)2 (2 e-, 960 mAh/g) then Fe(OH)2 -> Fe3O4 (2 e- / 3 Fe, 320 mAh/g).
DRI pellet beds, porous particles, and channeled rib electrodes share this RHS.
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

from ironair.chemistry.network import faraday_rate_mol_s  # noqa: E402
from ironair.chemistry.nernst import nernst_iron_v, nernst_magnetite_v  # noqa: E402
from ironair.ode.state import StateSpec  # noqa: E402

V_FE_M3_MOL = 7.09e-6
V_FEOH2_M3_MOL = 2.64e-5
V_FE3O4_M3_MOL = 4.46e-5

SPECS = (
    StateSpec("n_Fe_mol", "mol", "metallic iron inventory", nonnegative=True),
    StateSpec("n_FeOH2_mol", "mol", "ferrous hydroxide inventory", nonnegative=True),
    StateSpec("n_Fe3O4_mol", "mol", "magnetite inventory", nonnegative=True),
    StateSpec("T_K", "K", "electrode temperature"),
    StateSpec("delta_pass_m", "m", "passivation film thickness", nonnegative=True),
    StateSpec("porosity", "1", "electrode porosity", nonnegative=True),
    StateSpec("a_rel", "1", "relative active area", nonnegative=True),
    StateSpec("n_lost_mol", "mol", "irreversible iron loss", nonnegative=True),
)


def default_y0(p: PlantParams | None = None) -> NDArray[np.float64]:
    p = p or default_params()
    return np.array(
        [p.n_Fe0_mol, 1e-8, 1e-10, p.T_ep_sim_K, 1e-9, p.porosity_rib, 1.0, 0.0],
        dtype=np.float64,
    )


def _split_rates(I_A: float, n_Fe: float, n_FeOH2: float, n_Fe3O4: float) -> tuple[float, float]:
    """Positive I is anodic (discharge). Split between Fe/Fe(OH)2 and magnetite steps."""
    r_total = faraday_rate_mol_s(I_A, 2.0)
    if I_A >= 0.0:
        w1 = n_Fe / (n_Fe + 0.15 * n_FeOH2 + 1e-12)
        r_iron = r_total * w1
        r_mag = r_total * (1.0 - w1) / 1.0
        r_mag = min(r_mag, n_FeOH2 / 3.0 * 10.0)
        return r_iron, r_mag
    remain_oh2 = max(n_FeOH2, 0.0)
    remain_mag = max(n_Fe3O4, 0.0)
    w_mag = remain_mag / (remain_mag + 0.2 * remain_oh2 + 1e-12)
    r_mag = r_total * w_mag
    r_iron = r_total * (1.0 - w_mag)
    return r_iron, r_mag


def iron_anode_rhs(
    t: float,
    y: NDArray[np.float64],
    u: Mapping[str, float],
    p: PlantParams,
) -> NDArray[np.float64]:
    """Faraday iron-phase RHS (Fe / Fe(OH)2 / Fe3O4).

    @relation(IA-FE-001, scope=function)
    """
    n_Fe, n_FeOH2, n_Fe3O4, T, delta, eps, a_rel, n_lost = y
    I_A = float(u.get("I_fe_A", 0.0))
    T_amb = float(u.get("T_amb_K", p.T_ep_sim_K))
    a_oh = float(u.get("a_oh", max(p.c_KOH_mol_m3 / 1000.0, 1e-6)))
    a_h2o = float(u.get("a_h2o", 0.75))
    V_e = p.A_geom_m2 * p.L_anode_m

    avail = float(np.clip(a_rel, 1e-4, 1.0) * np.exp(-delta / p.delta_pass_ref_m))
    i0 = i0_T(p.i0_fe_A_m2, p.Ea_fe_J_mol, T)
    i_A_m2 = I_A / max(p.A_geom_m2 * avail, 1e-8)
    eta = asinh_overpotential_V(i_A_m2, i0, T, p.alpha_a)

    r_iron, r_mag = _split_rates(I_A, max(n_Fe, 0.0), max(n_FeOH2, 0.0), max(n_Fe3O4, 0.0))

    dn_Fe = -r_iron
    dn_FeOH2 = r_iron - 3.0 * r_mag
    dn_Fe3O4 = r_mag
    if n_Fe <= 0.0 and dn_Fe < 0.0:
        dn_Fe = 0.0
    if n_FeOH2 <= 0.0 and dn_FeOH2 < 0.0:
        dn_FeOH2 = 0.0
    if n_Fe3O4 <= 0.0 and dn_Fe3O4 < 0.0:
        dn_Fe3O4 = 0.0

    k_loss = 2e-7 * max(I_A, 0.0) / max(p.Q_step1_C, 1.0)
    dn_lost = k_loss * max(n_Fe, 0.0)
    dn_Fe -= dn_lost

    d_delta = p.k_pass_m4_mol * max(r_iron, 0.0) - 1e-5 * max(a_oh, 0.0) * delta
    if delta <= 0.0 and d_delta < 0.0:
        d_delta = 0.0

    solid = n_Fe * V_FE_M3_MOL + n_FeOH2 * V_FEOH2_M3_MOL + n_Fe3O4 * V_FE3O4_M3_MOL
    eps_target = float(np.clip(1.0 - solid / max(V_e, 1e-12), 0.05, 0.95))
    d_eps = (eps_target - eps) / 30.0

    a_target = float(np.clip((n_Fe / max(p.n_Fe0_mol, 1e-12)) ** 0.67 * np.exp(-delta / p.delta_pass_ref_m), 0.02, 1.0))
    da = (a_target - a_rel) / 20.0

    mCp = max(p.m_fe_kg, 1e-4) * p.Cp_fe_J_kg_K
    q_irrev = I_A * eta
    q_conv = p.h_conv_W_m2_K * p.A_geom_m2 * (T_amb - T)
    dT = (q_irrev + q_conv) / mCp

    _ = (t, nernst_iron_v(T, a_oh), nernst_magnetite_v(T, a_oh, a_h2o))
    return np.array([dn_Fe, dn_FeOH2, dn_Fe3O4, dT, d_delta, d_eps, da, dn_lost], dtype=np.float64)


def iron_anode_outputs(
    t: float,
    y: NDArray[np.float64],
    u: Mapping[str, float],
    p: PlantParams,
) -> dict[str, float]:
    n_Fe, n_FeOH2, n_Fe3O4, T, delta, eps, a_rel, n_lost = y
    I_A = float(u.get("I_fe_A", 0.0))
    a_oh = float(u.get("a_oh", max(p.c_KOH_mol_m3 / 1000.0, 1e-6)))
    a_h2o = float(u.get("a_h2o", 0.75))
    avail = float(np.clip(a_rel, 1e-4, 1.0) * np.exp(-delta / p.delta_pass_ref_m))
    i0 = i0_T(p.i0_fe_A_m2, p.Ea_fe_J_mol, T)
    i_A_m2 = I_A / max(p.A_geom_m2 * avail, 1e-8)
    eta = asinh_overpotential_V(i_A_m2, i0, T, p.alpha_a)
    soc = float(np.clip(n_Fe / max(p.n_Fe0_mol, 1e-12), 0.0, 1.0))
    q_used_C = 2.0 * 96485.3321233100184 * (p.n_Fe0_mol - n_Fe)
    cap_mah_g = q_used_C / max(p.m_fe_kg * 3.6 * 1000.0, 1e-18) if p.m_fe_kg > 0 else 0.0
    return {
        "E_fe_V": nernst_iron_v(T, a_oh),
        "E_mag_V": nernst_magnetite_v(T, a_oh, a_h2o),
        "eta_fe_V": eta,
        "i_fe_A_m2": i_A_m2,
        "SOC_Fe": soc,
        "capacity_extracted_mAh_g": cap_mah_g,
        "porosity": float(eps),
        "vf_electrolyte": float(np.clip(eps, p.vf_min, p.vf_max)),
        "passivation_m": float(delta),
        "n_lost_mol": float(n_lost),
        "T_K": float(T),
        "t_s": t,
        "n_Fe3O4_mol": float(n_Fe3O4),
        "n_FeOH2_mol": float(n_FeOH2),
    }


class IronAnode(RHSComponent):
    """IA-FE-001 iron electrode.

    @relation(IA-FE-001, scope=class)
    """

    def __init__(self, p: PlantParams | None = None, y0: NDArray[np.float64] | None = None) -> None:
        p = p or default_params()
        y0 = default_y0(p) if y0 is None else y0

        def rhs(t, y, inputs, context):  # type: ignore[no-untyped-def]
            return iron_anode_rhs(t, y, inputs, p)

        def out(t, y, inputs, context):  # type: ignore[no-untyped-def]
            return iron_anode_outputs(t, y, inputs, p)

        super().__init__(
            name="iron_anode",
            requirement_ids=("IA-FE-001", "IA-SYS-016", "IA-SYS-018", "IA-SYS-020"),
            specs=SPECS,
            y0=y0,
            rhs_fn=rhs,
            out_fn=out,
            input_names=("I_fe_A", "T_amb_K", "a_oh", "a_h2o"),
            output_names=("E_fe_V", "eta_fe_V", "SOC_Fe", "capacity_extracted_mAh_g"),
            params=p,
        )
