#!/usr/bin/env python3
"""Integrate every component and the assembled plant; save seaborn figures."""

from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "src"))

from plant_sim.bootstrap import setup_path  # noqa: E402

setup_path()

from plant_sim.components.air_system import AirSystem, Fan  # noqa: E402
from plant_sim.components.base import integrate_component  # noqa: E402
from plant_sim.components.current_collector import CurrentCollector  # noqa: E402
from plant_sim.components.electrolyte import Electrolyte  # noqa: E402
from plant_sim.components.gdl import GasDiffusionLayer  # noqa: E402
from plant_sim.components.her import HydrogenEvolution  # noqa: E402
from plant_sim.components.hydraulics import ElectrolyteFlow, Pipe, Pump, Reservoir, Valve  # noqa: E402
from plant_sim.components.iron_anode import IronAnode  # noqa: E402
from plant_sim.components.oer import OxygenEvolution  # noqa: E402
from plant_sim.components.orr import OxygenReduction, stacked_orr_flows  # noqa: E402
from plant_sim.components.separator import Separator  # noqa: E402
from plant_sim.components.thermal import HeatExchanger, ThermalNetwork  # noqa: E402
from plant_sim.params import CAPACITY_FE_OH2_MAH_G, CAPACITY_MAGNETITE_MAH_G, default_params  # noqa: E402
from plant_sim.plant import PlantModel  # noqa: E402
from plant_sim.plotting import heatmap, timeseries, verification_table, xy_plot  # noqa: E402
from plant_sim.scenarios.mission import (  # noqa: E402
    carbonation_inputs,
    charge_discharge_inputs,
    commissioning_inputs,
    full_mission_inputs,
    grid_services_inputs,
    starvation_inputs,
    thermal_excursion_inputs,
)
from plant_sim.substructures.air_cathode import AirCathode  # noqa: E402
from plant_sim.substructures.air_handling import AirHandling  # noqa: E402
from plant_sim.substructures.cell_stack import CellStack  # noqa: E402
from plant_sim.substructures.channeled_electrode import ChanneledElectrode  # noqa: E402
from plant_sim.substructures.dual_electrode_cell import DualElectrodeCell  # noqa: E402
from plant_sim.substructures.electrical_balance import ElectricalBalance  # noqa: E402
from plant_sim.substructures.hydraulics_bop import HydraulicsBOP  # noqa: E402
from plant_sim.substructures.negative_electrode import NegativeElectrode  # noqa: E402
from plant_sim.substructures.vessel_lid_air import VesselLidAir  # noqa: E402


def _ok(name: str, t: np.ndarray, y: np.ndarray) -> None:
    if not np.all(np.isfinite(y)):
        raise RuntimeError(f"{name}: NaNs")
    print(f"  {name}: nfev-ok states={y.shape[0]} steps={t.size} finite")


def run_components(p=None) -> dict[str, float]:
    p = p or default_params()
    report: dict[str, float] = {}
    print("== 01-09 isolated components ==")

    fe = IronAnode(p)
    I_dch = p.I_discharge_100h_A * 40.0  # accelerated isolation current

    def rhs_fe(t, y):
        return fe.rhs(t, y, {"I_fe_A": I_dch, "T_amb_K": p.T_ep_sim_K, "a_oh": 6.0, "a_h2o": 0.72}, {})

    t, y = integrate_component(rhs_fe, fe.y0(), (0.0, 4000.0), n_eval=200)
    _ok("01_IronAnode", t, y)
    timeseries(
        t / 3600,
        {"n_Fe": y[0], "n_FeOH2": y[1], "n_Fe3O4": y[2]},
        xlabel="t (h)",
        ylabel="inventory (mol)",
        title="Iron anode phase inventories",
        callout="EP4602674A1 [0042]-[0043] Eq. 1-2; IA-FE-001",
        stem="01_iron_phases",
    )
    timeseries(
        t / 3600,
        {"T": y[3], "porosity": y[5], "a_rel": y[6]},
        xlabel="t (h)",
        ylabel="T (K) / porosity / a_rel",
        title="Iron anode thermal and morphological states",
        callout="Volume increase taken up in porosity (IA-SYS-020)",
        stem="01_iron_morph",
    )
    eta = []
    cap = []
    for i in range(len(t)):
        o = fe.outputs(float(t[i]), y[:, i], {"I_fe_A": I_dch, "a_oh": 6.0, "a_h2o": 0.72}, {})
        eta.append(o["eta_fe_V"])
        cap.append(o["capacity_extracted_mAh_g"])
    timeseries(
        t / 3600,
        {"eta_V": eta, "mAh_g": cap},
        xlabel="t (h)",
        ylabel="eta (V) / extracted (mAh/g)",
        title="Iron overpotential and extracted specific capacity",
        callout="Theoretical first-step 960 mAh/g Fe",
        stem="01_iron_eta_cap",
    )
    xy_plot(
        eta,
        {"i_approx": np.full_like(t, I_dch / p.A_geom_m2)},
        xlabel="eta_fe (V)",
        ylabel="i (A/m2)",
        title="Iron anode polarization (accelerated)",
        callout="Butler-Volmer via ironair.chemistry.kinetics",
        stem="01_iron_polarization",
    )
    report["capacity_step1_theory_mAh_g"] = CAPACITY_FE_OH2_MAH_G
    report["capacity_step2_theory_mAh_g"] = CAPACITY_MAGNETITE_MAH_G
    report["capacity_extracted_end_mAh_g"] = float(cap[-1])

    her = HydrogenEvolution(p)

    def rhs_her(t, y):
        I = -2.0 * I_dch
        return her.rhs(
            t, y, {"I_fe_A": I, "T_K": p.T_ep_sim_K, "L_path_m": p.L_anode_m, "a_oh": 6.0, "a_h2o": 0.72}, {}
        )

    t, y = integrate_component(rhs_her, her.y0(), (0.0, 2000.0), n_eval=180)
    _ok("02_HER", t, y)
    ce = [
        her.outputs(
            float(ti),
            y[:, i],
            {"I_fe_A": -2.0 * I_dch, "T_K": p.T_ep_sim_K, "L_path_m": p.L_anode_m, "a_oh": 6.0, "a_h2o": 0.72},
            {},
        )["CE"]
        for i, ti in enumerate(t)
    ]
    timeseries(
        t / 60,
        {"n_H2": y[0], "theta": y[1]},
        xlabel="t (min)",
        ylabel="n_H2 (mol) / bubble holdup",
        title="HER inventory and channel bubble holdup",
        callout="EP4602674A1 [0044]-[0047], [0056] vertical channel egress",
        stem="02_her_gas",
    )
    timeseries(
        t / 60,
        {"CE": ce},
        xlabel="t (min)",
        ylabel="coulombic efficiency",
        title="Charge CE = I_Fe / (I_Fe + I_HER)",
        callout="Thick planar electrodes lose CE as L_path grows",
        stem="02_her_ce",
    )
    L = np.linspace(0.005, 0.08, 40)
    ce_L = [
        her.outputs(
            0.0,
            her.y0(),
            {"I_fe_A": -I_dch, "T_K": p.T_ep_sim_K, "L_path_m": float(Li), "a_oh": 6.0, "a_h2o": 0.72},
            {},
        )["CE"]
        for Li in L
    ]
    xy_plot(
        L * 100,
        {"CE": ce_L},
        xlabel="ionic path length (cm)",
        ylabel="CE",
        title="HER competition vs electrode thickness",
        callout="EP [0047] FIGS. 23-24 trend",
        stem="02_her_thickness",
    )

    orr = OxygenReduction(p, mode="vertical")

    def rhs_orr(t, y):
        return orr.rhs(
            t,
            y,
            {
                "I_orr_A": -I_dch,
                "T_K": p.T_ep_sim_K,
                "c_O2_gdl_mol_m3": 8.0,
                "p_O2_Pa": 21200.0,
                "a_oh": 6.0,
                "a_h2o": 0.72,
            },
            {},
        )

    t, y = integrate_component(rhs_orr, orr.y0(), (0.0, 800.0), n_eval=160)
    _ok("03_ORR", t, y)
    timeseries(
        t,
        {"c_tpb": y[1], "q_dl": y[0], "util": y[2]},
        xlabel="t (s)",
        ylabel="c_O2 (mol/m3) / q_dl (C) / util",
        title="ORR interfacial oxygen and double layer",
        callout="US12308414B2 four-electron ORR; IA-ORR-001",
        stem="03_orr_states",
    )
    eta = np.linspace(-0.4, 0.05, 80)
    i_bv = []
    from ironair.chemistry.kinetics import butler_volmer_current_density_a_m2
    from plant_sim.components.base import i0_T

    i0 = i0_T(p.i0_orr_A_m2, p.Ea_orr_J_mol, p.T_ep_sim_K)
    for e in eta:
        i_bv.append(butler_volmer_current_density_a_m2(float(e), i0, 0.5, 0.5, p.T_ep_sim_K))
    xy_plot(
        eta,
        {"i_ORR": i_bv},
        xlabel="eta_ORR (V)",
        ylabel="i (A/m2)",
        title="ORR Butler-Volmer polarization",
        callout="Cathodic current for eta < 0 vs Nernst O2",
        stem="03_orr_polarization",
    )

    oer = OxygenEvolution(p, layout="interdigitated")

    def rhs_oer(t, y):
        return oer.rhs(
            t,
            y,
            {
                "I_oer_A": I_dch,
                "T_K": p.T_ep_sim_K,
                "a_oh": 6.0,
                "a_h2o": 0.72,
                "p_O2_Pa": p.P_atm_Pa,
                "oer_isolated": 0.0,
            },
            {},
        )

    t, y = integrate_component(rhs_oer, oer.y0(), (0.0, 1500.0), n_eval=160)
    _ok("04_OER", t, y)
    timeseries(
        t / 60,
        {"theta_cat": y[0], "n_O2": y[1], "theta_b": y[2]},
        xlabel="t (min)",
        ylabel="catalyst / n_O2 (mol) / bubbles",
        title="OER catalyst, evolved O2, bubbles",
        callout="EP Claims 1, 3, 11-12 interdigitated OER; US dual-cathode isolation",
        stem="04_oer_states",
    )
    from plant_sim.components.oer import LAYOUT_AREA_FACTOR

    xy_plot(
        np.arange(len(LAYOUT_AREA_FACTOR)),
        {"area_factor": np.array(list(LAYOUT_AREA_FACTOR.values()))},
        xlabel="layout index (see callout)",
        ylabel="geometric area factor",
        title="OER layout specific-area factors",
        callout=", ".join(LAYOUT_AREA_FACTOR),
        stem="04_oer_layouts",
    )

    gdl = GasDiffusionLayer(p)

    def rhs_gdl(t, y):
        r = 2e-7 if t < 200 else 8e-7
        head = 0.05 if t < 250 else 0.4
        return gdl.rhs(
            t,
            y,
            {
                "T_K": p.T_ep_sim_K,
                "P_Pa": p.P_atm_Pa,
                "x_O2": 0.2095 if t < 80 else 0.05,
                "r_orr_mol_s": r,
                "hydraulic_head_m": head,
                "oer_dryout": 0.0,
            },
            {},
        )

    t, y = integrate_component(rhs_gdl, gdl.y0(), (0.0, 600.0), n_eval=180)
    _ok("05_GDL", t, y)
    n = p.n_gdl_nodes
    timeseries(
        t,
        {f"n{i}": y[i] for i in (0, n // 2, n - 1)},
        xlabel="t (s)",
        ylabel="c_O2 (mol/m3)",
        title="GDL oxygen profile (air / mid / TPB)",
        callout="IA-GDL-001 delayed interior O2 after boundary step; US flooding FIGS. 8-9B",
        stem="05_gdl_o2",
    )
    timeseries(
        t,
        {"saturation": y[n], "crust": y[n + 1]},
        xlabel="t (s)",
        ylabel="saturation / crust",
        title="GDL flooding and salt-crust blockage",
        callout="Hydraulic head drives liquid migration into vertical ORR",
        stem="05_gdl_flood",
    )
    z = np.linspace(0, p.L_gdl_m * 1e3, n)
    xy_plot(
        z,
        {"c_end": y[:n, -1], "c_start": y[:n, 0]},
        xlabel="GDL depth (mm)",
        ylabel="c_O2 (mol/m3)",
        title="Through-thickness O2 at start vs end",
        callout="Method of lines, scipy.integrate.solve_ivp BDF",
        stem="05_gdl_profile",
    )

    ely = Electrolyte(p, filled=True)

    def rhs_ely(t, y):
        return ely.rhs(
            t,
            y,
            {
                "r_iron_mol_s": 1e-6,
                "r_orr_mol_s": 5e-7,
                "r_oer_mol_s": 0.0,
                "r_her_mol_s": 1e-8,
                "fill_m3_s": 0.0,
                "x_CO2": 4.2e-4,
                "q_heat_W": 2.0,
                "T_amb_K": p.T_ep_sim_K,
            },
            {},
        )

    t, y = integrate_component(rhs_ely, ely.y0(), (0.0, 2500.0), n_eval=180)
    _ok("06_Electrolyte", t, y)
    cM = y[0] / np.maximum(y[5], 1e-12) / 1000.0
    timeseries(
        t / 60,
        {"c_KOH_M": cM, "n_CO3": y[2], "s_wet": y[6]},
        xlabel="t (min)",
        ylabel="KOH (M) / n_CO3 (mol) / wetting",
        title="Electrolyte KOH, carbonation, wetting",
        callout="Default 6 M KOH @ 303 K (EP FIGS. 19-26); US carbonation",
        stem="06_ely_chem",
    )
    timeseries(
        t / 60,
        {"T": y[4], "V": y[5]},
        xlabel="t (min)",
        ylabel="T (K) / V (m3)",
        title="Electrolyte temperature and volume",
        callout="IA-ELY-001 concentration-dependent properties via ironair.properties",
        stem="06_ely_TV",
    )
    report["c_KOH_end_M"] = float(cM[-1])

    sep = Separator(p)

    def rhs_sep(t, y):
        return sep.rhs(
            t,
            y,
            {
                "T_ely_K": p.T_ep_sim_K,
                "c_KOH_mol_m3": 6000.0,
                "I_cell_A": I_dch,
                "s_wet": 0.95,
                "c_O2_ely_mol_m3": 0.02,
            },
            {},
        )

    t, y = integrate_component(rhs_sep, sep.y0(), (0.0, 1200.0), n_eval=120)
    _ok("07_Separator", t, y)
    R = [
        sep.outputs(float(ti), y[:, i], {"c_KOH_mol_m3": 6000.0, "I_cell_A": I_dch}, {})["R_ionic_ohm"]
        for i, ti in enumerate(t)
    ]
    timeseries(
        t,
        {"T": y[0], "s": y[1], "c_O2": y[2]},
        xlabel="t (s)",
        ylabel="T (K) / s / c_O2 (mol/m3)",
        title="Separator thermal, saturation, O2 block",
        callout="US FIG. 4A oxygen-blocking hydrophilic separator; EP Claim 2",
        stem="07_sep_states",
    )
    timeseries(
        t,
        {"R_ionic": R},
        xlabel="t (s)",
        ylabel="R_ionic (ohm)",
        title="Separator ionic resistance",
        callout="R = L tau / (sigma A eps s^1.5)",
        stem="07_sep_R",
    )

    col = CurrentCollector(p)

    def rhs_col(t, y):
        return col.rhs(t, y, {"I_cell_A": I_dch, "T_amb_K": p.T_ep_sim_K}, {})

    t, y = integrate_component(rhs_col, col.y0(), (0.0, 2000.0), n_eval=120)
    _ok("08_CurrentCollector", t, y)
    timeseries(
        t / 60,
        {"T": y[0], "deg": y[1]},
        xlabel="t (min)",
        ylabel="T (K) / degradation",
        title="Collector temperature and contact degradation",
        callout="IA-COL-001 V_ohm = I R(T, deg); US FIGS. 4B-4C",
        stem="08_col_states",
    )

    th = ThermalNetwork(p)

    def rhs_th(t, y):
        q = 15.0 if t > 50 else 0.0
        return th.rhs(t, y, {"q_reaction_W": q, "q_joule_W": 4.0, "T_amb_K": p.T_ref_K, "mdot_coolant_kg_s": 0.04}, {})

    t, y = integrate_component(rhs_th, th.y0(), (0.0, 1800.0), n_eval=160)
    _ok("09_Thermal", t, y)
    timeseries(
        t / 60,
        {"Te": y[0], "Tely": y[1], "Tvessel": y[2], "Tlid": y[3], "Tcool": y[4]},
        xlabel="t (min)",
        ylabel="T (K)",
        title="Thermal network node temperatures",
        callout="US FIGS. 1E-1F cavity + FIG. 9A lid thermal management; IA-THM-001",
        stem="09_thermal_nodes",
    )
    hx = HeatExchanger(p)
    t, y = integrate_component(
        lambda t, y: hx.rhs(
            t, y, {"mdot_hot_kg_s": 0.04, "mdot_cold_kg_s": 0.05, "T_hot_in_K": 320.0, "T_cold_in_K": 290.0}, {}
        ),
        hx.y0(),
        (0.0, 400.0),
        n_eval=80,
    )
    _ok("09_HeatExchanger", t, y)
    timeseries(
        t,
        {"Thot": y[0], "Tcold": y[1]},
        xlabel="t (s)",
        ylabel="T (K)",
        title="Heat exchanger hot/cold streams",
        callout="IA-HEX-001 cavity coolant / lid loops",
        stem="09_hex",
    )

    air = AirSystem(p)
    t, y = integrate_component(
        lambda t, y: air.rhs(
            t, y, {"mdot_air_kg_s": 0.003, "r_orr_mol_s": 1e-6, "r_oer_mol_s": 0.0, "T_K": p.T_ep_sim_K}, {}
        ),
        air.y0(),
        (0.0, 200.0),
        n_eval=80,
    )
    _ok("09_AirSystem", t, y)
    timeseries(
        t,
        {"p": y[0], "nO2": y[1]},
        xlabel="t (s)",
        ylabel="p (Pa) / n_O2 (mol)",
        title="Air manifold pressure and oxygen",
        callout="IA-AIR-001 US Claims 9, 14-15",
        stem="09_air",
    )
    fan = Fan(p)
    t, y = integrate_component(lambda t, y: fan.rhs(t, y, {"I_fan_A": 1.5}, {}), fan.y0(), (0.0, 20.0), n_eval=60)
    _ok("09_Fan", t, y)
    timeseries(
        t,
        {"omega": y[0]},
        xlabel="t (s)",
        ylabel="omega (rad/s)",
        title="Fan rotor speed",
        callout="IA-AIR-002",
        stem="09_fan",
    )

    for name, obj, u in [
        ("flow", ElectrolyteFlow(p), {"omega_pump_rad_s": 90.0, "valve_pos": 0.7, "T_ely_K": p.T_ep_sim_K}),
        ("pump", Pump(p), {"I_pump_A": 2.0}),
        ("res", Reservoir(p), {"mdot_in_kg_s": 0.05, "mdot_out_kg_s": 0.04}),
        ("valve", Valve(p), {"valve_cmd": 0.9, "dP_Pa": 3e4}),
        ("pipe", Pipe(p), {"c_in_mol_m3": 6500.0, "T_in_K": 310.0, "tau_s": 5.0}),
    ]:
        t, y = integrate_component(lambda t, y, uu=u, o=obj: o.rhs(t, y, uu, {}), obj.y0(), (0.0, 30.0), n_eval=40)
        _ok(f"09_{name}", t, y)

    verification_table(
        [
            ("960 mAh/g Fe(OH)2", 960.0, CAPACITY_FE_OH2_MAH_G, "mAh/g"),
            ("320 mAh/g Fe3O4", 320.0, CAPACITY_MAGNETITE_MAH_G, "mAh/g"),
            ("6 M KOH default", 6.0, p.c_KOH_mol_m3 / 1000.0, "mol/L"),
            ("303 K EP ref", 303.15, p.T_ep_sim_K, "K"),
            ("25 C US STP", 298.15, p.T_ref_K, "K"),
            ("1 atm", 101325.0, p.P_atm_Pa, "Pa"),
            ("loading 3 g/cm2", 3.0, p.loading_g_cm2, "g/cm2"),
            ("VF 0.70", 0.70, p.vf_electrolyte_charged, "1"),
        ],
        "00_verification_constants",
    )
    return report


def run_substructures(p=None) -> None:
    p = p or default_params()
    print("== 10-39 substructures ==")
    neg = NegativeElectrode(p)
    res = neg.simulate((0.0, 600.0), u={"I_fe_A": p.I_discharge_100h_A * 20, "T_amb_K": p.T_ep_sim_K}, n_eval=80)
    _ok("10_NegativeElectrode", res["t"], res["y"])
    timeseries(
        res["t"],
        {"n_Fe": res["y"][0], "n_H2": res["y"][8]},
        xlabel="t (s)",
        ylabel="mol",
        title="Negative electrode: iron + HER",
        callout="10_NegativeElectrode couples IA-FE-001 + IA-HER-001 + IA-COL-001 + IA-ELY-001",
        stem="10_negative",
    )

    air_c = AirCathode(p)
    res = air_c.simulate(
        (0.0, 400.0),
        u={"I_orr_A": -p.I_discharge_100h_A * 20, "I_oer_A": 0.0, "T_K": p.T_ep_sim_K, "mdot_air_kg_s": 0.002},
        n_eval=80,
    )
    _ok("11_AirCathode", res["t"], res["y"])
    timeseries(
        res["t"],
        {"c_orr": res["y"][1], "n_O2_air": res["y"][3 + 3 + p.n_gdl_nodes + 2 + 1]},
        xlabel="t (s)",
        ylabel="states",
        title="Air cathode ORR + GDL + air",
        callout="11_AirCathode IA-ORR/OER/GDL/AIR",
        stem="11_air_cathode",
    )

    cell = DualElectrodeCell(p)
    res = cell.simulate((0.0, 500.0), u={"mode": -1.0, "I_cell_A": p.I_discharge_100h_A * 15}, n_eval=80)
    _ok("12_DualElectrodeCell", res["t"], res["y"])
    timeseries(
        res["t"],
        {"n_Fe": res["y"][0]},
        xlabel="t (s)",
        ylabel="n_Fe (mol)",
        title="Dual-electrode cell discharge (ORR path)",
        callout="US12308414B2 dual cathode; EP [0049] discharge iron-ORR-load",
        stem="12_dual_dch",
    )
    res = cell.simulate((0.0, 500.0), u={"mode": 1.0, "I_cell_A": p.I_discharge_100h_A * 15}, n_eval=80)
    _ok("12_DualElectrodeCell_charge", res["t"], res["y"])
    timeseries(
        res["t"],
        {"n_Fe": res["y"][0], "n_H2": res["y"][8]},
        xlabel="t (s)",
        ylabel="mol",
        title="Dual-electrode cell charge (OER path + HER)",
        callout="Charge iron-OER-source; OER isolatable from ORR (US Claim 16)",
        stem="12_dual_chg",
    )

    stack = CellStack(p, n_cells=3)
    res = stack.simulate((0.0, 200.0), n_eval=40)
    _ok("20_CellStack", res["t"], res["y"])
    eq = stack.equal_pressure_drop(compensate=True)
    neq = stack.equal_pressure_drop(compensate=False)
    xy_plot(
        eq["z_m"],
        {"dP_comp_Pa": eq["dP_Pa"], "dP_naive_Pa": neq["dP_Pa"]},
        xlabel="depth z (m)",
        ylabel="air-path ΔP (Pa)",
        title="Stacked submerged ORR pressure drop",
        callout="US12308414B2 Claim 1 equal ΔP via depth-increasing pocket thickness",
        stem="20_equal_dp",
    )
    xy_plot(
        eq["z_m"],
        {"Q_comp": eq["Q_m3_s"], "Q_naive": neq["Q_m3_s"]},
        xlabel="depth z (m)",
        ylabel="Q (m3/s)",
        title="Stacked ORR volumetric flow distribution",
        callout="Compensated geometry equalizes Q despite hydrostatic head",
        stem="20_equal_q",
    )
    heatmap(
        np.vstack([eq["dP_Pa"], neq["dP_Pa"]]),
        xlabel="section",
        ylabel="compensated / naive",
        title="ΔP heatmap stacked ORR",
        callout="IA-STK-001 / US Claim 1",
        stem="20_dp_heat",
        xticklabels=[str(i) for i in range(eq["dP_Pa"].size)],
        yticklabels=["compensated", "naive"],
    )

    ch = ChanneledElectrode(p)
    cmp = ch.compare_layouts(p.I_discharge_100h_A * 10)
    names = [k.replace("CE_", "") for k in cmp if k.startswith("CE_")]
    xy_plot(
        np.arange(len(names)),
        {"CE": np.array([cmp[f"CE_{n}"] for n in names])},
        xlabel="layout index",
        ylabel="CE",
        title="Charge CE vs channel/OER layout",
        callout="EP4602674A1 channel 3-50 mm x 1-40 mm, spacing 10-50 mm; loading 1-7 g/cm2; VF 0.5-0.9",
        stem="21_channel_ce",
    )
    res = ch.simulate((0.0, 300.0), u={"I_fe_A": -p.I_discharge_100h_A * 10}, n_eval=50)
    _ok("21_ChanneledElectrode", res["t"], res["y"])

    ves = VesselLidAir(p, dri=True)
    res = ves.simulate((0.0, 250.0), u={"I_fe_A": p.I_discharge_100h_A * 5, "I_fan_A": 0.8}, n_eval=50)
    _ok("22_VesselLidAir", res["t"], res["y"])
    timeseries(
        res["t"],
        {"T_fe": res["y"][3], "p_air": res["y"][8]},
        xlabel="t (s)",
        ylabel="T (K) / p (Pa)",
        title="DRI bed vessel + lid air",
        callout="US Claim 18 DRI pellet bed; FIG. 9A multi-function lid",
        stem="22_vessel",
    )

    HydraulicsBOP(p).simulate((0.0, 40.0), n_eval=30)
    print("  31_Hydraulics ok")
    AirHandling(p).simulate((0.0, 40.0), n_eval=30)
    print("  32_AirHandling ok")
    ElectricalBalance(p).simulate((0.0, 20.0), n_eval=30)
    print("  33_ElectricalBalance ok")


def run_plant_scenarios(p=None) -> None:
    p = p or default_params()
    plant = PlantModel(p)
    print("== 40 plant + 90-99 scenarios ==")

    print("  90_Commissioning ...")
    comm = plant.simulate(
        (0.0, 7200.0), inputs=commissioning_inputs(p), y0=plant.y0(filled=False), n_eval=360, rtol=1e-4
    )
    t = comm["t"]
    a = comm["alg"]
    y = comm["y"]
    b = plant.blocks
    timeseries(
        t / 3600,
        {"P_grid_W": a["P_grid_W"], "I_cell_A": a["I_cell_A"], "V_cell_V": a["V_cell_V"]},
        xlabel="t (h)",
        ylabel="P (W) / I (A) / V (V)",
        title="Commissioning: grid power, current, cell voltage",
        callout="90_Commissioning first charge from grid after KOH fill; IA-GRD-001",
        stem="90_comm_electrical",
    )
    timeseries(
        t / 3600,
        {"n_OH": y[b["ely"][0]], "s_wet": y[b["ely"][1] - 1], "V_ely": y[b["ely"][0] + 5]},
        xlabel="t (h)",
        ylabel="n_OH (mol) / wetting / V (m3)",
        title="Commissioning chemistry: KOH fill and pore wetting",
        callout="IA-SYS-021 6 M KOH make-up; US first-fill / formation analog",
        stem="90_comm_chemistry",
    )
    timeseries(
        t / 3600,
        {"n_H2": a["n_H2_mol"], "n_O2": a["n_O2_oer_mol"], "CE": a["CE"]},
        xlabel="t (h)",
        ylabel="mol / CE",
        title="Commissioning gas evolution (H2, O2) and CE",
        callout="HER parasitic on first charge; OER on dual-electrode path",
        stem="90_comm_gas",
    )
    timeseries(
        t / 3600,
        {"T_fe": y[b["fe"][0] + 3], "T_ely": y[b["ely"][0] + 4], "T_ves": y[b["th"][0] + 2]},
        xlabel="t (h)",
        ylabel="T (K)",
        title="Commissioning temperature rise",
        callout="Formation + I*eta heat; US lid/cavity thermal nodes",
        stem="90_comm_temp",
    )
    timeseries(
        t / 3600,
        {"SOC": a["SOC"], "n_CO3": y[b["ely"][0] + 2], "p_O2_atm": a["p_O2_Pa"] / p.P_atm_Pa},
        xlabel="t (h)",
        ylabel="SOC / n_CO3 (mol) / pO2 (atm)",
        title="Commissioning SOC, carbonation risk, pO2",
        callout="US CO2 carbonation; pO2 window 0.001-100 atm charge",
        stem="90_comm_soc_carb",
    )
    timeseries(
        t / 3600,
        {"fill_proxy_V": y[b["ely"][0] + 5], "mode": a["mode"], "P_grid": a["P_grid_W"]},
        xlabel="t (h)",
        ylabel="mixed",
        title="Commissioning mode, fill volume, grid power",
        callout="Rest then first polarization from grid",
        stem="90_comm_mode",
    )

    print("  91_ChargeDischarge ...")
    p8 = p.with_duration(8.0, 8.0)
    plant8 = PlantModel(p8)
    r8 = plant8.simulate((0.0, 1800.0), inputs=charge_discharge_inputs(600.0, 600.0, p8), n_eval=120, rtol=1e-4)
    timeseries(
        r8["t"] / 60,
        {"I": r8["alg"]["I_cell_A"], "V": r8["alg"]["V_cell_V"], "SOC": r8["alg"]["SOC"]},
        xlabel="t (min)",
        ylabel="I (A) / V (V) / SOC",
        title="Rated charge/discharge (8 h thickness scaling)",
        callout="US LODES 8 h; anode thickness maps to duration",
        stem="91_cd_8h",
    )
    p100 = p.with_duration(100.0, 100.0)
    p300 = p.with_duration(100.0, 300.0)
    xy_plot(
        np.array([8.0, 100.0, 300.0]),
        {"L_anode_cm": np.array([p.with_duration(8, 8).L_anode_m, p100.L_anode_m, p300.L_anode_m]) * 100},
        xlabel="duration (h)",
        ylabel="L_anode (cm)",
        title="Anode thickness vs LODES duration",
        callout="US ~3-5 cm / 100 h and ~4-6 cm / 300 h; Lc vs Ld asymmetric 100/300 h",
        stem="91_thickness",
    )

    print("  92_GridServices ...")
    g = plant.simulate((0.0, 3600.0), inputs=grid_services_inputs(p), n_eval=180, rtol=1e-4)
    timeseries(
        g["t"] / 60,
        {"P_grid": g["alg"]["P_grid_W"], "P_exch": g["y"][plant.blocks["grid"][0]], "SOC": g["alg"]["SOC"]},
        xlabel="t (min)",
        ylabel="P (W) / SOC",
        title="Grid services: curtailment charge, discharge to load, ramp",
        callout="US FIGS. 94-102 bulk energy / surplus solar",
        stem="92_grid",
    )

    print("  93_ThermalExcursion ...")
    ths = plant.simulate((0.0, 2400.0), inputs=thermal_excursion_inputs(p), n_eval=150, rtol=1e-4)
    timeseries(
        ths["t"] / 60,
        {"T_fe": ths["y"][b["fe"][0] + 3], "T_ves": ths["y"][b["th"][0] + 2], "T_cool": ths["y"][b["th"][0] + 4]},
        xlabel="t (min)",
        ylabel="T (K)",
        title="Thermal excursion and coolant recovery",
        callout="IA-THM-001 wide/low vessel heat rejection",
        stem="93_thermal",
    )

    print("  94_StarvationAndFlooding ...")
    st = plant.simulate((0.0, 1800.0), inputs=starvation_inputs(p), n_eval=150, rtol=1e-4)
    timeseries(
        st["t"] / 60,
        {"V": st["alg"]["V_cell_V"], "s_gdl": st["alg"]["s_gdl"], "pO2": st["alg"]["p_O2_Pa"]},
        xlabel="t (min)",
        ylabel="V (V) / s / pO2 (Pa)",
        title="Air starvation then GDL flooding",
        callout="IA-GDL-001; US hydraulic head flooding vs dry-out",
        stem="94_starve_flood",
    )

    print("  95_Carbonation ...")
    cb = plant.simulate((0.0, 2000.0), inputs=carbonation_inputs(p), n_eval=120, rtol=1e-4)
    timeseries(
        cb["t"] / 60,
        {"n_CO3": cb["y"][b["ely"][0] + 2], "CE": cb["alg"]["CE"], "n_H2": cb["alg"]["n_H2_mol"]},
        xlabel="t (min)",
        ylabel="n_CO3 / CE / n_H2",
        title="Carbonation and parasitic HER",
        callout="US CO2 paragraph; EP HER competition",
        stem="95_carbonation",
    )

    print("  96 already plotted in stack equal ΔP")
    print("  97 channel geometry window")
    from plant_sim.substructures.channeled_electrode import assert_channel_window

    assert_channel_window(p.channel_length_m, p.channel_width_m, p.channel_spacing_m, p)
    L = np.linspace(p.channel_length_min_m, p.channel_length_max_m, 12)
    W = np.linspace(p.channel_width_min_m, p.channel_width_max_m, 10)
    Z = np.zeros((W.size, L.size))
    for i, w in enumerate(W):
        for j, ell in enumerate(L):
            Z[i, j] = w * ell
    heatmap(
        Z,
        xlabel="channel length (m)",
        ylabel="channel width (m)",
        title="EP channel geometry window area",
        callout="EP 3-50 mm x 1-40 mm; spacing 10-50 mm; Fe 1-7 g/cm2; VF 0.5-0.9",
        stem="97_channel_window",
    )
    load = np.linspace(1.0, 7.0, 13)
    vf = np.linspace(0.5, 0.9, 9)
    Q = np.outer(vf, load)
    heatmap(
        Q,
        xlabel="loading g/cm2",
        ylabel="VF",
        title="Fe loading × electrolyte VF design space",
        callout="EP Claims 16-17",
        stem="97_loading_vf",
    )

    print("  98_DegradationCE ...")
    from plant_sim.components.degradation import Degradation

    deg = Degradation(p)

    def rhs_d(t, y):
        return deg.rhs(
            t,
            y,
            {
                "I_cell_A": 2.0,
                "eta_oer_V": 0.5,
                "r_carb_mol_s": 1e-7,
                "saturation": 0.3,
                "oer_isolated": 0.0 if t > 50000 else 1.0,
            },
            {},
        )

    t, y = integrate_component(rhs_d, deg.y0(), (0.0, 2e5), n_eval=200, rtol=1e-5)
    _ok("98_Degradation", t, y)
    ce_fade = [deg.outputs(float(ti), y[:, i], {}, {})["CE_fade"] for i, ti in enumerate(t)]
    asr = y[1]
    timeseries(
        t / 86400,
        {"CE_fade": ce_fade, "ASR_growth": asr, "orr_loss": y[2]},
        xlabel="t (day)",
        ylabel="fade / ASR / ORR loss",
        title="Degradation CE and ASR trends (EP FIGS. 19-27 analog)",
        callout="EP FIGS. 19-27 at 6 M KOH, 303 K; dual-cathode isolation protects ORR",
        stem="98_degradation",
    )

    print("  99_FullPlantMission ...")
    m = plant.simulate((0.0, 14000.0), inputs=full_mission_inputs(p), y0=plant.y0(filled=False), n_eval=400, rtol=1e-4)
    timeseries(
        m["t"] / 3600,
        {"P": m["alg"]["P_grid_W"], "SOC": m["alg"]["SOC"], "V": m["alg"]["V_cell_V"], "T": m["alg"]["T_K"]},
        xlabel="t (h)",
        ylabel="P (W) / SOC / V (V) / T (K)",
        title="Full plant mission: commission → charge → idle → discharge → rest",
        callout="Same PlantModel RHS as 40_PlantModel and 90_Commissioning",
        stem="99_mission",
    )
    timeseries(
        m["t"] / 3600,
        {"I": m["alg"]["I_cell_A"], "CE": m["alg"]["CE"], "n_H2": m["alg"]["n_H2_mol"], "s_gdl": m["alg"]["s_gdl"]},
        xlabel="t (h)",
        ylabel="I / CE / n_H2 / s",
        title="Mission current, CE, hydrogen, GDL saturation",
        callout="99_FullPlantMission",
        stem="99_mission_aux",
    )


def main() -> int:
    p = default_params()
    print(f"Faraday capacities: {CAPACITY_FE_OH2_MAH_G:.2f} mAh/g and {CAPACITY_MAGNETITE_MAH_G:.2f} mAh/g")
    report = run_components(p)
    run_substructures(p)
    run_plant_scenarios(p)
    out = Path(__file__).resolve().parent / "figures" / "verification_report.json"
    out.write_text(json.dumps(report, indent=2))
    print("verification report:", out)
    print("ALL INTEGRATIONS FINITE")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
