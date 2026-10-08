"""Solver diagnostics and conservation residual containers.

@relation(IA-ODE-005, scope=module)
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any

import numpy as np
from numpy.typing import NDArray


@dataclass(slots=True)
class SolverDiagnostics:
    """SciPy solve_ivp status and conservation residuals.

    @relation(IA-ODE-005, scope=class)
    """

    method: str
    success: bool
    message: str
    nfev: int
    njev: int
    nlu: int
    status: int
    conservation_residuals: dict[str, float] = field(default_factory=dict)
    events: dict[str, NDArray[np.float64]] = field(default_factory=dict)
    extra: dict[str, Any] = field(default_factory=dict)
