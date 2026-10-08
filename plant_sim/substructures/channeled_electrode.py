"""21 Channeled / interdigitated / spiral bifilar / pleated electrode (EP4602674A1)."""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np
from numpy.typing import NDArray

from plant_sim.components.her import her_current_split_A
from plant_sim.components.oer import LAYOUT_AREA_FACTOR, OER_LAYOUTS
from plant_sim.params import PlantParams, default_params
from plant_sim.substructures.negative_electrode import NegativeElectrode


def assert_channel_window(length_m: float, width_m: float, spacing_m: float, p: PlantParams) -> None:
    if not (p.channel_length_min_m <= length_m <= p.channel_length_max_m):
        raise ValueError(f"channel length {length_m} m outside 3-50 mm")
    if not (p.channel_width_min_m <= width_m <= p.channel_width_max_m):
        raise ValueError(f"channel width {width_m} m outside 1-40 mm")
    if not (p.channel_spacing_min_m <= spacing_m <= p.channel_spacing_max_m):
        raise ValueError(f"channel spacing {spacing_m} m outside 10-50 mm")


def ionic_path_length_m(layout: str, p: PlantParams) -> float:
    if layout in {"interdigitated", "spiral_bifilar", "pleated"}:
        return 0.5 * p.channel_spacing_m
    if layout == "channeled":
        return 0.5 * p.channel_width_m + 0.25 * p.L_anode_m
    return p.L_anode_m


@dataclass
class ChanneledElectrode:
    params: PlantParams | None = None
    layout: str = "interdigitated"

    def __post_init__(self) -> None:
        self.params = self.params or default_params()
        assert_channel_window(self.params.channel_length_m, self.params.channel_width_m, self.params.channel_spacing_m, self.params)
        if not (self.params.loading_min_g_cm2 <= self.params.loading_g_cm2 <= self.params.loading_max_g_cm2):
            raise ValueError("Fe loading outside 1-7 g/cm2")
        if not (self.params.vf_min <= self.params.vf_electrolyte_charged <= self.params.vf_max):
            raise ValueError("electrolyte VF outside 0.5-0.9")
        self.neg = NegativeElectrode(self.params)

    def compare_layouts(self, I_charge_A: float) -> dict[str, float]:
        p = self.params
        out: dict[str, float] = {}
        for layout in ("planar", "channeled", *OER_LAYOUTS):
            L = ionic_path_length_m(layout if layout != "channeled" else "channeled", p)
            _Iher, _Ife, ce = her_current_split_A(-abs(I_charge_A), L, p.T_ep_sim_K, p, 0.05)
            af = LAYOUT_AREA_FACTOR.get(layout, 1.0)
            out[f"CE_{layout}"] = ce
            out[f"area_{layout}"] = af
            out[f"L_{layout}_m"] = L
        return out

    def rhs(self, t: float, y: NDArray[np.float64], u=None):  # type: ignore[no-untyped-def]
        return self.neg.rhs(t, y, u)

    def y0(self) -> NDArray[np.float64]:
        return self.neg.y0()

    def simulate(self, t_span: tuple[float, float], **kwargs):  # type: ignore[no-untyped-def]
        return self.neg.simulate(t_span, **kwargs)
