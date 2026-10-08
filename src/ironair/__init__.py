"""ironair: Python multiphysics iron-air battery simulation.

@relation(IA-SYS-001, scope=module)
@relation(IA-IRS-001, scope=module)
"""

from ironair import chemistry, components, constants, scenarios, simulation

__version__ = "1.0.0"

__all__ = [
    "chemistry",
    "components",
    "constants",
    "scenarios",
    "simulation",
    "__version__",
]
