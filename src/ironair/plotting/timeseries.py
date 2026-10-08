"""Seaborn time-domain plotting for simulation results.

@relation(IA-NBK-002, scope=module)
@relation(IA-NBK-003, scope=module)
@relation(IA-PLT-001, scope=module)
"""

from __future__ import annotations

from typing import Any

import pandas as pd

from ironair.exceptions import InvalidPhysicalState


def _as_frame(data: Any) -> pd.DataFrame:
    if isinstance(data, pd.DataFrame):
        return data
    if hasattr(data, "to_dataframe"):
        return data.to_dataframe()
    raise TypeError("plotting requires a SimulationResult or pandas.DataFrame")


def plot_states(
    data: Any,
    y_columns: list[str],
    *,
    title: str,
    xlabel: str,
    ylabel: str,
    scenario_id: str,
    assumptions: str,
    time_column: str = "t_s",
) -> Any:
    """Plot named state columns with seaborn.

    @relation(IA-NBK-002, scope=function)
    @relation(IA-NBK-003, scope=function)
    @relation(IA-PLT-001, scope=function)
    """
    if not title or not xlabel or not ylabel:
        raise InvalidPhysicalState("plots require title and axis labels with units")
    if not scenario_id:
        raise InvalidPhysicalState("plots require a scenario identifier")
    frame = _as_frame(data)
    import matplotlib.pyplot as plt
    import seaborn as sns

    sns.set_theme(style="whitegrid")
    melted = frame.melt(
        id_vars=[time_column],
        value_vars=y_columns,
        var_name="quantity",
        value_name="value",
    )
    axes = sns.lineplot(data=melted, x=time_column, y="value", hue="quantity")
    axes.set_title(f"{title} [{scenario_id}]")
    axes.set_xlabel(xlabel)
    axes.set_ylabel(ylabel)
    axes.text(
        0.0,
        -0.22,
        assumptions,
        transform=axes.transAxes,
        fontsize=8,
        wrap=True,
    )
    fig = axes.figure
    fig.tight_layout()
    return fig if fig is not None else plt.gcf()
