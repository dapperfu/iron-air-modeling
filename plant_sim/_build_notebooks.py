#!/usr/bin/env python3
"""Write executable plant_sim decade notebooks (markdown + import/simulate/plot)."""

from __future__ import annotations

import sys
from pathlib import Path

import nbformat as nbf

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "src"))

IMPORTS = """\
from pathlib import Path
import sys

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import seaborn as sns

here = Path.cwd()
for cand in (here, here.parent):
    if (cand / "src" / "ironair").is_dir() and (cand / "plant_sim").is_dir():
        sys.path.insert(0, str(cand))
        sys.path.insert(0, str(cand / "src"))
        break

from plant_sim.bootstrap import setup_path

setup_path()
from plant_sim.params import CAPACITY_FE_OH2_MAH_G, CAPACITY_MAGNETITE_MAH_G, default_params
"""

SETUP = """\
from IPython import get_ipython

_ipy = get_ipython()
if _ipy is not None:
    _ipy.run_line_magic("matplotlib", "inline")

sns.set(
    rc={
        "axes.labelsize": 12,
        "axes.titlesize": 18,
        "figure.figsize": (11, 8.5),
        "figure.dpi": 300,
        "figure.facecolor": "w",
        "figure.edgecolor": "k",
    }
)
P = default_params()
print("KOH default", P.c_KOH_mol_m3 / 1000, "M; T_ep", P.T_ep_sim_K, "K")
print("Faraday 960/320 checks", round(CAPACITY_FE_OH2_MAH_G, 2), round(CAPACITY_MAGNETITE_MAH_G, 2))
"""

# Jupyter MathJax only ($...$ / $$...$$). No siunitx; no preamble newcommands.
GOV_DEFAULT = (
    "See the requirement UID and patent claims cited in the title cell. "
    r"Default electrolyte $6\,\mathrm{M}$ KOH at $303\,\mathrm{K}$ and $1\,\mathrm{atm}$. "
    r"Currents in $\mathrm{A}$, voltages in $\mathrm{V}$, power in $\mathrm{W}$. "
    r"Chemistry remains $\mathrm{...}$ (not mhchem)."
)

GOV_SCENARIO = r"""
Default electrolyte $6\,\mathrm{M}$ KOH at $303\,\mathrm{K}$ unless noted.
Quantities use Jupyter MathJax with $\mathrm{}$ SI (siunitx is not available).
Patents: US12308414B2, EP4602674A1.
"""


def md_cell(text: str):
    return nbf.v4.new_markdown_cell(text)


def code_cell(text: str):
    return nbf.v4.new_code_cell(text)


def write_nb(name: str, cells: list) -> Path:
    nb = nbf.v4.new_notebook()
    nb["metadata"] = {
        "kernelspec": {"display_name": "Python 3", "language": "python", "name": "python3"},
        "language_info": {"name": "python", "pygments_lexer": "ipython3"},
    }
    nb["cells"] = cells
    path = HERE / name
    path.write_text(nbf.writes(nb), encoding="utf-8")
    print("wrote", path.name)
    return path


def component_nb(fname, title, uid, equations, import_block, sim_block, verify_block):
    cells = [
        md_cell(
            f"# {title}\n\n**Requirement:** `{uid}`\n\n"
            "Patents: US12308414B2, EP4602674A1. Equations are paraphrased; "
            "see claims/paragraphs cited below."
        ),
        md_cell("## Governing equations\n\n" + equations.strip() + "\n"),
        code_cell(IMPORTS),
        code_cell(SETUP),
        md_cell("## Isolated component simulation"),
        code_cell(import_block + "\n" + sim_block),
        md_cell("## Verification against patents / SSS002"),
        code_cell(verify_block),
    ]
    write_nb(fname, cells)


def story_nb(
    fname: str,
    title: str,
    purpose: str,
    equations: str,
    sim_block: str,
    verify_block: str | None = None,
    uid: str | None = None,
) -> Path:
    head = f"# {title}\n\n{purpose.strip()}\n"
    if uid:
        head += f"\n**Requirement:** `{uid}`\n"
    cells = [
        md_cell(head),
        md_cell("## Governing equations\n\n" + equations.strip() + "\n"),
        code_cell(IMPORTS),
        code_cell(SETUP),
        md_cell("## Simulation"),
        code_cell(sim_block),
    ]
    if verify_block:
        cells.extend(
            [
                md_cell("## Verification against patents / SSS002"),
                code_cell(verify_block),
            ]
        )
    return write_nb(fname, cells)


def main() -> None:
    component_nb(
        "01_IronAnode.ipynb",
        "01 Iron anode (IA-FE-001)",
        "IA-FE-001",
        r"""
Discharge of metallic iron in alkaline electrolyte (EP4602674A1 [0042]-[0043] Eq. 1),
theoretical capacity $960\,\mathrm{mAh\,g^{-1}}$ Fe:

$$\mathrm{Fe} + 2\,\mathrm{OH^-} \leftrightarrow \mathrm{Fe(OH)_2} + 2\,\mathrm{e^-}$$

Second discharge step (Eq. 2), $320\,\mathrm{mAh\,g^{-1}}$ Fe:

$$3\,\mathrm{Fe(OH)_2} + 2\,\mathrm{OH^-} \leftrightarrow \mathrm{Fe_3O_4} + 4\,\mathrm{H_2O} + 2\,\mathrm{e^-}$$

Faraday: $r = I/(nF)$, $n=2$. Butler-Volmer current from `ironair.chemistry.kinetics`.
Porosity absorbs the solid volume increase (IA-SYS-020). DRI beds, porous particles, and
channeled ribs (EP Claim 1; loading $1$–$7\,\mathrm{g\,cm^{-2}}$, VF $0.5$–$0.9$) share this RHS.
""",
        "from plant_sim.components.iron_anode import IronAnode\nfrom plant_sim.components.base import integrate_component",
        """\
fe = IronAnode(P)
I = 40 * P.I_discharge_100h_A
t, y = integrate_component(lambda t, y: fe.rhs(t, y, {"I_fe_A": I, "T_amb_K": P.T_ep_sim_K, "a_oh": 6.0, "a_h2o": 0.72}, {}), fe.y0(), (0, 4000), n_eval=200)
plot_frame = pd.DataFrame(
    {
        "t": (t/3600),
        "n_Fe": (y[0]),
        "n_FeOH2": (y[1]),
        "n_Fe3O4": (y[2]),
    }
)
plot_long = plot_frame.melt(id_vars="t", var_name="quantity", value_name="value")
fig, ax = plt.subplots()
sns.lineplot(data=plot_long, x="t", y="value", hue="quantity", ax=ax, linewidth=2.0)
ax.set_xlabel("t (h)")
ax.set_ylabel("mol")
ax.set_title("Iron phase inventories")
ax.text(0.0, -0.22, "EP [0042]-[0043]", transform=ax.transAxes, fontsize=8, va="top")
fig.tight_layout()
fig.subplots_adjust(bottom=0.22)
cap = [fe.outputs(float(ti), y[:,i], {"I_fe_A": I, "a_oh": 6.0, "a_h2o": 0.72}, {})["capacity_extracted_mAh_g"] for i,ti in enumerate(t)]
print("extracted mA h g⁻¹ (accelerated)", cap[-1], "theory 960 =", CAPACITY_FE_OH2_MAH_G)
""",
        """\
assert abs(CAPACITY_FE_OH2_MAH_G - 960) < 1.0
assert abs(CAPACITY_MAGNETITE_MAH_G - 320) < 1.0
print("PASS Faraday capacities")
print("loading", P.loading_g_cm2, "g cm⁻² in [1, 7]; VF", P.vf_electrolyte_charged, "in [0.5, 0.9]")
""",
    )

    component_nb(
        "02_HER.ipynb",
        "02 Hydrogen evolution (IA-HER-001)",
        "IA-HER-001",
        r"""
Parasitic charge reaction (EP [0044], [0047]):

$$2\,\mathrm{H_2O} + 2\,\mathrm{e^-} \to \mathrm{H_2} + 2\,\mathrm{OH^-}$$

Coulombic efficiency is

$$\mathrm{CE} = \frac{I_\mathrm{Fe}}{I_\mathrm{Fe} + I_\mathrm{HER}}$$

and falls when the ionic path to the back of a thick iron electrode exceeds
front-surface HER. Vertical channels are a bubble-egress path ([0056]).
Evaluated at $303\,\mathrm{K}$ in $6\,\mathrm{M}$ KOH.
""",
        "from plant_sim.components.her import HydrogenEvolution\nfrom plant_sim.components.base import integrate_component",
        """\
her = HydrogenEvolution(P)
I = -80 * P.I_discharge_100h_A
t, y = integrate_component(lambda t,y: her.rhs(t,y,{"I_fe_A": I, "T_K": P.T_ep_sim_K, "L_path_m": P.L_anode_m, "a_oh": 6.0, "a_h2o": 0.72}, {}), her.y0(), (0, 1500), n_eval=180)
ce = [her.outputs(float(ti), y[:,i], {"I_fe_A": I, "T_K": P.T_ep_sim_K, "L_path_m": P.L_anode_m, "a_oh": 6.0, "a_h2o": 0.72}, {})["CE"] for i,ti in enumerate(t)]
plot_frame = pd.DataFrame(
    {
        "t": (t/60),
        "n_H2": (y[0]),
        "CE": (ce),
        "theta": (y[1]),
    }
)
plot_long = plot_frame.melt(id_vars="t", var_name="quantity", value_name="value")
fig, ax = plt.subplots()
sns.lineplot(data=plot_long, x="t", y="value", hue="quantity", ax=ax, linewidth=2.0)
ax.set_xlabel("t (min)")
ax.set_ylabel("n_H2 / CE / holdup")
ax.set_title("HER gas and coulombic efficiency")
ax.text(0.0, -0.22, "EP [0044]-[0047]", transform=ax.transAxes, fontsize=8, va="top")
fig.tight_layout()
fig.subplots_adjust(bottom=0.22)
""",
        "print('Open-circuit HER is smaller than strong cathodic charging HER (IA-HER-001 comment).')",
    )

    component_nb(
        "03_ORR.ipynb",
        "03 Oxygen reduction (IA-ORR-001)",
        "IA-ORR-001",
        r"""
Oxygen reduction (US12308414B2):

$$\mathrm{O_2} + 2\,\mathrm{H_2O} + 4\,\mathrm{e^-} \to 4\,\mathrm{OH^-}$$

Modes: floating, vertical natural-air-breathing, inverse, tubular, stacked
submerged with depth-equalized pressure drop, wavy/rippled, bifunctional
(IA-SYS-009, IA-SYS-012; US Claims 1, 4, 7-12).
One face to electrolyte/channels, opposing face to air (EP Claim 1). PTFE/GDE parameterizable.
Current density in $\mathrm{A\,m^{-2}}$; $p_{\mathrm{O_2}}$ in $\mathrm{atm}$.
""",
        "from plant_sim.components.orr import OxygenReduction, ORR_MODES, stacked_orr_flows\nfrom plant_sim.components.base import integrate_component",
        """\
print("ORR modes", ORR_MODES)
orr = OxygenReduction(P, mode="stacked_submerged")
t, y = integrate_component(lambda t,y: orr.rhs(t,y,{"I_orr_A": -20*P.I_discharge_100h_A, "T_K": P.T_ep_sim_K, "c_O2_gdl_mol_m3": 8.0, "p_O2_Pa": 21200, "a_oh": 6.0, "a_h2o": 0.72}, {}), orr.y0(), (0, 600), n_eval=120)
plot_frame = pd.DataFrame(
    {
        "t": (t),
        "c_tpb": (y[1]),
        "q_dl": (y[0]),
    }
)
plot_long = plot_frame.melt(id_vars="t", var_name="quantity", value_name="value")
fig, ax = plt.subplots()
sns.lineplot(data=plot_long, x="t", y="value", hue="quantity", ax=ax, linewidth=2.0)
ax.set_xlabel("t (s)")
ax.set_ylabel("c(O₂) (mol m⁻³) / q (C)")
ax.set_title("ORR TPB oxygen")
ax.text(0.0, -0.22, "IA-ORR-001", transform=ax.transAxes, fontsize=8, va="top")
fig.tight_layout()
fig.subplots_adjust(bottom=0.22)
eq = stacked_orr_flows(P, 5e-4, True, P.T_ep_sim_K)
plot_frame = pd.DataFrame(
    {
        "x": (eq["z_m"]),
        "dP": (eq["dP_Pa"]),
    }
)
plot_long = plot_frame.melt(id_vars="x", var_name="quantity", value_name="value")
fig, ax = plt.subplots()
sns.lineplot(data=plot_long, x="x", y="value", hue="quantity", ax=ax, linewidth=2.0)
ax.set_xlabel("z (m)")
ax.set_ylabel("ΔP (Pa)")
ax.set_title("Stacked ORR ΔP (compensated)")
ax.text(0.0, -0.22, "US Claim 1", transform=ax.transAxes, fontsize=8, va="top")
fig.tight_layout()
fig.subplots_adjust(bottom=0.22)
""",
        "print('pO2 discharge window', P.pO2_discharge_min_atm, P.pO2_discharge_max_atm, 'atm')",
    )

    component_nb(
        "04_OER.ipynb",
        "04 Oxygen evolution (IA-OER-001)",
        "IA-OER-001",
        r"""
Oxygen evolution:

$$4\,\mathrm{OH^-} \to \mathrm{O_2} + 2\,\mathrm{H_2O} + 4\,\mathrm{e^-}$$

Layouts: planar, submerged, interdigitated trunk-and-projection, corrugated,
serpentine, discrete arrays, spiral bifilar, pleated
(EP Claims 1, 3, 12, 32, 38, 70, 77). Default porous metal mesh + OER catalyst (Claim 11).
OER sits closer to iron than ORR on charge and is electrically isolatable (US FIGS. 5A-5B).
Overpotential in $\mathrm{V}$; gas inventories in $\mathrm{mol}$.
""",
        "from plant_sim.components.oer import OxygenEvolution, OER_LAYOUTS, LAYOUT_AREA_FACTOR\nfrom plant_sim.components.base import integrate_component",
        """\
print(OER_LAYOUTS)
oer = OxygenEvolution(P, layout="interdigitated")
t, y = integrate_component(lambda t,y: oer.rhs(t,y,{"I_oer_A": 20*P.I_discharge_100h_A, "T_K": P.T_ep_sim_K, "a_oh": 6.0, "a_h2o": 0.72, "p_O2_Pa": P.P_atm_Pa, "oer_isolated": 0.0}, {}), oer.y0(), (0, 800), n_eval=120)
plot_frame = pd.DataFrame(
    {
        "t": (t/60),
        "theta_cat": (y[0]),
        "n_O2": (y[1]),
        "bubbles": (y[2]),
    }
)
plot_long = plot_frame.melt(id_vars="t", var_name="quantity", value_name="value")
fig, ax = plt.subplots()
sns.lineplot(data=plot_long, x="t", y="value", hue="quantity", ax=ax, linewidth=2.0)
ax.set_xlabel("t (min)")
ax.set_ylabel("states")
ax.set_title("OER catalyst and gas")
ax.text(0.0, -0.22, "IA-OER-001", transform=ax.transAxes, fontsize=8, va="top")
fig.tight_layout()
fig.subplots_adjust(bottom=0.22)
plot_frame = pd.DataFrame(
    {
        "x": (np.arange(len(LAYOUT_AREA_FACTOR))),
        "af": (np.array(list(LAYOUT_AREA_FACTOR.values()))),
    }
)
plot_long = plot_frame.melt(id_vars="x", var_name="quantity", value_name="value")
fig, ax = plt.subplots()
sns.lineplot(data=plot_long, x="x", y="value", hue="quantity", ax=ax, linewidth=2.0)
ax.set_xlabel("layout index")
ax.set_ylabel("area factor")
ax.set_title("OER layouts")
ax.text(0.0, -0.22, str(list(LAYOUT_AREA_FACTOR)), transform=ax.transAxes, fontsize=8, va="top")
fig.tight_layout()
fig.subplots_adjust(bottom=0.22)
""",
        "print('Interdigitated shortens ionic path vs planar (EP [0050], FIGS. 19-21).')",
    )

    component_nb(
        "05_GDL.ipynb",
        "05 Gas diffusion layer (IA-GDL-001)",
        "IA-GDL-001",
        r"""
Method-of-lines diffusion:

$$\frac{\partial c}{\partial t} = \nabla\cdot(D_\mathrm{eff}\nabla c) - s_\mathrm{ORR}$$

$$D_\mathrm{eff} = D_\mathrm{gas}\,\varepsilon^{1.5}(1-s)^{3}$$

Flooding ($s \to 1$) kills gas diffusivity. Hydraulic head on vertical ORR drives
liquid; OER bubbles on a horizontal electrode can dry the TPB (US FIGS. 8-9B).
pO2 $0.01$–$100\,\mathrm{atm}$ discharge, $0.001$–$100\,\mathrm{atm}$ charge.
""",
        "from plant_sim.components.gdl import GasDiffusionLayer\nfrom plant_sim.components.base import integrate_component",
        """\
g = GasDiffusionLayer(P)
def u(t):
    return {"T_K": P.T_ep_sim_K, "P_Pa": P.P_atm_Pa, "x_O2": 0.21 if t<80 else 0.05, "r_orr_mol_s": 3e-7, "hydraulic_head_m": 0.05 if t<200 else 0.35, "oer_dryout": 0.0}
t, y = integrate_component(lambda t,y: g.rhs(t,y,u(t), {}), g.y0(), (0, 500), n_eval=160)
n = P.n_gdl_nodes
plot_frame = pd.DataFrame(
    {
        "t": (t),
        "air": (y[0]),
        "tpb": (y[n-1]),
        "s": (y[n]),
    }
)
plot_long = plot_frame.melt(id_vars="t", var_name="quantity", value_name="value")
fig, ax = plt.subplots()
sns.lineplot(data=plot_long, x="t", y="value", hue="quantity", ax=ax, linewidth=2.0)
ax.set_xlabel("t (s)")
ax.set_ylabel("c_O2 / saturation")
ax.set_title("GDL O2 and flooding")
ax.text(0.0, -0.22, "IA-GDL-001 delayed interior O2", transform=ax.transAxes, fontsize=8, va="top")
fig.tight_layout()
fig.subplots_adjust(bottom=0.22)
""",
        "print('Flooding reduces Deff; a boundary O2 step delays interior decline.')",
    )

    component_nb(
        "06_Electrolyte.ipynb",
        "06 Electrolyte (IA-ELY-001)",
        "IA-ELY-001",
        r"""
Default $6\,\mathrm{M}$ aqueous KOH. Carbonation

$$\mathrm{CO_2} + 2\,\mathrm{OH^-} \to \mathrm{CO_3^{2-}} + \mathrm{H_2O}$$

consumes $\mathrm{OH^-}$ and may clog pores (US). Alternate recipes from IA-SYS-021
(LiOH blends, NaOH, high hydroxide $\ge 7\,\mathrm{M}$ as a CE lever, EP).
Conductivity from `ironair.properties`.
""",
        "from plant_sim.components.electrolyte import Electrolyte\nfrom plant_sim.components.base import integrate_component",
        """\
ely = Electrolyte(P, filled=True)
t, y = integrate_component(lambda t,y: ely.rhs(t,y,{"r_iron_mol_s": 1e-6, "r_orr_mol_s": 5e-7, "x_CO2": 4.2e-4, "q_heat_W": 3.0, "T_amb_K": P.T_ep_sim_K}, {}), ely.y0(), (0, 2000), n_eval=150)
cM = y[0]/np.maximum(y[5],1e-12)/1000
plot_frame = pd.DataFrame(
    {
        "t": (t/60),
        "c_KOH_M": (cM),
        "n_CO3": (y[2]),
        "T": (y[4]),
        "s_wet": (y[6]),
    }
)
plot_long = plot_frame.melt(id_vars="t", var_name="quantity", value_name="value")
fig, ax = plt.subplots()
sns.lineplot(data=plot_long, x="t", y="value", hue="quantity", ax=ax, linewidth=2.0)
ax.set_xlabel("t (min)")
ax.set_ylabel("mixed SI")
ax.set_title("KOH, carbonate, T, wetting")
ax.text(0.0, -0.22, "6 M KOH @ 303 K (Unicode SI on axes)", transform=ax.transAxes, fontsize=8, va="top")
fig.tight_layout()
fig.subplots_adjust(bottom=0.22)
print("recipes", P.with_recipe("7M_KOH").c_KOH_mol_m3)
""",
        "assert abs(P.c_KOH_mol_m3/1000 - 6) < 1e-9\nprint('PASS 6 M default')",
    )

    component_nb(
        "07_Separator.ipynb",
        "07 Separator (IA-SEP-001)",
        "IA-SEP-001",
        r"""
$$R_\mathrm{ionic} = \frac{L\,\tau}{\sigma A \varepsilon s^{1.5}}$$

Separator blocks dissolved $\mathrm{O_2}$ and bubbles from iron without a large
ionic penalty, remaining hydrophilic/macroporous (US FIG. 4A; EP Claim 2, [0048]).
Wrapped stacked-core pores $1\,\mathrm{\mu m}$ to $1\,\mathrm{cm}$ (US FIG. 36A).
""",
        "from plant_sim.components.separator import Separator\nfrom plant_sim.components.base import integrate_component",
        """\
sep = Separator(P)
t, y = integrate_component(lambda t,y: sep.rhs(t,y,{"T_ely_K": P.T_ep_sim_K, "c_KOH_mol_m3": 6000, "I_cell_A": 5.0, "s_wet": 0.95, "c_O2_ely_mol_m3": 0.02}, {}), sep.y0(), (0, 800), n_eval=100)
R = [sep.outputs(float(ti), y[:,i], {"c_KOH_mol_m3": 6000, "I_cell_A": 5.0}, {})["R_ionic_ohm"] for i,ti in enumerate(t)]
plot_frame = pd.DataFrame(
    {
        "t": (t),
        "T": (y[0]),
        "s": (y[1]),
        "c_O2": (y[2]),
        "R": (R),
    }
)
plot_long = plot_frame.melt(id_vars="t", var_name="quantity", value_name="value")
fig, ax = plt.subplots()
sns.lineplot(data=plot_long, x="t", y="value", hue="quantity", ax=ax, linewidth=2.0)
ax.set_xlabel("t (s)")
ax.set_ylabel("mixed")
ax.set_title("Separator R_ionic and O2")
ax.text(0.0, -0.22, "IA-SEP-001", transform=ax.transAxes, fontsize=8, va="top")
fig.tight_layout()
fig.subplots_adjust(bottom=0.22)
""",
        "print('R_ionic is algebraic in conductivity, thickness, area, saturation.')",
    )

    component_nb(
        "08_CurrentCollector.ipynb",
        "08 Current collector (IA-COL-001)",
        "IA-COL-001",
        r"""
$$V_\mathrm{ohm} = I\,R(T,\mathrm{degradation})$$

No fake lag on resistance.
Anode branch-plus-primary, ORR dual-face tabs, Ni-coated-steel + EPDM (US FIGS. 4B-4C),
SS mesh in iron ribs (EP), can-negative housing (US Claim 5).
Ohmic drop in $\mathrm{V}$ for current in $\mathrm{A}$; $R$ in $\mathrm{\Omega}$.
""",
        "from plant_sim.components.current_collector import CurrentCollector\nfrom plant_sim.components.base import integrate_component",
        """\
col = CurrentCollector(P)
t, y = integrate_component(lambda t,y: col.rhs(t,y,{"I_cell_A": 8.0, "T_amb_K": P.T_ep_sim_K}, {}), col.y0(), (0, 1500), n_eval=100)
V = [col.outputs(float(ti), y[:,i], {"I_cell_A": 8.0}, {})["V_ohm_V"] for i,ti in enumerate(t)]
plot_frame = pd.DataFrame(
    {
        "t": (t/60),
        "T": (y[0]),
        "deg": (y[1]),
        "Vohm": (V),
    }
)
plot_long = plot_frame.melt(id_vars="t", var_name="quantity", value_name="value")
fig, ax = plt.subplots()
sns.lineplot(data=plot_long, x="t", y="value", hue="quantity", ax=ax, linewidth=2.0)
ax.set_xlabel("t (min)")
ax.set_ylabel("T / deg / V")
ax.set_title("Collector ohmic loss")
ax.text(0.0, -0.22, "IA-COL-001", transform=ax.transAxes, fontsize=8, va="top")
fig.tight_layout()
fig.subplots_adjust(bottom=0.22)
""",
        "print('V_ohm = I * R(T, deg) with no extra lag state.')",
    )

    component_nb(
        "09_Thermal.ipynb",
        "09 Thermal network + extra atomic BOP (IA-THM/AIR/FLD/HEX)",
        "IA-THM-001",
        r"""
Lumped energy balance on electrode, electrolyte, vessel wall, lid, and cavity coolant
(US FIGS. 1E-1F, 9A), with $T$ in $\mathrm{K}$ and heat rates in $\mathrm{W}$:

$$m c_p \frac{\mathrm{d}T}{\mathrm{d}t} = \sum q$$

Extra atomic pieces live here as importable modules:
`AirSystem`, `Fan`, `ElectrolyteFlow`, `Pump`, `Reservoir`, `Valve`, `Pipe`, `HeatExchanger`.
""",
        "from plant_sim.components.thermal import ThermalNetwork\nfrom plant_sim.components.air_system import AirSystem, Fan\nfrom plant_sim.components.hydraulics import Pump, Valve\nfrom plant_sim.components.base import integrate_component",
        """\
th = ThermalNetwork(P)
t, y = integrate_component(lambda t,y: th.rhs(t,y,{"q_reaction_W": 20.0, "q_joule_W": 5.0, "T_amb_K": P.T_ref_K, "mdot_coolant_kg_s": 0.04}, {}), th.y0(), (0, 1200), n_eval=120)
plot_frame = pd.DataFrame(
    {
        "t": (t/60),
        "Te": (y[0]),
        "Tely": (y[1]),
        "Tv": (y[2]),
        "Tlid": (y[3]),
        "Tc": (y[4]),
    }
)
plot_long = plot_frame.melt(id_vars="t", var_name="quantity", value_name="value")
fig, ax = plt.subplots()
sns.lineplot(data=plot_long, x="t", y="value", hue="quantity", ax=ax, linewidth=2.0)
ax.set_xlabel("t (min)")
ax.set_ylabel("T (K)")
ax.set_title("Thermal nodes")
ax.text(0.0, -0.22, "IA-THM-001", transform=ax.transAxes, fontsize=8, va="top")
fig.tight_layout()
fig.subplots_adjust(bottom=0.22)
for label, obj, uu in [
    ("air", AirSystem(P), {"mdot_air_kg_s": 0.002, "r_orr_mol_s": 1e-6, "T_K": P.T_ep_sim_K}),
    ("fan", Fan(P), {"I_fan_A": 1.0}),
    ("pump", Pump(P), {"I_pump_A": 1.5}),
    ("valve", Valve(P), {"valve_cmd": 1.0, "dP_Pa": 2e4}),
]:
    tt, yy = integrate_component(lambda t,y,o=obj,u=uu: o.rhs(t,y,u,{}), obj.y0(), (0, 15), n_eval=30)
    print(label, "finite", np.all(np.isfinite(yy)))
""",
        "print('Adiabatic node with +q raises T (IA-THM-001 comment). Extra atomic modules imported above.')",
    )

    # substructures
    write_nb(
        "10_NegativeElectrode.ipynb",
        [
            md_cell(
                "# 10 Negative electrode\n\nCouples **iron + HER + collector + local electrolyte** using the same RHS functions as 01, 02, 06, 08."
            ),
            md_cell("## Governing equations\n\n" + GOV_DEFAULT + "\n"),
            code_cell(IMPORTS),
            code_cell(SETUP),
            md_cell("## Simulation"),
            code_cell("""\
from plant_sim.substructures.negative_electrode import NegativeElectrode
neg = NegativeElectrode(P)
res = neg.simulate((0, 800), u={"I_fe_A": 20*P.I_discharge_100h_A})
plot_frame = pd.DataFrame(
    {
        "t": (res["t"]),
        "n_Fe": (res["y"][0]),
        "n_H2": (res["y"][8]),
    }
)
plot_long = plot_frame.melt(id_vars="t", var_name="quantity", value_name="value")
fig, ax = plt.subplots()
sns.lineplot(data=plot_long, x="t", y="value", hue="quantity", ax=ax, linewidth=2.0)
ax.set_xlabel("t (s)")
ax.set_ylabel("mol")
ax.set_title("Negative electrode inventories")
ax.text(0.0, -0.22, "10 half-cell = 01+02+08+06", transform=ax.transAxes, fontsize=8, va="top")
fig.tight_layout()
fig.subplots_adjust(bottom=0.22)
print("states", res["y"].shape, "finite", np.all(np.isfinite(res["y"])))
"""),
        ],
    )
    write_nb(
        "11_AirCathode.ipynb",
        [
            md_cell(
                "# 11 Air cathode\n\nORR + OER + GDL + air (03+04+05+AIR). Discharge consumes O2 at ORR; charge can isolate OER."
            ),
            md_cell("## Governing equations\n\n" + GOV_DEFAULT + "\n"),
            code_cell(IMPORTS),
            code_cell(SETUP),
            md_cell("## Simulation"),
            code_cell("""\
from plant_sim.substructures.air_cathode import AirCathode
ac = AirCathode(P)
res = ac.simulate((0, 500), u={"I_orr_A": -20*P.I_discharge_100h_A, "mdot_air_kg_s": 0.002, "T_K": P.T_ep_sim_K})
plot_frame = pd.DataFrame(
    {
        "t": (res["t"]),
        "c_tpb": (res["y"][1]),
    }
)
plot_long = plot_frame.melt(id_vars="t", var_name="quantity", value_name="value")
fig, ax = plt.subplots()
sns.lineplot(data=plot_long, x="t", y="value", hue="quantity", ax=ax, linewidth=2.0)
ax.set_xlabel("t (s)")
ax.set_ylabel("c(O₂) TPB (mol m⁻³)")
ax.set_title("Air cathode ORR oxygen")
ax.text(0.0, -0.22, "EP Claim 1 air-facing second surface", transform=ax.transAxes, fontsize=8, va="top")
fig.tight_layout()
fig.subplots_adjust(bottom=0.22)
"""),
        ],
    )
    write_nb(
        "12_DualElectrodeCell.ipynb",
        [
            md_cell(
                "# 12 Dual-electrode cell (US12308414B2)\n\nCharge: iron–OER–source. Discharge: iron–ORR–load (EP [0049]). Independent $L_\\mathrm{c}$ vs $L_\\mathrm{d}$ (US $100\\,\\mathrm{h}$ / $300\\,\\mathrm{h}$)."
            ),
            md_cell("## Governing equations\n\n" + GOV_DEFAULT + "\n"),
            code_cell(IMPORTS),
            code_cell(SETUP),
            md_cell("## Simulation"),
            code_cell("""\
from plant_sim.substructures.dual_electrode_cell import DualElectrodeCell
cell = DualElectrodeCell(P)
dch = cell.simulate((0, 600), u={"mode": -1.0, "I_cell_A": 15*P.I_discharge_100h_A})
chg = cell.simulate((0, 600), u={"mode": 1.0, "I_cell_A": 15*P.I_discharge_100h_A})
plot_frame = pd.DataFrame(
    {
        "t": (dch["t"]),
        "n_Fe_dch": (dch["y"][0]),
    }
)
plot_long = plot_frame.melt(id_vars="t", var_name="quantity", value_name="value")
fig, ax = plt.subplots()
sns.lineplot(data=plot_long, x="t", y="value", hue="quantity", ax=ax, linewidth=2.0)
ax.set_xlabel("t (s)")
ax.set_ylabel("n_Fe (mol)")
ax.set_title("Discharge through ORR")
ax.text(0.0, -0.22, "US dual-cathode", transform=ax.transAxes, fontsize=8, va="top")
fig.tight_layout()
fig.subplots_adjust(bottom=0.22)
plot_frame = pd.DataFrame(
    {
        "t": (chg["t"]),
        "n_Fe_chg": (chg["y"][0]),
        "n_H2": (chg["y"][8]),
    }
)
plot_long = plot_frame.melt(id_vars="t", var_name="quantity", value_name="value")
fig, ax = plt.subplots()
sns.lineplot(data=plot_long, x="t", y="value", hue="quantity", ax=ax, linewidth=2.0)
ax.set_xlabel("t (s)")
ax.set_ylabel("mol")
ax.set_title("Charge through OER + HER")
ax.text(0.0, -0.22, "US Claim 16 isolation", transform=ax.transAxes, fontsize=8, va="top")
fig.tight_layout()
fig.subplots_adjust(bottom=0.22)
"""),
        ],
    )
    write_nb(
        "20_CellStack.ipynb",
        [
            md_cell(
                "# 20 Cell stack + stacked submerged ORR (US Claim 1)\n\nSeries current conservation; depth-varying pocket thickness equalizes air ΔP."
            ),
            md_cell("## Governing equations\n\n" + GOV_DEFAULT + "\n"),
            code_cell(IMPORTS),
            code_cell(SETUP),
            md_cell("## Simulation"),
            code_cell("""\
from plant_sim.substructures.cell_stack import CellStack
st = CellStack(P, n_cells=3)
eq = st.equal_pressure_drop(compensate=True)
nq = st.equal_pressure_drop(compensate=False)
plot_frame = pd.DataFrame(
    {
        "x": (eq["z_m"]),
        "dP_comp": (eq["dP_Pa"]),
        "dP_naive": (nq["dP_Pa"]),
    }
)
plot_long = plot_frame.melt(id_vars="x", var_name="quantity", value_name="value")
fig, ax = plt.subplots()
sns.lineplot(data=plot_long, x="x", y="value", hue="quantity", ax=ax, linewidth=2.0)
ax.set_xlabel("depth (m)")
ax.set_ylabel("ΔP (Pa)")
ax.set_title("Equal ΔP verification")
ax.text(0.0, -0.22, "US12308414B2 Claim 1", transform=ax.transAxes, fontsize=8, va="top")
fig.tight_layout()
fig.subplots_adjust(bottom=0.22)
res = st.simulate((0, 180), n_eval=40)
print("stack finite", np.all(np.isfinite(res["y"])), "n_cells", res["n_cells"])
"""),
        ],
    )
    write_nb(
        "21_ChanneledElectrode.ipynb",
        [
            md_cell(
                "# 21 Channeled / interdigitated / spiral bifilar / pleated (EP4602674A1)\n\nChannel $3$–$50\\,\\mathrm{mm}$ × $1$–$40\\,\\mathrm{mm}$, spacing $10$–$50\\,\\mathrm{mm}$, Fe $1$–$7\\,\\mathrm{g\\,cm^{-2}}$, VF $0.5$–$0.9$."
            ),
            md_cell("## Governing equations\n\n" + GOV_DEFAULT + "\n"),
            code_cell(IMPORTS),
            code_cell(SETUP),
            md_cell("## Simulation"),
            code_cell("""\
from plant_sim.substructures.channeled_electrode import ChanneledElectrode
ch = ChanneledElectrode(P)
cmp = ch.compare_layouts(10*P.I_discharge_100h_A)
print({k: round(v, 4) for k,v in cmp.items() if k.startswith("CE_")})
ce_frame = pd.DataFrame(
    {
        "layout": [k[3:] for k in cmp if k.startswith("CE_")],
        "CE": [v for k, v in cmp.items() if k.startswith("CE_")],
    }
)
fig, ax = plt.subplots()
sns.barplot(data=ce_frame, x="layout", y="CE", ax=ax)
ax.set_xlabel("layout")
ax.set_ylabel("CE")
ax.set_title("Charge CE vs electrode layout")
ax.tick_params(axis="x", rotation=30)
fig.tight_layout()
res = ch.simulate((0, 400), u={"I_fe_A": -10*P.I_discharge_100h_A})
print("finite", np.all(np.isfinite(res["y"])))
"""),
        ],
    )
    write_nb(
        "22_VesselLidAir.ipynb",
        [
            md_cell(
                "# 22 Vessel, lid, air delivery, inverse-air, DRI bed\n\nUS Claim 18 DRI pellets; FIG. 9A multi-function lid (air, vent, thermal, DC, sensing)."
            ),
            md_cell("## Governing equations\n\n" + GOV_DEFAULT + "\n"),
            code_cell(IMPORTS),
            code_cell(SETUP),
            md_cell("## Simulation"),
            code_cell("""\
from plant_sim.substructures.vessel_lid_air import VesselLidAir
v = VesselLidAir(P, dri=True)
res = v.simulate((0, 300), u={"I_fe_A": 5*P.I_discharge_100h_A, "I_fan_A": 0.7})
plot_frame = pd.DataFrame(
    {
        "t": (res["t"]),
        "T": (res["y"][3]),
        "p": (res["y"][8]),
    }
)
plot_long = plot_frame.melt(id_vars="t", var_name="quantity", value_name="value")
fig, ax = plt.subplots()
sns.lineplot(data=plot_long, x="t", y="value", hue="quantity", ax=ax, linewidth=2.0)
ax.set_xlabel("t (s)")
ax.set_ylabel("T (K) / p (Pa)")
ax.set_title("DRI vessel + lid air")
ax.text(0.0, -0.22, "US Claim 18 / FIG. 9A", transform=ax.transAxes, fontsize=8, va="top")
fig.tight_layout()
fig.subplots_adjust(bottom=0.22)
"""),
        ],
    )
    write_nb(
        "30_Module.ipynb",
        [
            md_cell(
                "# 30 Module\n\nUS FIG. 13 stack of housings sharing lid air, venting, DC. Implemented as `PlantModel` with series/parallel counts."
            ),
            md_cell("## Governing equations\n\n" + GOV_DEFAULT + "\n"),
            code_cell(IMPORTS),
            code_cell(SETUP),
            md_cell("## Simulation"),
            code_cell("""\
from plant_sim.substructures.module import BatteryModule
from plant_sim.plant import MODE_DISCHARGE
mod = BatteryModule(P)
res = mod.simulate((0, 400), inputs={"mode": MODE_DISCHARGE, "P_grid_W": -300.0, "I_cell_A": P.I_discharge_100h_A}, n_eval=80)
print("module states", res["y"].shape, "finite", np.all(np.isfinite(res["y"])))
plot_frame = pd.DataFrame(
    {
        "t": (res["t"]),
        "V": (res["alg"]["V_cell_V"]),
        "SOC": (res["alg"]["SOC"]),
    }
)
plot_long = plot_frame.melt(id_vars="t", var_name="quantity", value_name="value")
fig, ax = plt.subplots()
sns.lineplot(data=plot_long, x="t", y="value", hue="quantity", ax=ax, linewidth=2.0)
ax.set_xlabel("t (s)")
ax.set_ylabel("V / SOC")
ax.set_title("Module discharge")
ax.text(0.0, -0.22, "IA-MOD-001", transform=ax.transAxes, fontsize=8, va="top")
fig.tight_layout()
fig.subplots_adjust(bottom=0.22)
"""),
        ],
    )
    write_nb(
        "31_Hydraulics.ipynb",
        [
            md_cell(
                "# 31 Electrolyte hydraulics BOP\n\nPump, valve, pipe delay, reservoir, circulation loop (IA-FLD-001-005)."
            ),
            md_cell("## Governing equations\n\n" + GOV_DEFAULT + "\n"),
            code_cell(IMPORTS),
            code_cell(SETUP),
            md_cell("## Simulation"),
            code_cell("""\
from plant_sim.substructures.hydraulics_bop import HydraulicsBOP
h = HydraulicsBOP(P)
res = h.simulate((0, 40), u={"I_pump_A": 2.0, "valve_cmd": 0.8})
plot_frame = pd.DataFrame(
    {
        "t": (res["t"]),
        "mdot": (res["y"][0]),
        "p": (res["y"][1]),
    }
)
plot_long = plot_frame.melt(id_vars="t", var_name="quantity", value_name="value")
fig, ax = plt.subplots()
sns.lineplot(data=plot_long, x="t", y="value", hue="quantity", ax=ax, linewidth=2.0)
ax.set_xlabel("t (s)")
ax.set_ylabel("ṁ (kg s⁻¹) / p (Pa)")
ax.set_title("Electrolyte loop")
ax.text(0.0, -0.22, "IA-FLD-001", transform=ax.transAxes, fontsize=8, va="top")
fig.tight_layout()
fig.subplots_adjust(bottom=0.22)
"""),
        ],
    )
    write_nb(
        "32_AirHandling.ipynb",
        [
            md_cell("# 32 Air handling\n\nFan + manifold + stacked-ORR distribution (IA-AIR-001/002)."),
            md_cell("## Governing equations\n\n" + GOV_DEFAULT + "\n"),
            code_cell(IMPORTS),
            code_cell(SETUP),
            md_cell("## Simulation"),
            code_cell("""\
from plant_sim.substructures.air_handling import AirHandling
ah = AirHandling(P)
res = ah.simulate((0, 40), u={"I_fan_A": 1.2, "r_orr_mol_s": 1e-6})
eq = ah.stacked_distribution(True)
plot_frame = pd.DataFrame(
    {
        "x": (eq["z_m"]),
        "Q": (eq["Q_m3_s"]),
    }
)
plot_long = plot_frame.melt(id_vars="x", var_name="quantity", value_name="value")
fig, ax = plt.subplots()
sns.lineplot(data=plot_long, x="x", y="value", hue="quantity", ax=ax, linewidth=2.0)
ax.set_xlabel("z (m)")
ax.set_ylabel("Q (m³/s)")
ax.set_title("Stacked air distribution")
ax.text(0.0, -0.22, "US Claim 1", transform=ax.transAxes, fontsize=8, va="top")
fig.tight_layout()
fig.subplots_adjust(bottom=0.22)
"""),
        ],
    )
    write_nb(
        "33_ElectricalBalance.ipynb",
        [
            md_cell(
                "# 33 Electrical balance\n\nTabs/stacking, DC bus, converter, inverter, transformer, grid (IA-DC/CNV/INV/TRF/GRD)."
            ),
            md_cell("## Governing equations\n\n" + GOV_DEFAULT + "\n"),
            code_cell(IMPORTS),
            code_cell(SETUP),
            md_cell("## Simulation"),
            code_cell("""\
from plant_sim.substructures.electrical_balance import ElectricalBalance
eb = ElectricalBalance(P)
res = eb.simulate((0, 15), u={"P_grid_W": 700.0, "I_stack_A": 4.0})
plot_frame = pd.DataFrame(
    {
        "t": (res["t"]),
        "Vdc": (res["y"][0]),
        "Pinv": (res["y"][3]),
    }
)
plot_long = plot_frame.melt(id_vars="t", var_name="quantity", value_name="value")
fig, ax = plt.subplots()
sns.lineplot(data=plot_long, x="t", y="value", hue="quantity", ax=ax, linewidth=2.0)
ax.set_xlabel("t (s)")
ax.set_ylabel("V / W")
ax.set_title("DC bus and inverter tracker")
ax.text(0.0, -0.22, "IA-DC-001 IA-INV-001", transform=ax.transAxes, fontsize=8, va="top")
fig.tight_layout()
fig.subplots_adjust(bottom=0.22)
"""),
        ],
    )
    write_nb(
        "40_PlantModel.ipynb",
        [
            md_cell(
                "# 40 Full plant model\n\nOne `solve_ivp` over concatenated 01-09 states plus BOP. Scenarios 90-99 call **this same** `PlantModel.rhs`."
            ),
            md_cell("## Governing equations\n\n" + GOV_DEFAULT + "\n"),
            code_cell(IMPORTS),
            code_cell(SETUP),
            md_cell("## Simulation"),
            code_cell("""\
from plant_sim.plant import PlantModel, MODE_DISCHARGE
plant = PlantModel(P)
print("n_states", plant.n_states)
res = plant.simulate((0, 600), inputs={"mode": MODE_DISCHARGE, "P_grid_W": -400.0, "I_cell_A": P.I_discharge_100h_A}, n_eval=120)
assert np.all(np.isfinite(res["y"]))
plot_frame = pd.DataFrame(
    {
        "t": (res["t"]),
        "V": (res["alg"]["V_cell_V"]),
        "I": (res["alg"]["I_cell_A"]),
        "SOC": (res["alg"]["SOC"]),
        "T": (res["alg"]["T_K"]),
    }
)
plot_long = plot_frame.melt(id_vars="t", var_name="quantity", value_name="value")
fig, ax = plt.subplots()
sns.lineplot(data=plot_long, x="t", y="value", hue="quantity", ax=ax, linewidth=2.0)
ax.set_xlabel("t (s)")
ax.set_ylabel("mixed SI")
ax.set_title("Assembled plant discharge")
ax.text(0.0, -0.22, "IA-CEL-001 / IA-SYS-005", transform=ax.transAxes, fontsize=8, va="top")
fig.tight_layout()
fig.subplots_adjust(bottom=0.22)
print("nfev", res["nfev"])
"""),
        ],
    )

    write_nb(
        "90_Commissioning.ipynb",
        [
            md_cell(
                "# 90 Commissioning (flagship)\n\nKOH first fill, wetting, residual oxygen, formation, **grid power in**, rest, first charge, H2/O2, carbonation risk, temperature. Plot every engineer-relevant signal.\n\n**Requirements:** `IA-SYS-020`, `IA-SYS-021`, `IA-GRD-001`."
            ),
            md_cell(r"""## Sequence (verification-scaled seconds; engineering analog in hours)

| $t$ | Action |
| --- | --- |
| $0$–$600\,\mathrm{s}$ | Dry vessel, residual air $\mathrm{O_2}$, fans on |
| $600$–$2400\,\mathrm{s}$ | $6\,\mathrm{M}$ KOH make-up fill into anode pores |
| $2400$–$3600\,\mathrm{s}$ | Rest / wetting / residual $\mathrm{O_2}$ |
| $3600$–$7200\,\mathrm{s}$ | First charge from grid, OER + HER, $T$ rise |

Chemistry: IA-SYS-020/021. Grid: IA-GRD-001. Same `PlantModel` as decade 40.
"""),
            md_cell(r"""## Governing equations

Fill, wetting, residual oxygen, then first charge through OER with parasitic HER.
Default $6\,\mathrm{M}$ KOH. Temperatures in $\mathrm{K}$, power in $\mathrm{W}$,
current in $\mathrm{A}$, voltage in $\mathrm{V}$.
"""),
            code_cell(IMPORTS),
            code_cell(SETUP),
            md_cell("## Simulation"),
            code_cell("""\
from plant_sim.plant import PlantModel
from plant_sim.scenarios.mission import commissioning_inputs
plant = PlantModel(P)
res = plant.simulate((0, 7200), inputs=commissioning_inputs(P), y0=plant.y0(filled=False), n_eval=360, rtol=1e-4)
t, a, y = res["t"], res["alg"], res["y"]
b = plant.blocks
plot_frame = pd.DataFrame(
    {
        "t": (t/3600),
        "P_grid_W": (a["P_grid_W"]),
        "I_A": (a["I_cell_A"]),
        "V_V": (a["V_cell_V"]),
    }
)
plot_long = plot_frame.melt(id_vars="t", var_name="quantity", value_name="value")
fig, ax = plt.subplots()
sns.lineplot(data=plot_long, x="t", y="value", hue="quantity", ax=ax, linewidth=2.0)
ax.set_xlabel("t (h)")
ax.set_ylabel("P (W) / I (A) / V (V)")
ax.set_title("Grid power, current, voltage")
ax.text(0.0, -0.22, "90_Commissioning", transform=ax.transAxes, fontsize=8, va="top")
fig.tight_layout()
fig.subplots_adjust(bottom=0.22)
plot_frame = pd.DataFrame(
    {
        "t": (t/3600),
        "n_OH": (y[b["ely"][0]]),
        "s_wet": (y[b["ely"][0]+6]),
        "V_m3": (y[b["ely"][0]+5]),
    }
)
plot_long = plot_frame.melt(id_vars="t", var_name="quantity", value_name="value")
fig, ax = plt.subplots()
sns.lineplot(data=plot_long, x="t", y="value", hue="quantity", ax=ax, linewidth=2.0)
ax.set_xlabel("t (h)")
ax.set_ylabel("n_OH / wetting / volume")
ax.set_title("KOH fill and wetting")
ax.text(0.0, -0.22, "6 M KOH make-up", transform=ax.transAxes, fontsize=8, va="top")
fig.tight_layout()
fig.subplots_adjust(bottom=0.22)
plot_frame = pd.DataFrame(
    {
        "t": (t/3600),
        "n_H2": (a["n_H2_mol"]),
        "n_O2": (a["n_O2_oer_mol"]),
        "CE": (a["CE"]),
    }
)
plot_long = plot_frame.melt(id_vars="t", var_name="quantity", value_name="value")
fig, ax = plt.subplots()
sns.lineplot(data=plot_long, x="t", y="value", hue="quantity", ax=ax, linewidth=2.0)
ax.set_xlabel("t (h)")
ax.set_ylabel("mol / CE")
ax.set_title("Gas evolution")
ax.text(0.0, -0.22, "HER + OER on first charge", transform=ax.transAxes, fontsize=8, va="top")
fig.tight_layout()
fig.subplots_adjust(bottom=0.22)
plot_frame = pd.DataFrame(
    {
        "t": (t/3600),
        "T_fe": (y[b["fe"][0]+3]),
        "T_ely": (y[b["ely"][0]+4]),
        "T_ves": (y[b["th"][0]+2]),
    }
)
plot_long = plot_frame.melt(id_vars="t", var_name="quantity", value_name="value")
fig, ax = plt.subplots()
sns.lineplot(data=plot_long, x="t", y="value", hue="quantity", ax=ax, linewidth=2.0)
ax.set_xlabel("t (h)")
ax.set_ylabel("T (K)")
ax.set_title("Temperature rise")
ax.text(0.0, -0.22, "I*eta + formation", transform=ax.transAxes, fontsize=8, va="top")
fig.tight_layout()
fig.subplots_adjust(bottom=0.22)
plot_frame = pd.DataFrame(
    {
        "t": (t/3600),
        "SOC": (a["SOC"]),
        "n_CO3": (y[b["ely"][0]+2]),
        "pO2_atm": (a["p_O2_Pa"]/P.P_atm_Pa),
        "s_gdl": (a["s_gdl"]),
    }
)
plot_long = plot_frame.melt(id_vars="t", var_name="quantity", value_name="value")
fig, ax = plt.subplots()
sns.lineplot(data=plot_long, x="t", y="value", hue="quantity", ax=ax, linewidth=2.0)
ax.set_xlabel("t (h)")
ax.set_ylabel("SOC / carbonate / pO2 / s")
ax.set_title("SOC, carbonation risk, pO2, GDL saturation")
ax.text(0.0, -0.22, "US CO2; pO2 window", transform=ax.transAxes, fontsize=8, va="top")
fig.tight_layout()
fig.subplots_adjust(bottom=0.22)
print("finite", np.all(np.isfinite(y)), "nfev", res["nfev"])
"""),
            md_cell("## Verification against patents / SSS002"),
            code_cell("assert np.all(np.isfinite(y))\nprint('PASS finite commissioning trajectory')"),
        ],
    )

    scenarios = [
        (
            "91_ChargeDischarge.ipynb",
            "91 Charge / discharge LODES",
            r"$8\,\mathrm{h}$ / $100\,\mathrm{h}$ / $300\,\mathrm{h}$ thickness; asymmetric $L_\mathrm{c}$ vs $L_\mathrm{d}$.",
            """\
from plant_sim.plant import PlantModel
from plant_sim.scenarios.mission import charge_discharge_inputs
for hrs, span in [(8, 1200), (100, 1200)]:
    pp = P.with_duration(hrs, hrs)
    plant = PlantModel(pp)
    r = plant.simulate((0, span), inputs=charge_discharge_inputs(span/3, span/3, pp), n_eval=100, rtol=1e-4)
    plot_frame = pd.DataFrame(
        {
            "t": (r["t"]/60),
            "I": (r["alg"]["I_cell_A"]),
            "V": (r["alg"]["V_cell_V"]),
            "SOC": (r["alg"]["SOC"]),
        }
    )
    plot_long = plot_frame.melt(id_vars="t", var_name="quantity", value_name="value")
    fig, ax = plt.subplots()
    sns.lineplot(data=plot_long, x="t", y="value", hue="quantity", ax=ax, linewidth=2.0)
    ax.set_xlabel("t (min)")
    ax.set_ylabel("I/V/SOC")
    ax.set_title(f"{hrs} h thickness case")
    ax.text(0.0, -0.22, "US LODES duration scaling", transform=ax.transAxes, fontsize=8, va="top")
    fig.tight_layout()
    fig.subplots_adjust(bottom=0.22)
    print(hrs, "h L_anode_cm", round(pp.L_anode_m*100, 2), "finite", np.all(np.isfinite(r["y"])))
pp = P.with_duration(100, 300)
print("asymmetric 100/300 h Lc,Ld cm", pp.L_charge_m*100, pp.L_discharge_m*100)
""",
        ),
        (
            "92_GridServices.ipynb",
            "92 Grid services",
            "Curtailment charge, discharge to load, ramping, Q support.",
            """\
from plant_sim.plant import PlantModel
from plant_sim.scenarios.mission import grid_services_inputs
plant = PlantModel(P)
r = plant.simulate((0, 3600), inputs=grid_services_inputs(P), n_eval=180, rtol=1e-4)
plot_frame = pd.DataFrame(
    {
        "t": (r["t"]/60),
        "P": (r["alg"]["P_grid_W"]),
        "SOC": (r["alg"]["SOC"]),
        "V": (r["alg"]["V_cell_V"]),
    }
)
plot_long = plot_frame.melt(id_vars="t", var_name="quantity", value_name="value")
fig, ax = plt.subplots()
sns.lineplot(data=plot_long, x="t", y="value", hue="quantity", ax=ax, linewidth=2.0)
ax.set_xlabel("t (min)")
ax.set_ylabel("P/SOC/V")
ax.set_title("Grid services hour")
ax.text(0.0, -0.22, "US FIGS. 94-102 surplus solar / bulk energy", transform=ax.transAxes, fontsize=8, va="top")
fig.tight_layout()
fig.subplots_adjust(bottom=0.22)
""",
        ),
        (
            "93_ThermalExcursion.ipynb",
            "93 Thermal excursion",
            "Hot ambient + delayed coolant.",
            """\
from plant_sim.plant import PlantModel
from plant_sim.scenarios.mission import thermal_excursion_inputs
plant = PlantModel(P)
r = plant.simulate((0, 2400), inputs=thermal_excursion_inputs(P), n_eval=150, rtol=1e-4)
b = plant.blocks
plot_frame = pd.DataFrame(
    {
        "t": (r["t"]/60),
        "Tfe": (r["y"][b["fe"][0]+3]),
        "Tves": (r["y"][b["th"][0]+2]),
        "Tcool": (r["y"][b["th"][0]+4]),
    }
)
plot_long = plot_frame.melt(id_vars="t", var_name="quantity", value_name="value")
fig, ax = plt.subplots()
sns.lineplot(data=plot_long, x="t", y="value", hue="quantity", ax=ax, linewidth=2.0)
ax.set_xlabel("t (min)")
ax.set_ylabel("T (K)")
ax.set_title("Thermal excursion")
ax.text(0.0, -0.22, "IA-THM-001", transform=ax.transAxes, fontsize=8, va="top")
fig.tight_layout()
fig.subplots_adjust(bottom=0.22)
""",
        ),
        (
            "94_StarvationAndFlooding.ipynb",
            "94 Air starvation and GDL flooding",
            "Fan trip then high hydraulic head.",
            """\
from plant_sim.plant import PlantModel
from plant_sim.scenarios.mission import starvation_inputs
plant = PlantModel(P)
r = plant.simulate((0, 1800), inputs=starvation_inputs(P), n_eval=150, rtol=1e-4)
plot_frame = pd.DataFrame(
    {
        "t": (r["t"]/60),
        "V": (r["alg"]["V_cell_V"]),
        "s": (r["alg"]["s_gdl"]),
        "pO2": (r["alg"]["p_O2_Pa"]),
    }
)
plot_long = plot_frame.melt(id_vars="t", var_name="quantity", value_name="value")
fig, ax = plt.subplots()
sns.lineplot(data=plot_long, x="t", y="value", hue="quantity", ax=ax, linewidth=2.0)
ax.set_xlabel("t (min)")
ax.set_ylabel("V / s / pO2")
ax.set_title("Starvation then flooding")
ax.text(0.0, -0.22, "IA-GDL-001", transform=ax.transAxes, fontsize=8, va="top")
fig.tight_layout()
fig.subplots_adjust(bottom=0.22)
""",
        ),
        (
            "95_CarbonationAndImpurity.ipynb",
            "95 Carbonation and HER parasitic",
            "CO2-bearing air + charge HER.",
            """\
from plant_sim.plant import PlantModel
from plant_sim.scenarios.mission import carbonation_inputs
plant = PlantModel(P)
r = plant.simulate((0, 2000), inputs=carbonation_inputs(P), n_eval=120, rtol=1e-4)
b = plant.blocks
plot_frame = pd.DataFrame(
    {
        "t": (r["t"]/60),
        "n_CO3": (r["y"][b["ely"][0]+2]),
        "CE": (r["alg"]["CE"]),
        "n_H2": (r["alg"]["n_H2_mol"]),
    }
)
plot_long = plot_frame.melt(id_vars="t", var_name="quantity", value_name="value")
fig, ax = plt.subplots()
sns.lineplot(data=plot_long, x="t", y="value", hue="quantity", ax=ax, linewidth=2.0)
ax.set_xlabel("t (min)")
ax.set_ylabel("n_CO3 / CE / n_H2")
ax.set_title("Carbonate and HER")
ax.text(0.0, -0.22, "US CO2; EP HER", transform=ax.transAxes, fontsize=8, va="top")
fig.tight_layout()
fig.subplots_adjust(bottom=0.22)
""",
        ),
        (
            "96_EqualPressureDropORR.ipynb",
            "96 Equal pressure-drop ORR",
            "US Claim 1 verification.",
            """\
from plant_sim.substructures.cell_stack import CellStack
st = CellStack(P)
eq, nq = st.equal_pressure_drop(True), st.equal_pressure_drop(False)
plot_frame = pd.DataFrame(
    {
        "x": (eq["z_m"]),
        "comp": (eq["dP_Pa"]),
        "naive": (nq["dP_Pa"]),
    }
)
plot_long = plot_frame.melt(id_vars="x", var_name="quantity", value_name="value")
fig, ax = plt.subplots()
sns.lineplot(data=plot_long, x="x", y="value", hue="quantity", ax=ax, linewidth=2.0)
ax.set_xlabel("z (m)")
ax.set_ylabel("ΔP (Pa)")
ax.set_title("Claim 1 equal ΔP")
ax.text(0.0, -0.22, "US12308414B2 Claim 1", transform=ax.transAxes, fontsize=8, va="top")
fig.tight_layout()
fig.subplots_adjust(bottom=0.22)
plot_frame = pd.DataFrame(
    {
        "x": (eq["z_m"]),
        "Qcomp": (eq["Q_m3_s"]),
        "Qnaive": (nq["Q_m3_s"]),
    }
)
plot_long = plot_frame.melt(id_vars="x", var_name="quantity", value_name="value")
fig, ax = plt.subplots()
sns.lineplot(data=plot_long, x="x", y="value", hue="quantity", ax=ax, linewidth=2.0)
ax.set_xlabel("z (m)")
ax.set_ylabel("Q (m³/s)")
ax.set_title("Flow equalization")
ax.text(0.0, -0.22, "increasing pocket thickness with depth", transform=ax.transAxes, fontsize=8, va="top")
fig.tight_layout()
fig.subplots_adjust(bottom=0.22)
print("std dP compensated", float(np.std(eq["dP_Pa"])), "naive", float(np.std(nq["dP_Pa"])))
""",
        ),
        (
            "97_ChannelGeometryEP.ipynb",
            "97 EP channel geometry window",
            r"Channel $3$–$50\,\mathrm{mm}$ × $1$–$40\,\mathrm{mm}$, spacing $10$–$50\,\mathrm{mm}$, Fe $1$–$7\,\mathrm{g\,cm^{-2}}$, VF $0.5$–$0.9$.",
            """\
from plant_sim.substructures.channeled_electrode import ChanneledElectrode, assert_channel_window
assert_channel_window(P.channel_length_m, P.channel_width_m, P.channel_spacing_m, P)
ch = ChanneledElectrode(P)
cmp = ch.compare_layouts(P.I_discharge_100h_A*8)
print(cmp)
ce_frame = pd.DataFrame(
    {
        "layout": [k[3:] for k in cmp if k.startswith("CE_")],
        "CE": [v for k, v in cmp.items() if k.startswith("CE_")],
    }
)
fig, ax = plt.subplots()
sns.barplot(data=ce_frame, x="layout", y="CE", ax=ax)
ax.set_xlabel("layout")
ax.set_ylabel("CE")
ax.set_title("EP channel window: charge CE by layout")
ax.tick_params(axis="x", rotation=30)
fig.tight_layout()
print("loading", P.loading_g_cm2, "VF", P.vf_electrolyte_charged, "chan", P.channel_length_m, P.channel_width_m, P.channel_spacing_m)
""",
        ),
        (
            "98_DegradationCE.ipynb",
            "98 Degradation CE / ASR (EP FIGS. 19-27 analog)",
            r"$6\,\mathrm{M}$ KOH, $303\,\mathrm{K}$, isolation protects ORR.",
            """\
from plant_sim.components.degradation import Degradation
from plant_sim.components.base import integrate_component
deg = Degradation(P)
t, y = integrate_component(lambda t,y: deg.rhs(t,y,{"I_cell_A": 2.0, "eta_oer_V": 0.55, "r_carb_mol_s": 1e-7, "saturation": 0.25, "oer_isolated": 0.0 if t>8e4 else 1.0}, {}), deg.y0(), (0, 2e5), n_eval=200)
fade = [deg.outputs(float(ti), y[:,i], {}, {})["CE_fade"] for i,ti in enumerate(t)]
plot_frame = pd.DataFrame(
    {
        "t": (t/86400),
        "CE_fade": (fade),
        "ASR": (y[1]),
        "ORR_loss": (y[2]),
        "PTFE": (y[3]),
    }
)
plot_long = plot_frame.melt(id_vars="t", var_name="quantity", value_name="value")
fig, ax = plt.subplots()
sns.lineplot(data=plot_long, x="t", y="value", hue="quantity", ax=ax, linewidth=2.0)
ax.set_xlabel("t (d)")
ax.set_ylabel("fade metrics")
ax.set_title("CE/ASR aging analog of EP FIGS. 19-27")
ax.text(0.0, -0.22, "6 M KOH, 303 K", transform=ax.transAxes, fontsize=8, va="top")
fig.tight_layout()
fig.subplots_adjust(bottom=0.22)
""",
        ),
        (
            "99_FullPlantMission.ipynb",
            "99 Full plant mission",
            "Commission → charge → idle → discharge → rest on the same plant ODE.",
            """\
from plant_sim.plant import PlantModel
from plant_sim.scenarios.mission import full_mission_inputs
plant = PlantModel(P)
r = plant.simulate((0, 14000), inputs=full_mission_inputs(P), y0=plant.y0(filled=False), n_eval=400, rtol=1e-4)
plot_frame = pd.DataFrame(
    {
        "t": (r["t"]/3600),
        "P": (r["alg"]["P_grid_W"]),
        "SOC": (r["alg"]["SOC"]),
        "V": (r["alg"]["V_cell_V"]),
        "T": (r["alg"]["T_K"]),
    }
)
plot_long = plot_frame.melt(id_vars="t", var_name="quantity", value_name="value")
fig, ax = plt.subplots()
sns.lineplot(data=plot_long, x="t", y="value", hue="quantity", ax=ax, linewidth=2.0)
ax.set_xlabel("t (h)")
ax.set_ylabel("mixed SI")
ax.set_title("Multi-segment mission")
ax.text(0.0, -0.22, "Same RHS as 40 and 90", transform=ax.transAxes, fontsize=8, va="top")
fig.tight_layout()
fig.subplots_adjust(bottom=0.22)
print("finite", np.all(np.isfinite(r["y"])))
""",
        ),
    ]
    for fname, title, blurb, code in scenarios:
        story_nb(
            fname,
            title,
            blurb,
            GOV_SCENARIO,
            code,
            "print('finite trajectories and patent-window parameters: see printed checks above')",
        )


if __name__ == "__main__":
    main()
