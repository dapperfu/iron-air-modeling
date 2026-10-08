"""30 Module: stacks + shared thermal/fluid/air (US FIG. 13 ~40 housings).

@relation(IA-MOD-001, scope=module)
"""

from __future__ import annotations

from plant_sim.params import PlantParams, default_params
from plant_sim.plant import PlantModel


class BatteryModule:
    """IA-MOD-001 module wrapping the assembled plant.

    @relation(IA-MOD-001, scope=class)
    """

    def __init__(self, p: PlantParams | None = None) -> None:
        self.params = p or default_params()
        self.plant = PlantModel(self.params)

    def y0(self, filled: bool = True):
        return self.plant.y0(filled=filled)

    def rhs(self, t, y, u=None):  # type: ignore[no-untyped-def]
        """Delegate to PlantModel concatenated RHS.

        @relation(IA-MOD-001, scope=function)
        """
        return self.plant.rhs(t, y, u)

    def simulate(self, t_span, **kwargs):  # type: ignore[no-untyped-def]
        return self.plant.simulate(t_span, **kwargs)
