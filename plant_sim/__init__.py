"""Component-to-plant iron-air simulation package.

Decade numbering (see README.md):
  01-09 atomic components, 10-19 half-cells, 20-29 vessels,
  30-39 module/BOP, 40 plant, 90-99 operational scenarios.

Physics reuse ironair.chemistry (stoichiometry, Nernst, Butler-Volmer) so this
package does not invent a parallel reaction set.
"""

from __future__ import annotations

from plant_sim.params import PlantParams, default_params

__all__ = ["PlantParams", "default_params"]
