"""ODE component protocol and state metadata.

@relation(IA-ODE-001, scope=module)
"""

from ironair.ode.component import DynamicComponent
from ironair.ode.protocol import Context, DynamicComponentProtocol, Inputs
from ironair.ode.state import StateSpec, validate_state_vector

__all__ = [
    "Context",
    "DynamicComponent",
    "DynamicComponentProtocol",
    "Inputs",
    "StateSpec",
    "validate_state_vector",
]
