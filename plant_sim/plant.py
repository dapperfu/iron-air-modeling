"""Full coupled iron-air plant: one solve_ivp over concatenated component states.

@relation(IA-CTL-001, scope=module)

Charge closes iron to OER to the power source; discharge closes iron to ORR to
the load (EP4602674A1 [0049]). Dual-electrode isolation follows US Claim 16.
"""

from __future__ import annotations

from collections.abc import Callable, Mapping
from dataclasses import dataclass, field
from typing import Any

import numpy as np
from numpy.typing import NDArray
from scipy.integrate import solve_ivp

from plant_sim.bootstrap import setup_path
from plant_sim.components import air_system as air_mod
from plant_sim.components import current_collector as col_mod
from plant_sim.components import degradation as deg_mod
from plant_sim.components import electrical as el_mod
from plant_sim.components import electrolyte as ely_mod
from plant_sim.components import gdl as gdl_mod
from plant_sim.components import her as her_mod
from plant_sim.components import hydraulics as hyd_mod
from plant_sim.components import iron_anode as fe_mod
from plant_sim.components import oer as oer_mod
from plant_sim.components import orr as orr_mod
from plant_sim.components import separator as sep_mod
from plant_sim.components import thermal as th_mod
from plant_sim.components.base import asinh_overpotential_V, i0_T
from plant_sim.params import PlantParams, default_params

setup_path()

from ironair.chemistry.network import faraday_rate_mol_s  # noqa: E402
from ironair.chemistry.nernst import nernst_iron_v, nernst_oxygen_v  # noqa: E402
from ironair.constants import constants  # noqa: E402
from ironair.chemistry.thermodynamics import irreversible_heat_w  # noqa: E402

MODE_REST = 0.0
MODE_CHARGE = 1.0
MODE_DISCHARGE = -1.0
MODE_COMMISSION = 2.0


def _blocks(p: PlantParams) -> dict[str, tuple[int, int]]:
    n_gdl = p.n_gdl_nodes + 2
    sizes = [
        ("fe", 8),
        ("her", 3),
        ("orr", 3),
        ("oer", 3),
        ("gdl", n_gdl),
        ("ely", 7),
        ("sep", 4),
        ("col_fe", 2),
        ("col_air", 2),
        ("th", 5),
        ("air", 5),
        ("fan", 1),
        ("flow", 3),
        ("pump", 1),
        ("res", 3),
        ("valve", 1),
        ("pipe", 2),
        ("hex", 2),
        ("dc", 1),
        ("inv", 2),
        ("grid", 1),
        ("deg", 4),
    ]
    out: dict[str, tuple[int, int]] = {}
    i = 0
    for name, n in sizes:
        out[name] = (i, i + n)
        i += n
    return out


@dataclass
class PlantModel:
    """Assembled plant. Isolated component RHS functions are the same Python objects.

    @relation(IA-CTL-001, scope=class)
    """

    params: PlantParams = field(default_factory=default_params)
    orr_mode: str = "stacked_submerged"
    oer_layout: str = "interdigitated"

    def __post_init__(self) -> None:
        self.blocks = _blocks(self.params)
        self.n_states = max(b[1] for b in self.blocks.values())
        self.state_names = self._names()

    def _names(self) -> tuple[str, ...]:
        p = self.params
        names = [
            "fe.n_Fe_mol",
            "fe.n_FeOH2_mol",
            "fe.n_Fe3O4_mol",
            "fe.T_K",
            "fe.delta_pass_m",
            "fe.porosity",
            "fe.a_rel",
            "fe.n_lost_mol",
            "her.n_H2_mol",
            "her.theta_bubble",
            "her.p_H2_Pa",
            "orr.q_dl_C",
            "orr.c_O2_tpb_mol_m3",
            "orr.util_O2",
            "oer.theta_cat",
            "oer.n_O2_mol",
            "oer.theta_bubble",
        ]
        names += [f"gdl.c_O2_n{i}_mol_m3" for i in range(p.n_gdl_nodes)]
        names += ["gdl.saturation", "gdl.s_crust"]
        names += [
            "ely.n_OH_mol",
            "ely.n_H2O_mol",
            "ely.n_CO3_mol",
            "ely.n_CO2_aq_mol",
            "ely.T_K",
            "ely.V_m3",
            "ely.s_wet",
            "sep.T_K",
            "sep.saturation",
            "sep.c_O2_mol_m3",
            "sep.deg",
            "col_fe.T_K",
            "col_fe.deg",
            "col_air.T_K",
            "col_air.deg",
            "th.T_electrode_K",
            "th.T_electrolyte_K",
            "th.T_vessel_K",
            "th.T_lid_K",
            "th.T_coolant_K",
            "air.p_man_Pa",
            "air.n_O2_mol",
            "air.n_N2_mol",
            "air.n_H2O_vap_mol",
            "air.n_CO2_mol",
            "fan.omega_rad_s",
            "flow.mdot_kg_s",
            "flow.p_header_Pa",
            "flow.T_loop_K",
            "pump.omega_rad_s",
            "res.M_kg",
            "res.n_OH_mol",
            "res.T_K",
            "valve.pos",
            "pipe.c_delay_mol_m3",
            "pipe.T_K",
            "hex.T_hot_K",
            "hex.T_cold_K",
            "dc.V_dc_V",
            "inv.P_W",
            "inv.Q_var",
            "grid.P_exch_W",
            "deg.Q_lost_C",
            "deg.R_growth",
            "deg.k_orr_decay",
            "deg.ptfe_loss",
        ]
        return tuple(names)

    def y0(self, filled: bool = True) -> NDArray[np.float64]:
        p = self.params
        y = np.zeros(self.n_states)
        b = self.blocks
        y[b["fe"][0] : b["fe"][1]] = fe_mod.default_y0(p)
        y[b["her"][0] : b["her"][1]] = her_mod.default_y0(p)
        y[b["orr"][0] : b["orr"][1]] = orr_mod.default_y0(p)
        y[b["oer"][0] : b["oer"][1]] = oer_mod.default_y0(p)
        y[b["gdl"][0] : b["gdl"][1]] = gdl_mod.default_y0(p)
        y[b["ely"][0] : b["ely"][1]] = ely_mod.default_y0(p, filled=filled)
        y[b["sep"][0] : b["sep"][1]] = sep_mod.default_y0(p)
        y[b["col_fe"][0] : b["col_fe"][1]] = col_mod.default_y0(p)
        y[b["col_air"][0] : b["col_air"][1]] = col_mod.default_y0(p)
        y[b["th"][0] : b["th"][1]] = th_mod.default_y0(p)
        y[b["air"][0] : b["air"][1]] = air_mod.air_y0(p)
        y[b["fan"][0] : b["fan"][1]] = np.array([30.0])
        y[b["flow"][0] : b["flow"][1]] = np.array([0.02, p.P_atm_Pa + 1e4, p.T_ep_sim_K])
        y[b["pump"][0] : b["pump"][1]] = np.array([40.0])
        dens = 1270.0
        M = dens * p.V_reservoir_m3 if filled else 2.0
        y[b["res"][0] : b["res"][1]] = np.array([M, p.c_KOH_mol_m3 * (M / dens), p.T_ep_sim_K])
        y[b["valve"][0] : b["valve"][1]] = np.array([0.7 if filled else 0.0])
        y[b["pipe"][0] : b["pipe"][1]] = np.array([p.c_KOH_mol_m3, p.T_ep_sim_K])
        y[b["hex"][0] : b["hex"][1]] = np.array([p.T_ep_sim_K + 2.0, p.T_ref_K])
        y[b["dc"][0] : b["dc"][1]] = np.array([float(p.n_cells_series) * 1.15])
        y[b["inv"][0] : b["inv"][1]] = np.array([0.0, 0.0])
        y[b["grid"][0] : b["grid"][1]] = np.array([0.0])
        y[b["deg"][0] : b["deg"][1]] = deg_mod.default_y0()
        return y

    def slice(self, y: NDArray[np.float64], name: str) -> NDArray[np.float64]:
        a, b = self.blocks[name]
        return y[a:b]

    def algebraic(self, t: float, y: NDArray[np.float64], u: Mapping[str, float]) -> dict[str, float]:
        """Map discrete charge/discharge/rest/commission modes onto electrode currents.

        @relation(IA-CTL-001, scope=function)
        """
        p = self.params
        fe = self.slice(y, "fe")
        ely = self.slice(y, "ely")
        air = self.slice(y, "air")
        gdl = self.slice(y, "gdl")
        oer = self.slice(y, "oer")
        her = self.slice(y, "her")
        deg = self.slice(y, "deg")
        T = float(fe[3])
        Vely = max(float(ely[5]), 1e-8)
        a_oh = max(float(ely[0]) / Vely / 1000.0, 1e-6)
        a_h2o = 0.72
        n_air = max(float(air[1] + air[2] + air[3] + air[4]), 1e-12)
        x_O2 = float(air[1]) / n_air
        p_O2 = x_O2 * float(air[0])
        E_fe = nernst_iron_v(T, a_oh)
        E_ox = nernst_oxygen_v(T, max(p_O2, 1.0), a_oh, a_h2o)
        mode = float(u.get("mode", MODE_REST))
        P_grid = float(u.get("P_grid_W", 0.0))
        n_series = p.n_cells_series
        n_par = p.n_cells_parallel * p.n_stacks
        V_est = max(float(self.slice(y, "dc")[0]), 1.0)
        I_stack = P_grid / max(V_est, 1.0) / max(n_par, 1)
        # sign: discharge positive anodic on iron
        if mode == MODE_DISCHARGE or (mode == MODE_REST and P_grid < 0.0):
            I_cell = abs(I_stack) if mode == MODE_DISCHARGE else 0.0
            if P_grid < 0.0:
                I_cell = abs(P_grid) / max(V_est, 1.0) / max(n_par, 1)
        elif mode in (MODE_CHARGE, MODE_COMMISSION):
            I_cell = -abs(I_stack)
        else:
            I_cell = 0.0
        I_cmd = float(u.get("I_cell_A", I_cell))
        wet = float(np.clip(ely[6], 0.02, 1.0))
        I_cmd *= wet
        L_path = p.L_anode_m * (1.0 - 0.6 * p.chan_frac)
        I_her, I_fe_red, ce = her_mod.her_current_split_A(I_cmd, L_path, T, p, float(her[1]))
        if I_cmd >= 0.0:
            I_fe = I_cmd
            I_orr = -I_cmd
            I_oer = 0.0
            isolated = 1.0
        else:
            I_fe = -I_fe_red
            I_oer = -I_cmd
            I_orr = 0.0
            isolated = float(u.get("oer_isolated", 0.0))
        i0f = i0_T(p.i0_fe_A_m2, p.Ea_fe_J_mol, T)
        eta_fe = asinh_overpotential_V(I_fe / max(p.A_geom_m2, 1e-8), i0f, T)
        eta_orr = asinh_overpotential_V(I_orr / max(p.A_geom_m2, 1e-8), i0_T(p.i0_orr_A_m2, p.Ea_orr_J_mol, T), T)
        eta_oer = asinh_overpotential_V(I_oer / max(p.A_geom_m2, 1e-8), i0_T(p.i0_oer_A_m2, p.Ea_oer_J_mol, T), T)
        Rsep = sep_mod.ionic_resistance_ohm(T, float(ely[0]) / Vely, float(self.slice(y, "sep")[1]), float(self.slice(y, "sep")[3]), p)
        Rcol = col_mod.collector_resistance_ohm(T, float(self.slice(y, "col_fe")[1]), p)
        Rcol += col_mod.collector_resistance_ohm(T, float(self.slice(y, "col_air")[1]), p)
        Rcol *= 1.0 + float(deg[1])
        if I_cmd >= 0.0:
            V_cell = E_ox + eta_orr - (E_fe + eta_fe) - I_cmd * (Rsep + Rcol)
        else:
            V_cell = (E_ox + eta_oer) - (E_fe + eta_fe) - I_cmd * (Rsep + Rcol)
        soc = float(np.clip(fe[0] / max(p.n_Fe0_mol, 1e-12), 0.0, 1.0))
        r_iron = faraday_rate_mol_s(I_fe, 2.0)
        r_orr = abs(min(I_orr, 0.0)) / (4.0 * constants.F_C_MOL)
        r_oer = max(I_oer, 0.0) / (4.0 * constants.F_C_MOL)
        r_her = I_her / (2.0 * constants.F_C_MOL)
        q_irrev = irreversible_heat_w(eta_fe, I_fe) + irreversible_heat_w(eta_orr, I_orr) + irreversible_heat_w(eta_oer, I_oer)
        return {
            "mode": mode,
            "I_cell_A": I_cmd,
            "I_fe_A": I_fe,
            "I_orr_A": I_orr,
            "I_oer_A": I_oer,
            "I_her_A": I_her,
            "CE": ce if I_cmd < 0.0 else 1.0,
            "V_cell_V": V_cell,
            "V_module_V": V_cell * n_series,
            "P_grid_W": P_grid,
            "SOC": soc,
            "a_oh": a_oh,
            "a_h2o": a_h2o,
            "p_O2_Pa": p_O2,
            "x_O2": x_O2,
            "x_CO2": float(air[4]) / n_air,
            "T_K": T,
            "r_iron_mol_s": r_iron,
            "r_orr_mol_s": r_orr,
            "r_oer_mol_s": r_oer,
            "r_her_mol_s": r_her,
            "q_irrev_W": q_irrev,
            "R_ionic_ohm": Rsep,
            "eta_fe_V": eta_fe,
            "eta_orr_V": eta_orr,
            "eta_oer_V": eta_oer,
            "oer_isolated": isolated,
            "s_gdl": float(gdl[-2]),
            "n_H2_mol": float(her[0]),
            "n_O2_oer_mol": float(oer[1]),
            "wet": wet,
            "t_s": t,
        }

    def rhs(self, t: float, y: NDArray[np.float64], u: Mapping[str, float] | None = None) -> NDArray[np.float64]:
        p = self.params
        u = u or {}
        alg = self.algebraic(t, y, u)
        b = self.blocks
        dy = np.zeros_like(y)
        a_oh = alg["a_oh"]
        T = alg["T_K"]
        u_fe = {"I_fe_A": alg["I_fe_A"], "T_amb_K": float(u.get("T_amb_K", p.T_ref_K)), "a_oh": a_oh, "a_h2o": alg["a_h2o"]}
        dy[b["fe"][0] : b["fe"][1]] = fe_mod.iron_anode_rhs(t, self.slice(y, "fe"), u_fe, p)
        u_her = {"I_fe_A": alg["I_fe_A"], "T_K": T, "L_path_m": p.L_anode_m * (1.0 - 0.6 * p.chan_frac), "a_oh": a_oh, "a_h2o": alg["a_h2o"]}
        dy[b["her"][0] : b["her"][1]] = her_mod.her_rhs(t, self.slice(y, "her"), u_her, p)
        c_gdl_tpb = float(self.slice(y, "gdl")[p.n_gdl_nodes - 1])
        u_orr = {"I_orr_A": alg["I_orr_A"], "T_K": T, "c_O2_gdl_mol_m3": c_gdl_tpb, "p_O2_Pa": alg["p_O2_Pa"], "a_oh": a_oh, "a_h2o": alg["a_h2o"]}
        dy[b["orr"][0] : b["orr"][1]] = orr_mod.orr_rhs(t, self.slice(y, "orr"), u_orr, p)
        u_oer = {"I_oer_A": alg["I_oer_A"], "T_K": T, "a_oh": a_oh, "a_h2o": alg["a_h2o"], "p_O2_Pa": alg["p_O2_Pa"], "oer_isolated": alg["oer_isolated"]}
        dy[b["oer"][0] : b["oer"][1]] = oer_mod.oer_rhs(t, self.slice(y, "oer"), u_oer, p, self.oer_layout)
        omega_fan = float(self.slice(y, "fan")[0])
        mdot_air = 1.2e-5 * omega_fan + float(u.get("mdot_air_kg_s", 0.0))
        u_gdl = {
            "T_K": T,
            "P_Pa": float(self.slice(y, "air")[0]),
            "x_O2": alg["x_O2"],
            "r_orr_mol_s": alg["r_orr_mol_s"],
            "hydraulic_head_m": float(u.get("hydraulic_head_m", 0.15)),
            "oer_dryout": 0.2 if alg["I_oer_A"] > 0 else 0.0,
            "r_carb_mol_s": max(float(self.slice(y, "ely")[3]), 0.0) * 1e-4,
        }
        dy[b["gdl"][0] : b["gdl"][1]] = gdl_mod.gdl_rhs(t, self.slice(y, "gdl"), u_gdl, p)
        u_ely = {
            "r_iron_mol_s": alg["r_iron_mol_s"],
            "r_mag_mol_s": 0.05 * alg["r_iron_mol_s"] if alg["I_fe_A"] > 0 else 0.0,
            "r_orr_mol_s": alg["r_orr_mol_s"],
            "r_oer_mol_s": alg["r_oer_mol_s"],
            "r_her_mol_s": alg["r_her_mol_s"],
            "fill_m3_s": float(u.get("fill_m3_s", 0.0)),
            "T_amb_K": float(u.get("T_amb_K", p.T_ref_K)),
            "x_CO2": alg["x_CO2"],
            "P_Pa": float(self.slice(y, "air")[0]),
            "q_heat_W": alg["q_irrev_W"],
        }
        dy[b["ely"][0] : b["ely"][1]] = ely_mod.electrolyte_rhs(t, self.slice(y, "ely"), u_ely, p)
        u_sep = {
            "T_ely_K": float(self.slice(y, "ely")[4]),
            "c_KOH_mol_m3": float(self.slice(y, "ely")[0]) / max(float(self.slice(y, "ely")[5]), 1e-8),
            "I_cell_A": alg["I_cell_A"],
            "s_wet": float(self.slice(y, "ely")[6]),
            "c_O2_ely_mol_m3": c_gdl_tpb * 0.01,
        }
        dy[b["sep"][0] : b["sep"][1]] = sep_mod.separator_rhs(t, self.slice(y, "sep"), u_sep, p)
        u_col = {"I_cell_A": alg["I_cell_A"], "T_amb_K": float(u.get("T_amb_K", p.T_ref_K))}
        dy[b["col_fe"][0] : b["col_fe"][1]] = col_mod.collector_rhs(t, self.slice(y, "col_fe"), u_col, p)
        dy[b["col_air"][0] : b["col_air"][1]] = col_mod.collector_rhs(t, self.slice(y, "col_air"), u_col, p)
        u_th = {
            "q_reaction_W": alg["q_irrev_W"],
            "q_joule_W": alg["I_cell_A"] ** 2 * (alg["R_ionic_ohm"] + 1e-3),
            "T_amb_K": float(u.get("T_amb_K", p.T_ref_K)),
            "mdot_coolant_kg_s": float(u.get("mdot_coolant_kg_s", 0.04)),
        }
        dy[b["th"][0] : b["th"][1]] = th_mod.thermal_rhs(t, self.slice(y, "th"), u_th, p)
        u_air = {"mdot_air_kg_s": mdot_air, "r_orr_mol_s": alg["r_orr_mol_s"], "r_oer_mol_s": alg["r_oer_mol_s"], "T_K": T}
        dy[b["air"][0] : b["air"][1]] = air_mod.air_rhs(t, self.slice(y, "air"), u_air, p)
        I_fan = float(u.get("I_fan_A", 0.8 if abs(alg["I_cell_A"]) > 1e-3 else 0.1))
        dy[b["fan"][0] : b["fan"][1]] = air_mod.fan_rhs(t, self.slice(y, "fan"), {"I_fan_A": I_fan}, p)
        dy[b["flow"][0] : b["flow"][1]] = hyd_mod.flow_rhs(
            t,
            self.slice(y, "flow"),
            {"omega_pump_rad_s": float(self.slice(y, "pump")[0]), "valve_pos": float(self.slice(y, "valve")[0]), "T_ely_K": float(self.slice(y, "ely")[4])},
            p,
        )
        dy[b["pump"][0] : b["pump"][1]] = hyd_mod.Pump(p)._rhs(t, self.slice(y, "pump"), {"I_pump_A": float(u.get("I_pump_A", 1.5))}, {})
        mdot = float(self.slice(y, "flow")[0])
        dy[b["res"][0] : b["res"][1]] = hyd_mod.Reservoir(p)._rhs(
            t, self.slice(y, "res"), {"mdot_in_kg_s": mdot, "mdot_out_kg_s": mdot * 0.98, "T_in_K": float(self.slice(y, "ely")[4])}, {}
        )
        dy[b["valve"][0] : b["valve"][1]] = hyd_mod.Valve(p)._rhs(t, self.slice(y, "valve"), {"valve_cmd": float(u.get("valve_cmd", 0.75)), "dP_Pa": 2e4}, {})
        c_ely = float(self.slice(y, "ely")[0]) / max(float(self.slice(y, "ely")[5]), 1e-8)
        dy[b["pipe"][0] : b["pipe"][1]] = hyd_mod.Pipe(p)._rhs(
            t, self.slice(y, "pipe"), {"c_in_mol_m3": c_ely, "T_in_K": float(self.slice(y, "ely")[4]), "tau_s": 8.0}, {}
        )
        dy[b["hex"][0] : b["hex"][1]] = th_mod.hex_rhs(
            t,
            self.slice(y, "hex"),
            {"mdot_hot_kg_s": 0.04, "mdot_cold_kg_s": 0.05, "T_hot_in_K": float(self.slice(y, "th")[2]), "T_cold_in_K": float(u.get("T_amb_K", p.T_ref_K))},
            p,
        )
        P_dc = alg["V_cell_V"] * alg["I_cell_A"] * p.n_cells_series * p.n_cells_parallel * p.n_stacks
        P_grid = float(u.get("P_grid_W", 0.0))
        dy[b["dc"][0] : b["dc"][1]] = el_mod.DCBus(p)._rhs(t, self.slice(y, "dc"), {"P_net_W": P_grid - P_dc}, {})
        dy[b["inv"][0] : b["inv"][1]] = el_mod.GridInverter(p)._rhs(t, self.slice(y, "inv"), {"P_ref_W": P_grid, "Q_ref_var": float(u.get("Q_ref_var", 0.0))}, {})
        dy[b["grid"][0] : b["grid"][1]] = el_mod.GridInterface(p)._rhs(t, self.slice(y, "grid"), {"P_grid_W": P_grid}, {})
        u_deg = {
            "I_cell_A": alg["I_cell_A"],
            "eta_oer_V": alg["eta_oer_V"],
            "r_carb_mol_s": max(float(self.slice(y, "ely")[3]), 0.0) * 1e-4,
            "saturation": alg["s_gdl"],
            "oer_isolated": alg["oer_isolated"],
        }
        dy[b["deg"][0] : b["deg"][1]] = deg_mod.degradation_rhs(t, self.slice(y, "deg"), u_deg, p)
        return dy

    def simulate(
        self,
        t_span: tuple[float, float],
        inputs: Callable[[float], Mapping[str, float]] | Mapping[str, float] | None = None,
        y0: NDArray[np.float64] | None = None,
        n_eval: int = 400,
        method: str = "BDF",
        rtol: float = 1e-5,
        atol: float = 1e-8,
        filled: bool = True,
    ) -> dict[str, Any]:
        y_init = self.y0(filled=filled) if y0 is None else y0

        def u_at(t: float) -> Mapping[str, float]:
            if inputs is None:
                return {}
            if callable(inputs):
                return inputs(t)
            return inputs

        def fun(t: float, y: NDArray[np.float64]) -> NDArray[np.float64]:
            return self.rhs(t, y, u_at(t))

        t_eval = np.linspace(t_span[0], t_span[1], n_eval)
        sol = solve_ivp(fun, t_span, y_init, method=method, t_eval=t_eval, rtol=rtol, atol=atol)
        if not sol.success:
            raise RuntimeError(sol.message)
        y = np.asarray(sol.y, dtype=float)
        if not np.all(np.isfinite(y)):
            raise RuntimeError("plant trajectory contains NaNs")
        t = np.asarray(sol.t, dtype=float)
        records = [self.algebraic(float(ti), y[:, i], u_at(float(ti))) for i, ti in enumerate(t)]
        alg = {k: np.array([r[k] for r in records], dtype=float) for k in records[0]}
        return {
            "t": t,
            "y": y,
            "alg": alg,
            "state_names": self.state_names,
            "nfev": int(sol.nfev),
            "success": True,
        }
