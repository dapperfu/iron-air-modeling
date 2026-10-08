"""Time-varying plant inputs for commissioning through multi-day mission.

@relation(IA-NBK-007, scope=module)
@relation(IA-NBK-008, scope=module)
@relation(IA-NBK-009, scope=module)
"""

from __future__ import annotations

from collections.abc import Mapping

from plant_sim.params import PlantParams, default_params
from plant_sim.plant import MODE_CHARGE, MODE_COMMISSION, MODE_DISCHARGE, MODE_REST


def commissioning_inputs(p: PlantParams | None = None):
    """KOH fill, wetting, rest, then first charge from the grid.

    @relation(IA-NBK-009, scope=function)

    Timeline (verification-scaled seconds; notebooks state the engineering analog):
      0-600 s     dry vessel, residual air O2, fans on
      600-2400 s  KOH make-up fill into anode pores
      2400-3600 s rest / wetting / residual oxygen consumption
      3600-7200 s first charge, P_grid > 0, OER + HER, temperature rise
    """
    p = p or default_params()
    V_fill = p.A_geom_m2 * p.L_anode_m * p.vf_electrolyte_charged

    def u(t: float) -> dict[str, float]:
        if t < 600.0:
            return {"mode": MODE_COMMISSION, "P_grid_W": 0.0, "fill_m3_s": 0.0, "I_fan_A": 0.4, "T_amb_K": p.T_ref_K, "valve_cmd": 0.0}
        if t < 2400.0:
            return {"mode": MODE_COMMISSION, "P_grid_W": 0.0, "fill_m3_s": V_fill / 1800.0, "I_fan_A": 0.3, "T_amb_K": p.T_ref_K, "valve_cmd": 0.4}
        if t < 3600.0:
            return {"mode": MODE_REST, "P_grid_W": 0.0, "fill_m3_s": 0.0, "I_fan_A": 0.2, "T_amb_K": p.T_ref_K, "valve_cmd": 0.5}
        P = 400.0 + 50.0 * (t - 3600.0) / 3600.0
        return {"mode": MODE_CHARGE, "P_grid_W": P, "fill_m3_s": 0.0, "I_fan_A": 1.0, "T_amb_K": p.T_ref_K, "valve_cmd": 0.8, "I_pump_A": 1.8}

    return u


def charge_discharge_inputs(t_chg_s: float, t_dch_s: float, p: PlantParams | None = None):
    """Charge then discharge current/power profile.

    @relation(IA-NBK-007, scope=function)
    @relation(IA-NBK-008, scope=function)
    @relation(IA-SCN-PAT-ASYM, scope=function)
    """
    p = p or default_params()
    I = p.I_discharge_100h_A
    P_chg = abs(I) * 1.7 * p.n_cells_series * p.n_cells_parallel * p.n_stacks
    P_dch = -abs(I) * 1.1 * p.n_cells_series * p.n_cells_parallel * p.n_stacks

    def u(t: float) -> dict[str, float]:
        if t < t_chg_s:
            return {"mode": MODE_CHARGE, "P_grid_W": P_chg, "I_cell_A": -abs(I), "I_fan_A": 1.2, "T_amb_K": p.T_ep_sim_K}
        if t < t_chg_s + 600.0:
            return {"mode": MODE_REST, "P_grid_W": 0.0, "I_cell_A": 0.0, "I_fan_A": 0.2, "T_amb_K": p.T_ep_sim_K}
        if t < t_chg_s + 600.0 + t_dch_s:
            return {"mode": MODE_DISCHARGE, "P_grid_W": P_dch, "I_cell_A": abs(I), "I_fan_A": 1.0, "T_amb_K": p.T_ep_sim_K}
        return {"mode": MODE_REST, "P_grid_W": 0.0, "I_cell_A": 0.0, "I_fan_A": 0.15, "T_amb_K": p.T_ep_sim_K}

    return u


def grid_services_inputs(p: PlantParams | None = None):
    """Curtailment charge, rest, and load-following discharge.

    @relation(IA-NBK-014, scope=function)
    """
    p = p or default_params()

    def u(t: float) -> dict[str, float]:
        # curtailment charge, then discharge to load, then ramp
        cycle = t % 3600.0
        if cycle < 1200.0:
            P = 800.0  # charge from curtailed solar
            mode = MODE_CHARGE
        elif cycle < 1800.0:
            P = 0.0
            mode = MODE_REST
        elif cycle < 3000.0:
            P = -600.0
            mode = MODE_DISCHARGE
        else:
            P = -200.0 - 400.0 * ((cycle - 3000.0) / 600.0)
            mode = MODE_DISCHARGE
        return {"mode": mode, "P_grid_W": P, "I_fan_A": 0.8, "T_amb_K": p.T_ref_K, "Q_ref_var": 50.0 * (1 if cycle > 1800 else 0)}

    return u


def thermal_excursion_inputs(p: PlantParams | None = None):
    """Ambient temperature and coolant-flow excursion.

    @relation(IA-NBK-011, scope=function)
    """
    p = p or default_params()

    def u(t: float) -> dict[str, float]:
        T_amb = 298.15 + 25.0 * min(max((t - 300.0) / 900.0, 0.0), 1.0)
        return {"mode": MODE_DISCHARGE, "P_grid_W": -500.0, "I_cell_A": p.I_discharge_100h_A * 2.0, "T_amb_K": T_amb, "mdot_coolant_kg_s": 0.01 if t < 1500 else 0.08, "I_fan_A": 0.5}

    return u


def starvation_inputs(p: PlantParams | None = None):
    """Air starvation then hydraulic-head flooding.

    @relation(IA-NBK-012, scope=function)
    """
    p = p or default_params()

    def u(t: float) -> dict[str, float]:
        if t < 400.0:
            mdot = 0.003
            head = 0.05
            Ifan = 1.2
        elif t < 1200.0:
            mdot = 1e-5
            head = 0.05
            Ifan = 0.0
        else:
            mdot = 0.001
            head = 0.45
            Ifan = 0.3
        return {
            "mode": MODE_DISCHARGE,
            "P_grid_W": -400.0,
            "I_cell_A": p.I_discharge_100h_A,
            "mdot_air_kg_s": mdot,
            "I_fan_A": Ifan,
            "hydraulic_head_m": head,
            "T_amb_K": p.T_ep_sim_K,
        }

    return u


def carbonation_inputs(p: PlantParams | None = None):
    """Carbonation / impurity air-side stress.

    @relation(IA-NBK-010, scope=function)
    """
    p = p or default_params()

    def u(t: float) -> dict[str, float]:
        return {
            "mode": MODE_DISCHARGE,
            "P_grid_W": -250.0,
            "I_cell_A": 0.5 * p.I_discharge_100h_A,
            "T_amb_K": p.T_ep_sim_K,
            "I_fan_A": 0.9,
        }

    return u


def equal_dp_inputs(p: PlantParams | None = None) -> Mapping[str, float]:
    """US Claim 1 stacked-ORR equal pressure-drop operating point.

    @relation(IA-SCN-PAT-STACKORR, scope=function)
    """
    p = p or default_params()
    return {"mode": MODE_DISCHARGE, "P_grid_W": -300.0, "I_cell_A": p.I_discharge_100h_A, "I_fan_A": 1.0, "T_amb_K": p.T_ep_sim_K}


def full_mission_inputs(p: PlantParams | None = None):
    """Commission -> charge -> idle -> discharge -> rest (multi-segment).

    @relation(IA-NBK-015, scope=function)
    """
    p = p or default_params()
    u_comm = commissioning_inputs(p)

    def u(t: float) -> dict[str, float]:
        if t < 7200.0:
            return u_comm(t)
        if t < 7200.0 + 2400.0:
            return {"mode": MODE_CHARGE, "P_grid_W": 600.0, "I_fan_A": 1.1, "T_amb_K": p.T_ref_K, "valve_cmd": 0.8, "I_pump_A": 1.6}
        if t < 7200.0 + 2400.0 + 1200.0:
            return {"mode": MODE_REST, "P_grid_W": 0.0, "I_fan_A": 0.2, "T_amb_K": p.T_ref_K}
        if t < 7200.0 + 2400.0 + 1200.0 + 2400.0:
            return {"mode": MODE_DISCHARGE, "P_grid_W": -500.0, "I_fan_A": 1.0, "T_amb_K": p.T_ref_K}
        return {"mode": MODE_REST, "P_grid_W": 0.0, "I_fan_A": 0.15, "T_amb_K": p.T_ref_K}

    return u
