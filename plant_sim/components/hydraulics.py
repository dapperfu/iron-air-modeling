"""Electrolyte hydraulics (IA-FLD-001 through IA-FLD-005).

@relation(IA-FLD-001, scope=module)
@relation(IA-FLD-002, scope=module)
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
from ironair.properties import koh_density_kg_m3, koh_viscosity_pa_s  # noqa: E402

FLOW_SPECS = (
    StateSpec("mdot_kg_s", "kg/s", "circulation mass flow"),
    StateSpec("p_header_Pa", "Pa", "header pressure", nonnegative=True),
    StateSpec("T_loop_K", "K", "loop temperature"),
)
PUMP_SPECS = (StateSpec("omega_rad_s", "rad/s", "pump shaft speed", nonnegative=True),)
RES_SPECS = (
    StateSpec("M_kg", "kg", "liquid mass", nonnegative=True),
    StateSpec("n_OH_mol", "mol", "reservoir hydroxide", nonnegative=True),
    StateSpec("T_K", "K", "reservoir temperature"),
)
VALVE_SPECS = (StateSpec("pos", "1", "actuator position", nonnegative=True),)
PIPE_SPECS = (
    StateSpec("c_delay_mol_m3", "mol/m3", "advected KOH concentration", nonnegative=True),
    StateSpec("T_K", "K", "pipe wall/fluid temperature"),
)


def flow_rhs(t: float, y: NDArray[np.float64], u: Mapping[str, float], p: PlantParams) -> NDArray[np.float64]:
    """Circulation mass-flow and header-pressure RHS.

    @relation(IA-FLD-001, scope=function)
    """
    mdot, ph, T = y
    omega = float(u.get("omega_pump_rad_s", 80.0))
    pos = float(np.clip(u.get("valve_pos", 0.8), 0.0, 1.0))
    T_ely = float(u.get("T_ely_K", p.T_ep_sim_K))
    mu = koh_viscosity_pa_s(min(max(T, 274.0), 372.0), p.c_KOH_mol_m3)
    R_hyd = (8.0 * mu * 4.0) / (np.pi * 0.015**4) * (2.0 - pos)
    dp_pump = 12.0 * omega**2
    dmdot = (dp_pump - (ph - p.P_atm_Pa) - R_hyd * max(mdot, 0.0)) / 40.0
    dph = (mdot * 0.8 - 0.5 * (ph - p.P_atm_Pa) / 1e5) * 2e4
    dT = (T_ely - T) / 15.0
    _ = t
    return np.array([dmdot, dph, dT], dtype=np.float64)


class ElectrolyteFlow(RHSComponent):
    """IA-FLD-001 electrolyte circulation.

    @relation(IA-FLD-001, scope=class)
    """

    def __init__(self, p: PlantParams | None = None) -> None:
        p = p or default_params()
        y0 = np.array([0.05, p.P_atm_Pa + 2e4, p.T_ep_sim_K], dtype=np.float64)

        def rhs(t, y, inputs, context):  # type: ignore[no-untyped-def]
            return flow_rhs(t, y, inputs, p)

        def out(t, y, inputs, context):  # type: ignore[no-untyped-def]
            return {"mdot_kg_s": float(y[0]), "p_header_Pa": float(y[1]), "T_loop_K": float(y[2]), "t_s": t}

        super().__init__(
            name="ely_flow",
            requirement_ids=("IA-FLD-001",),
            specs=FLOW_SPECS,
            y0=y0,
            rhs_fn=rhs,
            out_fn=out,
            input_names=("omega_pump_rad_s", "valve_pos", "T_ely_K"),
            output_names=("mdot_kg_s", "p_header_Pa"),
            params=p,
        )


class Pump(RHSComponent):
    """IA-FLD-002 electrolyte pump.

    @relation(IA-FLD-002, scope=class)
    """

    def __init__(self, p: PlantParams | None = None) -> None:
        p = p or default_params()
        y0 = np.array([20.0], dtype=np.float64)

        def rhs(t, y, inputs, context):  # type: ignore[no-untyped-def]
            """Pump shaft-speed RHS.

            @relation(IA-FLD-002, scope=function)
            """
            omega = y[0]
            I = float(inputs.get("I_pump_A", 0.0))
            tau = 0.12 * I - 0.004 * omega
            return np.array([tau / 0.02], dtype=np.float64)

        def out(t, y, inputs, context):  # type: ignore[no-untyped-def]
            omega = float(y[0])
            I = float(inputs.get("I_pump_A", 0.0))
            P_el = 24.0 * I
            P_hyd = 0.65 * P_el
            return {"omega_rad_s": omega, "P_elec_W": P_el, "P_hyd_W": P_hyd, "eta": 0.65, "t_s": t}

        super().__init__(
            name="pump",
            requirement_ids=("IA-FLD-002",),
            specs=PUMP_SPECS,
            y0=y0,
            rhs_fn=rhs,
            out_fn=out,
            input_names=("I_pump_A",),
            output_names=("omega_rad_s", "P_elec_W", "P_hyd_W"),
            params=p,
        )


class Reservoir(RHSComponent):
    def __init__(self, p: PlantParams | None = None, filled: bool = True) -> None:
        p = p or default_params()
        dens = koh_density_kg_m3(p.T_ep_sim_K, p.c_KOH_mol_m3)
        M = dens * p.V_reservoir_m3 if filled else 1.0
        n_OH = p.c_KOH_mol_m3 * (M / dens)
        y0 = np.array([M, n_OH, p.T_ep_sim_K], dtype=np.float64)

        def rhs(t, y, inputs, context):  # type: ignore[no-untyped-def]
            M, n_OH, T = y
            m_in = float(inputs.get("mdot_in_kg_s", 0.0))
            m_out = float(inputs.get("mdot_out_kg_s", 0.0))
            leak = float(inputs.get("mdot_leak_kg_s", 0.0))
            c_in = float(inputs.get("c_OH_in_mol_m3", p.c_KOH_mol_m3))
            dens = koh_density_kg_m3(min(max(T, 274.0), 372.0), p.c_KOH_mol_m3)
            dM = m_in - m_out - leak
            dn = m_in * (c_in / dens) - (m_out + leak) * (n_OH / max(M, 1e-6))
            dT = (float(inputs.get("T_in_K", T)) - T) * max(m_in, 0.0) / max(M, 1.0)
            return np.array([dM, dn, dT], dtype=np.float64)

        def out(t, y, inputs, context):  # type: ignore[no-untyped-def]
            M, n_OH, T = y
            dens = koh_density_kg_m3(min(max(float(T), 274.0), 372.0), p.c_KOH_mol_m3)
            return {"M_kg": float(M), "V_m3": float(M / dens), "c_OH_mol_m3": float(n_OH / max(M / dens, 1e-12)), "T_K": float(T), "t_s": t}

        super().__init__(
            name="reservoir",
            requirement_ids=("IA-FLD-003",),
            specs=RES_SPECS,
            y0=y0,
            rhs_fn=rhs,
            out_fn=out,
            input_names=("mdot_in_kg_s", "mdot_out_kg_s", "mdot_leak_kg_s"),
            output_names=("M_kg", "V_m3", "c_OH_mol_m3"),
            params=p,
        )


class Valve(RHSComponent):
    def __init__(self, p: PlantParams | None = None) -> None:
        p = p or default_params()
        y0 = np.array([0.0], dtype=np.float64)

        def rhs(t, y, inputs, context):  # type: ignore[no-untyped-def]
            pos = y[0]
            cmd = float(np.clip(inputs.get("valve_cmd", 0.0), 0.0, 1.0))
            return np.array([(cmd - pos) / p.valve_tau_s], dtype=np.float64)

        def out(t, y, inputs, context):  # type: ignore[no-untyped-def]
            pos = float(np.clip(y[0], 0.0, 1.0))
            dP = float(inputs.get("dP_Pa", 2e4))
            Cv = 2e-8 * pos**1.5
            q = Cv * np.sign(dP) * np.sqrt(abs(dP))
            return {"pos": pos, "Q_m3_s": float(q), "t_s": t}

        super().__init__(
            name="valve",
            requirement_ids=("IA-FLD-004",),
            specs=VALVE_SPECS,
            y0=y0,
            rhs_fn=rhs,
            out_fn=out,
            input_names=("valve_cmd", "dP_Pa"),
            output_names=("pos", "Q_m3_s"),
            params=p,
        )


class Pipe(RHSComponent):
    def __init__(self, p: PlantParams | None = None) -> None:
        p = p or default_params()
        y0 = np.array([p.c_KOH_mol_m3, p.T_ep_sim_K], dtype=np.float64)

        def rhs(t, y, inputs, context):  # type: ignore[no-untyped-def]
            c, T = y
            c_in = float(inputs.get("c_in_mol_m3", p.c_KOH_mol_m3))
            T_in = float(inputs.get("T_in_K", p.T_ep_sim_K))
            tau = float(inputs.get("tau_s", 8.0))
            return np.array([(c_in - c) / tau, (T_in - T) / tau], dtype=np.float64)

        def out(t, y, inputs, context):  # type: ignore[no-untyped-def]
            return {"c_delay_mol_m3": float(y[0]), "T_K": float(y[1]), "t_s": t}

        super().__init__(
            name="pipe",
            requirement_ids=("IA-FLD-005",),
            specs=PIPE_SPECS,
            y0=y0,
            rhs_fn=rhs,
            out_fn=out,
            input_names=("c_in_mol_m3", "T_in_K", "tau_s"),
            output_names=("c_delay_mol_m3", "T_K"),
            params=p,
            # detailed transport delay exists; not reduced_order
        )
