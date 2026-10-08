"""Shared iron-air chemical reaction network.

@relation(IA-CHM-001, scope=module)
"""

from ironair.chemistry.conservation import (
    assert_closed_conservation,
    closed_system_element_residual,
    elemental_inventory,
)
from ironair.chemistry.kinetics import (
    butler_volmer_current_density_a_m2,
    faradaic_current_A,
    temperature_scaled_i0_a_m2,
)
from ironair.chemistry.nernst import (
    equilibrium_cell_potential_v,
    nernst_her_v,
    nernst_iron_v,
    nernst_magnetite_v,
    nernst_oxygen_v,
)
from ironair.chemistry.network import (
    DEFAULT_NETWORK,
    Reaction,
    ReactionNetwork,
    current_from_rate_A,
    faraday_rate_mol_s,
)
from ironair.chemistry.species import Element, Species
from ironair.chemistry.thermodynamics import (
    ReactionThermo,
    electrochemical_thermo,
    gibbs_from_potential_j_mol,
    irreversible_heat_w,
    reversible_heat_w,
)

__all__ = [
    "DEFAULT_NETWORK",
    "Element",
    "Reaction",
    "ReactionNetwork",
    "ReactionThermo",
    "Species",
    "assert_closed_conservation",
    "butler_volmer_current_density_a_m2",
    "closed_system_element_residual",
    "current_from_rate_A",
    "electrochemical_thermo",
    "elemental_inventory",
    "equilibrium_cell_potential_v",
    "faradaic_current_A",
    "faraday_rate_mol_s",
    "gibbs_from_potential_j_mol",
    "irreversible_heat_w",
    "nernst_her_v",
    "nernst_iron_v",
    "nernst_magnetite_v",
    "nernst_oxygen_v",
    "reversible_heat_w",
    "temperature_scaled_i0_a_m2",
]
