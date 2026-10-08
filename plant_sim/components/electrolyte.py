"""Electrolyte ODE (IA-ELY-001).

Default 6 M KOH. Tracks water, OH-, carbonate, volume, and temperature.
Carbonation: CO2 + 2 OH- -> CO3^2- + H2O (US12308414B2). High hydroxide
(>= 7 M) is an allowed CE/capacity lever (EP4602674A1).
"""

from __future__ import annotations

from collections.abc import Mapping

import numpy as np
from numpy.typing import NDArray

from plant_sim.bootstrap import setup_path
from plant_sim.components.base import RHSComponent
from plant_sim.params import PlantParams, default_params

setup_path()

from ironair.chemistry.network import DEFAULT_NETWORK, Reaction  # noqa: E402
from ironair.constants import constants  # noqa: E402
from ironair.ode.state import StateSpec  # noqa: E402
from ironair.properties import (  # noqa: E402
    koh_conductivity_s_m,
    koh_density_kg_m3,
    koh_heat_capacity_j_kg_k,
    koh_water_activity,
)

SPECS = (
    StateSpec("n_OH_mol", "mol", "hydroxide inventory", nonnegative=True),
    StateSpec("n_H2O_mol", "mol", "water inventory", nonnegative=True),
    StateSpec("n_CO3_mol", "mol", "carbonate inventory", nonnegative=True),
    StateSpec("n_CO2_aq_mol", "mol", "dissolved CO2", nonnegative=True),
    StateSpec("T_K", "K", "electrolyte temperature"),
    StateSpec("V_m3", "m3", "electrolyte volume", nonnegative=True),
    StateSpec("s_wet", "1", "pore wetting saturation", nonnegative=True),
)


def default_y0(p: PlantParams | None = None, filled: bool = True) -> NDArray[np.float64]:
    p = p or default_params()
    V = p.A_geom_m2 * p.L_anode_m * p.vf_electrolyte_charged
    if not filled:
        V = 1e-6
    n_OH = p.c_KOH_mol_m3 * V
    dens = koh_density_kg_m3(p.T_ep_sim_K, p.c_KOH_mol_m3)
    n_H2O = max((dens * V - n_OH * constants.M_KOH_KG_MOL) / constants.M_H2O_KG_MOL, 1e-6)
    s_wet = 1.0 if filled else 0.02
    return np.array([n_OH, n_H2O, 1e-8, 1e-10, p.T_ep_sim_K, max(V, 1e-6), s_wet], dtype=np.float64)


def electrolyte_rhs(
    t: float,
    y: NDArray[np.float64],
    u: Mapping[str, float],
    p: PlantParams,
) -> NDArray[np.float64]:
    n_OH, n_H2O, n_CO3, n_CO2, T, V, s_wet = y
    V = max(V, 1e-8)
    r_iron = float(u.get("r_iron_mol_s", 0.0))
    r_mag = float(u.get("r_mag_mol_s", 0.0))
    r_orr = float(u.get("r_orr_mol_s", 0.0))
    r_oer = float(u.get("r_oer_mol_s", 0.0))
    r_her = float(u.get("r_her_mol_s", 0.0))
    fill_m3_s = float(u.get("fill_m3_s", 0.0))
    T_amb = float(u.get("T_amb_K", p.T_ep_sim_K))
    x_CO2 = float(u.get("x_CO2", p.x_CO2_air))
    p_air = float(u.get("P_Pa", p.P_atm_Pa))
    q_heat = float(u.get("q_heat_W", 0.0))

    rates = np.zeros(6)
    rates[int(Reaction.IRON)] = r_iron
    rates[int(Reaction.MAGNETITE)] = r_mag
    rates[int(Reaction.ORR)] = r_orr
    rates[int(Reaction.OER)] = r_oer
    rates[int(Reaction.HER)] = r_her
    dn = DEFAULT_NETWORK.inventory_derivative(rates)

    c_CO2 = x_CO2 * p_air / (constants.R_J_MOL_K * T) * 0.03
    r_carb = p.k_carb_m3_mol_s * (n_OH / V) * max(n_CO2 / V, c_CO2) * V
    dn_OH = dn[3] - 2.0 * r_carb
    dn_H2O = dn[4] + r_carb
    dn_CO3 = dn[8] + r_carb
    dn_CO2 = c_CO2 * 1e-4 * p.A_thermal_m2 - r_carb

    c_fill = p.c_KOH_mol_m3
    dens = koh_density_kg_m3(min(max(T, 274.0), 372.0), min(max(n_OH / V, 0.0), 12000.0))
    n_OH_fill = c_fill * fill_m3_s
    n_H2O_fill = max((dens * fill_m3_s - n_OH_fill * constants.M_KOH_KG_MOL) / constants.M_H2O_KG_MOL, 0.0)
    dn_OH += n_OH_fill
    dn_H2O += n_H2O_fill
    dV = fill_m3_s
    ds = 0.15 * fill_m3_s / max(p.A_geom_m2 * p.L_anode_m * p.vf_electrolyte_charged, 1e-8) + 0.02 * (1.0 - s_wet) * (1.0 if V > 1e-4 else 0.0)
    if s_wet >= 1.0 and ds > 0.0:
        ds = 0.0

    Cp = koh_heat_capacity_j_kg_k(min(max(T, 274.0), 372.0), min(max(n_OH / V, 0.0), 12000.0))
    m = dens * V
    dT = (q_heat + p.h_conv_W_m2_K * p.A_thermal_m2 * (T_amb - T)) / max(m * Cp, 1.0)
    _ = t
    return np.array([dn_OH, dn_H2O, dn_CO3, dn_CO2, dT, dV, ds], dtype=np.float64)


def electrolyte_outputs(
    t: float,
    y: NDArray[np.float64],
    u: Mapping[str, float],
    p: PlantParams,
) -> dict[str, float]:
    n_OH, n_H2O, n_CO3, n_CO2, T, V, s_wet = y
    V = max(V, 1e-12)
    c_OH = n_OH / V
    Tclip = min(max(T, 274.0), 372.0)
    cclip = min(max(c_OH, 0.0), 12000.0)
    pH = 14.0 + np.log10(max(c_OH / 1000.0, 1e-12))
    return {
        "c_OH_mol_m3": c_OH,
        "c_KOH_M": c_OH / 1000.0,
        "c_CO3_mol_m3": n_CO3 / V,
        "sigma_S_m": koh_conductivity_s_m(Tclip, cclip),
        "density_kg_m3": koh_density_kg_m3(Tclip, cclip),
        "a_H2O": koh_water_activity(Tclip, cclip),
        "a_OH": max(c_OH / 1000.0, 1e-12),
        "pH": float(pH),
        "T_K": float(T),
        "V_m3": float(V),
        "s_wet": float(np.clip(s_wet, 0.0, 1.0)),
        "n_OH_mol": float(n_OH),
        "n_H2O_mol": float(n_H2O),
        "n_CO3_mol": float(n_CO3),
        "t_s": t,
    }


class Electrolyte(RHSComponent):
    def __init__(self, p: PlantParams | None = None, y0: NDArray[np.float64] | None = None, filled: bool = True) -> None:
        p = p or default_params()
        y0 = default_y0(p, filled=filled) if y0 is None else y0

        def rhs(t, y, inputs, context):  # type: ignore[no-untyped-def]
            return electrolyte_rhs(t, y, inputs, p)

        def out(t, y, inputs, context):  # type: ignore[no-untyped-def]
            return electrolyte_outputs(t, y, inputs, p)

        super().__init__(
            name="electrolyte",
            requirement_ids=("IA-ELY-001", "IA-SYS-021", "IA-SYS-023"),
            specs=SPECS,
            y0=y0,
            rhs_fn=rhs,
            out_fn=out,
            input_names=("r_iron_mol_s", "r_orr_mol_s", "r_oer_mol_s", "r_her_mol_s", "fill_m3_s", "x_CO2", "q_heat_W"),
            output_names=("c_KOH_M", "sigma_S_m", "pH", "a_OH", "s_wet"),
            params=p,
        )
