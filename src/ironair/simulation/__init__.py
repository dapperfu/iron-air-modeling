"""Coupled ODE assembly and SciPy integration.

@relation(IA-ODE-003, scope=module)
"""

from ironair.simulation.coupled import CoupledSystem, SimulationResult
from ironair.simulation.diagnostics import SolverDiagnostics

__all__ = ["CoupledSystem", "SimulationResult", "SolverDiagnostics"]
