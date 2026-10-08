"""Air handling and fan ODEs (IA-AIR-001, IA-AIR-002).

@relation(IA-AIR-001, scope=module)

Natural breathing, forced supply, sparging into submerged ORR, cascading
stacked-core flow, snorkel mixed-phase channels (US Claims 9, 14-15).
"""

from __future__ import annotations

from collections.abc import Mapping

import numpy as np
from numpy.typing import NDArray

from plant_sim.bootstrap import setup_path
from plant_sim.components.base import RHSComponent
from plant_sim.params import PlantParams, default_params

setup_path()

from ironair.constants import constants  # noqa: E402
from ironair.ode.state import StateSpec  # noqa: E402

AIR_SPECS = (
    StateSpec("p_man_Pa", "Pa", "manifold pressure", nonnegative=True),
    StateSpec("n_O2_mol", "mol", "manifold oxygen inventory", nonnegative=True),
    StateSpec("n_N2_mol", "mol", "manifold nitrogen inventory", nonnegative=True),
    StateSpec("n_H2O_vap_mol", "mol", "humidity inventory", nonnegative=True),
    StateSpec("n_CO2_mol", "mol", "manifold CO2 inventory", nonnegative=True),
)

FAN_SPECS = (
    StateSpec("omega_rad_s", "rad/s", "rotor speed", nonnegative=True),
)


def air_y0(p: PlantParams | None = None) -> NDArray[np.float64]:
    p = p or default_params()
    n_tot = p.P_atm_Pa * p.V_manifold_m3 / (constants.R_J_MOL_K * p.T_ep_sim_K)
    return np.array(
        [
            p.P_atm_Pa,
            p.x_O2_air * n_tot,
            (1.0 - p.x_O2_air - p.x_CO2_air) * n_tot,
            0.01 * n_tot,
            p.x_CO2_air * n_tot,
        ],
        dtype=np.float64,
    )


def air_rhs(
    t: float,
    y: NDArray[np.float64],
    u: Mapping[str, float],
    p: PlantParams,
) -> NDArray[np.float64]:
    """Manifold pressure and gas-inventory RHS.

    @relation(IA-AIR-001, scope=function)
    """
    p_man, n_O2, n_N2, n_w, n_CO2 = y
    T = float(u.get("T_K", p.T_ep_sim_K))
    mdot_in = float(u.get("mdot_air_kg_s", 0.0))
    r_orr = float(u.get("r_orr_mol_s", 0.0))
    r_oer = float(u.get("r_oer_mol_s", 0.0))
    k_out = 2.5e-4
    n_tot = max(n_O2 + n_N2 + n_w + n_CO2, 1e-8)
    MW = 0.029
    n_dot_in = mdot_in / MW
    x_O2 = n_O2 / n_tot
    n_dot_out = k_out * (p_man - p.P_atm_Pa)
    dn_O2 = n_dot_in * p.x_O2_air - n_dot_out * x_O2 - r_orr + r_oer
    dn_N2 = n_dot_in * (1.0 - p.x_O2_air - p.x_CO2_air) - n_dot_out * (n_N2 / n_tot)
    dn_w = n_dot_in * 0.01 - n_dot_out * (n_w / n_tot)
    dn_CO2 = n_dot_in * p.x_CO2_air - n_dot_out * (n_CO2 / n_tot)
    n_tot2 = n_tot + dn_O2 + dn_N2 + dn_w + dn_CO2
    p_target = n_tot2 * constants.R_J_MOL_K * T / max(p.V_manifold_m3, 1e-8)
    dp = (p_target - p_man) / 0.3
    _ = t
    return np.array([dp, dn_O2, dn_N2, dn_w, dn_CO2], dtype=np.float64)


def air_outputs(
    t: float,
    y: NDArray[np.float64],
    u: Mapping[str, float],
    p: PlantParams,
) -> dict[str, float]:
    p_man, n_O2, n_N2, n_w, n_CO2 = y
    n_tot = max(n_O2 + n_N2 + n_w + n_CO2, 1e-12)
    x_O2 = n_O2 / n_tot
    p_O2 = x_O2 * p_man
    return {
        "p_man_Pa": float(p_man),
        "x_O2": float(x_O2),
        "x_CO2": float(n_CO2 / n_tot),
        "p_O2_Pa": float(p_O2),
        "p_O2_atm": float(p_O2 / p.P_atm_Pa),
        "RH_approx": float(np.clip(n_w / n_tot / 0.03, 0.0, 1.5)),
        "t_s": t,
    }


class AirSystem(RHSComponent):
    """IA-AIR-001 air handling manifold.

    @relation(IA-AIR-001, scope=class)
    """

    def __init__(self, p: PlantParams | None = None, y0: NDArray[np.float64] | None = None) -> None:
        p = p or default_params()
        y0 = air_y0(p) if y0 is None else y0

        def rhs(t, y, inputs, context):  # type: ignore[no-untyped-def]
            return air_rhs(t, y, inputs, p)

        def out(t, y, inputs, context):  # type: ignore[no-untyped-def]
            return air_outputs(t, y, inputs, p)

        super().__init__(
            name="air",
            requirement_ids=("IA-AIR-001", "IA-SYS-014"),
            specs=AIR_SPECS,
            y0=y0,
            rhs_fn=rhs,
            out_fn=out,
            input_names=("mdot_air_kg_s", "r_orr_mol_s", "r_oer_mol_s", "T_K"),
            output_names=("p_man_Pa", "x_O2", "p_O2_atm"),
            params=p,
        )


def fan_rhs(
    t: float,
    y: NDArray[np.float64],
    u: Mapping[str, float],
    p: PlantParams,
) -> NDArray[np.float64]:
    omega = y[0]
    I_fan = float(u.get("I_fan_A", 0.0))
    tau = p.k_fan_Nm_A * I_fan - p.b_fan_Nms * omega
    domega = tau / p.J_fan_kg_m2
    _ = t
    return np.array([max(domega, -omega / 0.05 if omega < 0 else domega)], dtype=np.float64)


class Fan(RHSComponent):
    def __init__(self, p: PlantParams | None = None) -> None:
        p = p or default_params()
        y0 = np.array([10.0], dtype=np.float64)

        def rhs(t, y, inputs, context):  # type: ignore[no-untyped-def]
            return fan_rhs(t, y, inputs, p)

        def out(t, y, inputs, context):  # type: ignore[no-untyped-def]
            omega = float(y[0])
            mdot = 1.2e-5 * omega
            P_el = p.k_fan_Nm_A * float(inputs.get("I_fan_A", 0.0)) * omega
            return {"omega_rad_s": omega, "mdot_air_kg_s": mdot, "P_fan_W": P_el, "t_s": t}

        super().__init__(
            name="fan",
            requirement_ids=("IA-AIR-002",),
            specs=FAN_SPECS,
            y0=y0,
            rhs_fn=rhs,
            out_fn=out,
            input_names=("I_fan_A",),
            output_names=("omega_rad_s", "mdot_air_kg_s", "P_fan_W"),
            params=p,
        )
