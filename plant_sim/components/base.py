"""Shared ODE helpers: BV inversion, integration, DynamicComponent adapter."""

from __future__ import annotations

from collections.abc import Callable, Mapping
from typing import Any

import numpy as np
from numpy.typing import NDArray
from scipy.integrate import solve_ivp
from scipy.optimize import brentq

from plant_sim.bootstrap import setup_path
from plant_sim.params import PlantParams, default_params

setup_path()

from ironair.chemistry.kinetics import butler_volmer_current_density_a_m2  # noqa: E402
from ironair.constants import constants  # noqa: E402
from ironair.ode.component import DynamicComponent  # noqa: E402
from ironair.ode.state import StateSpec  # noqa: E402
from ironair.parameters import ParameterSet  # noqa: E402
from ironair.properties import arrhenius_rate  # noqa: E402

F = constants.F_C_MOL
R = constants.R_J_MOL_K
EXP_MAX = 40.0


def clip_exp(x: float) -> float:
    return float(np.exp(np.clip(x, -EXP_MAX, EXP_MAX)))


def asinh_overpotential_V(
    i_A_m2: float,
    i0_A_m2: float,
    temperature_K: float,
    alpha: float = 0.5,
) -> float:
    """Symmetric BV inverse: eta = (RT / (alpha F)) asinh(i / (2 i0))."""
    i0 = max(i0_A_m2, 1e-18)
    arg = 0.5 * i_A_m2 / i0
    return (R * temperature_K / (alpha * F)) * float(np.arcsinh(arg))


def invert_butler_volmer_eta_V(
    i_target_A_m2: float,
    i0_A_m2: float,
    alpha_a: float,
    alpha_c: float,
    temperature_K: float,
    activity_ox: float = 1.0,
    activity_red: float = 1.0,
    availability: float = 1.0,
) -> float:
    """Solve BV for overpotential given a target current density."""
    if abs(i_target_A_m2) < 1e-18 or i0_A_m2 <= 0.0 or availability <= 0.0:
        return 0.0
    guess = asinh_overpotential_V(i_target_A_m2, i0_A_m2 * availability, temperature_K, 0.5)

    def residual(eta: float) -> float:
        i = butler_volmer_current_density_a_m2(
            eta,
            i0_A_m2,
            alpha_a,
            alpha_c,
            temperature_K,
            activity_ox=activity_ox,
            activity_red=activity_red,
            availability=availability,
        )
        return i - i_target_A_m2

    lo, hi = guess - 1.5, guess + 1.5
    r_lo, r_hi = residual(lo), residual(hi)
    tries = 0
    while r_lo * r_hi > 0.0 and tries < 8:
        lo -= 0.8
        hi += 0.8
        r_lo, r_hi = residual(lo), residual(hi)
        tries += 1
    if r_lo * r_hi > 0.0:
        return guess
    return float(brentq(residual, lo, hi, xtol=1e-10, maxiter=80))


def i0_T(i0_ref: float, Ea: float, T: float) -> float:
    return arrhenius_rate(i0_ref, Ea, T)


def integrate_component(
    rhs: Callable[[float, NDArray[np.float64]], NDArray[np.float64]],
    y0: NDArray[np.float64],
    t_span: tuple[float, float],
    n_eval: int = 250,
    method: str = "BDF",
    rtol: float = 1e-6,
    atol: float | NDArray[np.float64] = 1e-8,
) -> tuple[NDArray[np.float64], NDArray[np.float64]]:
    t_eval = np.linspace(t_span[0], t_span[1], n_eval)
    sol = solve_ivp(rhs, t_span, np.asarray(y0, dtype=float), method=method, t_eval=t_eval, rtol=rtol, atol=atol, dense_output=False)
    if not sol.success:
        raise RuntimeError(sol.message)
    y = np.asarray(sol.y, dtype=float)
    if not np.all(np.isfinite(y)):
        raise RuntimeError("non-finite trajectory")
    return np.asarray(sol.t, dtype=float), y


class RHSComponent(DynamicComponent):
    """DynamicComponent that delegates to a numpy rhs closure."""

    def __init__(
        self,
        name: str,
        requirement_ids: tuple[str, ...],
        specs: tuple[StateSpec, ...],
        y0: NDArray[np.float64],
        rhs_fn: Callable[[float, NDArray[np.float64], Mapping[str, float], Mapping[str, Any]], NDArray[np.float64]],
        out_fn: Callable[[float, NDArray[np.float64], Mapping[str, float], Mapping[str, Any]], dict[str, float]],
        parameters: ParameterSet | None = None,
        input_names: tuple[str, ...] = (),
        output_names: tuple[str, ...] = (),
        params: PlantParams | None = None,
    ) -> None:
        super().__init__(
            name=name,
            requirement_ids=requirement_ids,
            _specs=specs,
            _parameters=parameters or ParameterSet({}),
            _y0=np.asarray(y0, dtype=np.float64),
            _input_names=input_names,
            _output_names=output_names,
        )
        self._rhs_fn = rhs_fn
        self._out_fn = out_fn
        self.plant_params = params or default_params()

    def rhs(
        self,
        t: float,
        y: NDArray[np.float64],
        inputs: Mapping[str, float],
        context: Mapping[str, Any],
    ) -> NDArray[np.float64]:
        y_clip = np.array(y, dtype=np.float64, copy=True)
        for i, spec in enumerate(self._specs):
            if spec.nonnegative and y_clip[i] < 0.0:
                y_clip[i] = 0.0
        return super().rhs(t, y_clip, inputs, context)

    def _rhs(
        self,
        t: float,
        y: NDArray[np.float64],
        inputs: Mapping[str, float],
        context: Mapping[str, Any],
    ) -> NDArray[np.float64]:
        return self._rhs_fn(t, y, inputs, context)

    def _outputs(
        self,
        t: float,
        y: NDArray[np.float64],
        inputs: Mapping[str, float],
        context: Mapping[str, Any],
    ) -> dict[str, float]:
        return self._out_fn(t, y, inputs, context)
