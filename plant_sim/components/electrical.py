"""Electrical BOP: DC bus, converter, inverter, transformer, grid (IA-DC/CNV/INV/TRF/GRD).

@relation(IA-DC-001, scope=module)
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

DC_SPECS = (StateSpec("V_dc_V", "V", "DC-link voltage", nonnegative=True),)
CNV_SPECS = (
    StateSpec("i_L_A", "A", "averaged inductor current"),
    StateSpec("v_C_V", "V", "converter capacitor voltage", nonnegative=True),
)
INV_SPECS = (
    StateSpec("P_W", "W", "active power tracker"),
    StateSpec("Q_var", "var", "reactive power tracker"),
)
TRF_SPECS = (
    StateSpec("flux_Wb", "Wb", "magnetizing flux"),
    StateSpec("T_winding_K", "K", "winding temperature"),
)


class DCBus(RHSComponent):
    """IA-DC-001 DC-link capacitor.

    @relation(IA-DC-001, scope=class)
    """

    def __init__(self, p: PlantParams | None = None) -> None:
        p = p or default_params()
        y0 = np.array([48.0 * p.n_cells_series / 12.0 * 12.0], dtype=np.float64)
        y0 = np.array([float(p.n_cells_series) * 1.2], dtype=np.float64)

        def rhs(t, y, inputs, context):  # type: ignore[no-untyped-def]
            """DC-link capacitor energy RHS.

            @relation(IA-DC-001, scope=function)
            """
            V = max(float(y[0]), 1.0)
            P_net = float(inputs.get("P_net_W", 0.0))
            return np.array([P_net / (p.C_dc_F * V)], dtype=np.float64)

        def out(t, y, inputs, context):  # type: ignore[no-untyped-def]
            V = float(y[0])
            return {"V_dc_V": V, "E_J": 0.5 * p.C_dc_F * V * V, "t_s": t}

        super().__init__(
            name="dc_bus",
            requirement_ids=("IA-DC-001",),
            specs=DC_SPECS,
            y0=y0,
            rhs_fn=rhs,
            out_fn=out,
            input_names=("P_net_W",),
            output_names=("V_dc_V", "E_J"),
            params=p,
        )


class DCDCConverter(RHSComponent):
    def __init__(self, p: PlantParams | None = None) -> None:
        p = p or default_params()
        y0 = np.array([0.0, 48.0], dtype=np.float64)

        def rhs(t, y, inputs, context):  # type: ignore[no-untyped-def]
            iL, vC = y
            v_in = float(inputs.get("v_in_V", 48.0))
            duty = float(np.clip(inputs.get("duty", 0.5), 0.05, 0.95))
            L = 1e-3
            C = 2e-3
            Rload = float(inputs.get("R_load_ohm", 10.0))
            di = (v_in * duty - vC) / L - 0.05 * iL
            dv = (iL - vC / max(Rload, 0.1)) / C
            return np.array([di, dv], dtype=np.float64)

        def out(t, y, inputs, context):  # type: ignore[no-untyped-def]
            iL, vC = y
            loss = 0.04 * abs(iL * vC)
            return {"i_L_A": float(iL), "v_C_V": float(vC), "P_loss_W": loss, "t_s": t}

        super().__init__(
            name="dcdc",
            requirement_ids=("IA-CNV-001",),
            specs=CNV_SPECS,
            y0=y0,
            rhs_fn=rhs,
            out_fn=out,
            input_names=("v_in_V", "duty", "R_load_ohm"),
            output_names=("i_L_A", "v_C_V", "P_loss_W"),
            params=p,
        )


class GridInverter(RHSComponent):
    def __init__(self, p: PlantParams | None = None) -> None:
        p = p or default_params()
        y0 = np.array([0.0, 0.0], dtype=np.float64)

        def rhs(t, y, inputs, context):  # type: ignore[no-untyped-def]
            P, Q = y
            Pref = float(inputs.get("P_ref_W", 0.0))
            Qref = float(inputs.get("Q_ref_var", 0.0))
            tau = 0.4
            return np.array([(Pref - P) / tau, (Qref - Q) / tau], dtype=np.float64)

        def out(t, y, inputs, context):  # type: ignore[no-untyped-def]
            P, Q = y
            return {"P_ac_W": float(P), "Q_var": float(Q), "P_dc_W": float(P) / p.inverter_eta if P >= 0 else float(P) * p.inverter_eta, "t_s": t}

        super().__init__(
            name="inverter",
            requirement_ids=("IA-INV-001",),
            specs=INV_SPECS,
            y0=y0,
            rhs_fn=rhs,
            out_fn=out,
            input_names=("P_ref_W", "Q_ref_var"),
            output_names=("P_ac_W", "Q_var", "P_dc_W"),
            params=p,
        )


class Transformer(RHSComponent):
    def __init__(self, p: PlantParams | None = None) -> None:
        p = p or default_params()
        y0 = np.array([0.0, p.T_ref_K], dtype=np.float64)

        def rhs(t, y, inputs, context):  # type: ignore[no-untyped-def]
            flux, Tw = y
            v = float(inputs.get("v_grid_V", p.grid_V_rms))
            f = float(inputs.get("f_Hz", p.grid_f_Hz))
            # flux tracks V/(2 pi f N) with N=1 equivalent
            flux_ref = v / max(2.0 * np.pi * f, 1.0)
            dflux = (flux_ref - flux) / 0.05
            I = float(inputs.get("I_rms_A", 0.0))
            dT = (3.0 * I**2 * 0.02 + 0.5 * (p.T_ref_K - Tw)) / 800.0
            return np.array([dflux, dT], dtype=np.float64)

        def out(t, y, inputs, context):  # type: ignore[no-untyped-def]
            return {"flux_Wb": float(y[0]), "T_winding_K": float(y[1]), "t_s": t}

        super().__init__(
            name="transformer",
            requirement_ids=("IA-TRF-001",),
            specs=TRF_SPECS,
            y0=y0,
            rhs_fn=rhs,
            out_fn=out,
            input_names=("v_grid_V", "f_Hz", "I_rms_A"),
            output_names=("flux_Wb", "T_winding_K"),
            params=p,
        )


class GridInterface(RHSComponent):
    """Prescribed grid voltage/frequency are inputs, not invented states (IA-GRD-001)."""

    def __init__(self, p: PlantParams | None = None) -> None:
        p = p or default_params()
        y0 = np.array([0.0], dtype=np.float64)
        specs = (StateSpec("P_exch_W", "W", "filtered grid exchange power"),)

        def rhs(t, y, inputs, context):  # type: ignore[no-untyped-def]
            Pref = float(inputs.get("P_grid_W", 0.0))
            return np.array([(Pref - y[0]) / 0.25], dtype=np.float64)

        def out(t, y, inputs, context):  # type: ignore[no-untyped-def]
            v = float(inputs.get("v_grid_V", p.grid_V_rms))
            f = float(inputs.get("f_Hz", p.grid_f_Hz))
            return {"P_grid_W": float(y[0]), "v_grid_V": v, "f_Hz": f, "t_s": t}

        super().__init__(
            name="grid",
            requirement_ids=("IA-GRD-001", "IA-SYS-007"),
            specs=specs,
            y0=y0,
            rhs_fn=rhs,
            out_fn=out,
            input_names=("P_grid_W", "v_grid_V", "f_Hz"),
            output_names=("P_grid_W", "v_grid_V", "f_Hz"),
            params=p,
        )
