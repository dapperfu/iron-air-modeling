"""Gas-diffusion layer ODE (IA-GDL-001).

Method-of-lines O2 diffusion, pore saturation, flooding, and dry-out.
Hydraulic head on vertical ORR can drive liquid migration; OER bubbles at a
horizontal electrode can dry the TPB (US12308414B2 FIGS. 8-9B).
pO2 window 0.01-100 atm discharge, 0.001-100 atm charge.
"""

from __future__ import annotations

from collections.abc import Mapping

import numpy as np
from numpy.typing import NDArray
from scipy import sparse
from scipy.sparse.linalg import spsolve

from plant_sim.bootstrap import setup_path
from plant_sim.components.base import RHSComponent
from plant_sim.params import PlantParams, default_params

setup_path()

from ironair.constants import constants  # noqa: E402
from ironair.ode.state import StateSpec  # noqa: E402
from ironair.properties import gas_phase_diffusivity_m2_s  # noqa: E402


def gdl_specs(n: int) -> tuple[StateSpec, ...]:
    nodes = tuple(
        StateSpec(f"c_O2_n{i}_mol_m3", "mol/m3", f"O2 concentration node {i}", nonnegative=True)
        for i in range(n)
    )
    extra = (
        StateSpec("saturation", "1", "liquid pore saturation", nonnegative=True),
        StateSpec("s_crust", "1", "salt-crust blockage", nonnegative=True),
    )
    return nodes + extra


def default_y0(p: PlantParams | None = None) -> NDArray[np.float64]:
    p = p or default_params()
    n = p.n_gdl_nodes
    c0 = (p.x_O2_air * p.P_atm_Pa) / (constants.R_J_MOL_K * p.T_ep_sim_K)
    return np.concatenate([np.full(n, c0), np.array([0.12, 0.0])])


def _Deff(T: float, P: float, eps: float, s: float, crust: float) -> float:
    Dgas = gas_phase_diffusivity_m2_s(T, P)
    gas_frac = max(eps * (1.0 - np.clip(s, 0.0, 1.0)) ** 3.0, 1e-8)
    return Dgas * gas_frac * (1.0 - 0.85 * np.clip(crust, 0.0, 1.0))


def gdl_rhs(
    t: float,
    y: NDArray[np.float64],
    u: Mapping[str, float],
    p: PlantParams,
) -> NDArray[np.float64]:
    n = p.n_gdl_nodes
    c = np.maximum(y[:n], 0.0)
    s = float(np.clip(y[n], 0.0, 1.0))
    crust = float(np.clip(y[n + 1], 0.0, 1.0))
    T = float(u.get("T_K", p.T_ep_sim_K))
    P = float(u.get("P_Pa", p.P_atm_Pa))
    x_O2 = float(u.get("x_O2", p.x_O2_air))
    r_orr = float(u.get("r_orr_mol_s", 0.0))
    head_m = float(u.get("hydraulic_head_m", 0.0))
    dryout = float(u.get("oer_dryout", 0.0))
    dz = p.L_gdl_m / max(n - 1, 1)
    Deff = _Deff(T, P, p.eps_gdl, s, crust)
    c_bc = x_O2 * P / (constants.R_J_MOL_K * T)
    dc = np.zeros(n)
    # Dirichlet air-side node 0
    dc[0] = (c_bc - c[0]) / 0.05
    for i in range(1, n - 1):
        dc[i] = Deff * (c[i + 1] - 2.0 * c[i] + c[i - 1]) / dz**2
    dc[n - 1] = Deff * (c[n - 2] - c[n - 1]) / dz**2 - r_orr / max(p.A_geom_m2 * dz, 1e-12)
    dc = np.where((c <= 1e-12) & (dc < 0.0), 0.0, dc)
    j_liquid = p.k_flood_m_s * head_m / max(p.L_gdl_m, 1e-6)
    j_drain = p.s_flood_drain_1_s * s + 0.4 * dryout * s
    ds = (j_liquid - j_drain) / max(p.eps_gdl, 0.05)
    if s >= 1.0 and ds > 0.0:
        ds = 0.0
    if s <= 0.0 and ds < 0.0:
        ds = 0.0
    dcrust = 1e-6 * float(u.get("r_carb_mol_s", 0.0)) * 1e3
    _ = t
    return np.concatenate([dc, np.array([ds, dcrust], dtype=np.float64)])


def gdl_outputs(
    t: float,
    y: NDArray[np.float64],
    u: Mapping[str, float],
    p: PlantParams,
) -> dict[str, float]:
    n = p.n_gdl_nodes
    c = y[:n]
    s = float(np.clip(y[n], 0.0, 1.0))
    crust = float(y[n + 1])
    T = float(u.get("T_K", p.T_ep_sim_K))
    P = float(u.get("P_Pa", p.P_atm_Pa))
    Deff = _Deff(T, P, p.eps_gdl, s, crust)
    flooded = 1.0 if s > 0.85 else 0.0
    return {
        "c_O2_air_mol_m3": float(c[0]),
        "c_O2_tpb_mol_m3": float(c[-1]),
        "saturation": s,
        "crust": crust,
        "Deff_m2_s": Deff,
        "flooded": flooded,
        "t_s": t,
    }


def diffusion_matrix(n: int, Deff: float, dz: float) -> Any:
    diag = np.full(n, -2.0 * Deff / dz**2)
    off = np.full(n - 1, Deff / dz**2)
    return sparse.diags([off, diag, off], offsets=[-1, 0, 1], format="csc")


class GasDiffusionLayer(RHSComponent):
    def __init__(self, p: PlantParams | None = None, y0: NDArray[np.float64] | None = None) -> None:
        p = p or default_params()
        y0 = default_y0(p) if y0 is None else y0

        def rhs(t, y, inputs, context):  # type: ignore[no-untyped-def]
            return gdl_rhs(t, y, inputs, p)

        def out(t, y, inputs, context):  # type: ignore[no-untyped-def]
            return gdl_outputs(t, y, inputs, p)

        super().__init__(
            name="gdl",
            requirement_ids=("IA-GDL-001", "IA-SYS-014"),
            specs=gdl_specs(p.n_gdl_nodes),
            y0=y0,
            rhs_fn=rhs,
            out_fn=out,
            input_names=("T_K", "P_Pa", "x_O2", "r_orr_mol_s", "hydraulic_head_m", "oer_dryout"),
            output_names=("c_O2_tpb_mol_m3", "saturation", "Deff_m2_s", "flooded"),
            params=p,
        )
        self._laplace = diffusion_matrix(p.n_gdl_nodes, 1.0, p.L_gdl_m / max(p.n_gdl_nodes - 1, 1))

    def steady_profile(self, Deff: float, c_bc: float, sink: NDArray[np.float64]) -> NDArray[np.float64]:
        n = self.plant_params.n_gdl_nodes
        dz = self.plant_params.L_gdl_m / max(n - 1, 1)
        A = diffusion_matrix(n, Deff, dz).tolil()
        A[0, :] = 0.0
        A[0, 0] = 1.0
        b = -sink
        b[0] = c_bc
        return np.asarray(spsolve(A.tocsc(), b), dtype=float)
