"""PNG export for plant_sim/verify_components.py.

Notebooks do not import this module. Edit notebooks directly: each figure
has its own markdown section (header, what it illustrates, governing
equations) and a focused seaborn cell. This module only writes PNGs for
the headless verifier.

Axis labels here use Unicode SI (mA h g⁻¹, Pa, K). Notebook Markdown uses
Jupyter MathJax `$...$` with `\\mathrm{}` SI (siunitx is not available).
"""

from __future__ import annotations

from pathlib import Path
from typing import Any, Sequence

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import seaborn as sns
from numpy.typing import NDArray

FIGURES = Path(__file__).resolve().parent / "figures"
FIGURES.mkdir(exist_ok=True)

PALETTE = "deep"


def apply_style() -> None:
    sns.set_theme(style="whitegrid", context="talk", palette=PALETTE)
    plt.rcParams.update(
        {
            "figure.figsize": (10.0, 5.5),
            "figure.dpi": 120,
            "axes.titlesize": 13,
            "axes.labelsize": 11,
            "legend.fontsize": 9,
            "axes.titleweight": "medium",
        }
    )


def _annotate(ax: Any, callout: str) -> None:
    if not callout:
        return
    ax.text(
        0.0,
        -0.18,
        callout,
        transform=ax.transAxes,
        fontsize=8,
        color="#333333",
        wrap=True,
        va="top",
    )


def save_fig(fig: Any, stem: str) -> Path:
    FIGURES.mkdir(exist_ok=True)
    path = FIGURES / f"{stem}.png"
    fig.savefig(path, bbox_inches="tight", dpi=140)
    return path


def timeseries(
    t_s: NDArray[np.float64] | Sequence[float],
    series: dict[str, NDArray[np.float64] | Sequence[float]],
    *,
    xlabel: str,
    ylabel: str,
    title: str,
    callout: str,
    stem: str,
    t_scale: float = 1.0,
) -> Path:
    apply_style()
    frame = pd.DataFrame(
        {"t": np.asarray(t_s, dtype=float) / t_scale, **{k: np.asarray(v, dtype=float) for k, v in series.items()}}
    )
    melted = frame.melt(id_vars=["t"], var_name="quantity", value_name="value")
    fig, ax = plt.subplots()
    sns.lineplot(data=melted, x="t", y="value", hue="quantity", ax=ax, linewidth=2.0)
    ax.set_xlabel(xlabel)
    ax.set_ylabel(ylabel)
    ax.set_title(title)
    _annotate(ax, callout)
    fig.tight_layout()
    path = save_fig(fig, stem)
    plt.close(fig)
    return path


def xy_plot(
    x: NDArray[np.float64] | Sequence[float],
    series: dict[str, NDArray[np.float64] | Sequence[float]],
    *,
    xlabel: str,
    ylabel: str,
    title: str,
    callout: str,
    stem: str,
) -> Path:
    apply_style()
    frame = pd.DataFrame(
        {"x": np.asarray(x, dtype=float), **{k: np.asarray(v, dtype=float) for k, v in series.items()}}
    )
    melted = frame.melt(id_vars=["x"], var_name="quantity", value_name="value")
    fig, ax = plt.subplots()
    sns.lineplot(data=melted, x="x", y="value", hue="quantity", ax=ax, linewidth=2.0)
    ax.set_xlabel(xlabel)
    ax.set_ylabel(ylabel)
    ax.set_title(title)
    _annotate(ax, callout)
    fig.tight_layout()
    path = save_fig(fig, stem)
    plt.close(fig)
    return path


def heatmap(
    z: NDArray[np.float64],
    *,
    xlabel: str,
    ylabel: str,
    title: str,
    callout: str,
    stem: str,
    xticklabels: Sequence[str] | None = None,
    yticklabels: Sequence[str] | None = None,
) -> Path:
    apply_style()
    fig, ax = plt.subplots(figsize=(9.0, 5.0))
    sns.heatmap(
        z,
        ax=ax,
        cmap="mako",
        xticklabels=True if xticklabels is None else xticklabels,
        yticklabels=True if yticklabels is None else yticklabels,
    )
    ax.set_xlabel(xlabel)
    ax.set_ylabel(ylabel)
    ax.set_title(title)
    _annotate(ax, callout)
    fig.tight_layout()
    path = save_fig(fig, stem)
    plt.close(fig)
    return path


def verification_table(rows: list[tuple[str, float, float, str]], stem: str) -> Path:
    """Plot expected vs simulated numeric checks as a grouped bar chart."""
    apply_style()
    names = [r[0] for r in rows]
    expected = np.array([r[1] for r in rows], dtype=float)
    simulated = np.array([r[2] for r in rows], dtype=float)
    units = [r[3] for r in rows]
    frame = pd.DataFrame(
        {
            "check": names,
            "expected": expected,
            "simulated": simulated,
            "unit": units,
        }
    )
    melted = frame.melt(
        id_vars=["check", "unit"], value_vars=["expected", "simulated"], var_name="source", value_name="value"
    )
    fig, ax = plt.subplots(figsize=(11.0, 5.5))
    sns.barplot(data=melted, x="check", y="value", hue="source", ax=ax)
    ax.set_xlabel("Verification check")
    ax.set_ylabel("Value (mixed SI / patent units — see legend callout)")
    ax.set_title("Patent / requirements numeric verification")
    labels = ", ".join(f"{n} [{u}]" for n, u in zip(names, units))
    _annotate(ax, labels)
    for tick in ax.get_xticklabels():
        tick.set_rotation(20)
        tick.set_ha("right")
    fig.tight_layout()
    path = save_fig(fig, stem)
    plt.close(fig)
    return path
