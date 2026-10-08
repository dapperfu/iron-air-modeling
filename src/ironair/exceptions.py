"""Domain exceptions for invalid physical states and numerical failures.

@relation(IA-TST-004, scope=module)
"""

from __future__ import annotations


class IronAirError(Exception):
    """Base exception for ironair.

    @relation(IA-TST-004, scope=class)
    """


class InvalidPhysicalState(IronAirError):
    """A state, input, or parameter is outside the physical domain.

    @relation(IA-TST-004, scope=class)
    """


class DomainError(InvalidPhysicalState):
    """A property or kinetic model was evaluated outside its valid domain.

    @relation(IA-CON-003, scope=class)
    """


class ConservationError(IronAirError):
    """Element, charge, or energy conservation residual exceeded tolerance.

    @relation(IA-CHM-010, scope=class)
    """


class SolverFailure(IronAirError):
    """SciPy integration or algebraic residual solve failed.

    @relation(IA-ODE-003, scope=class)
    """


class TraceabilityError(IronAirError):
    """A requirements traceability rule was violated.

    @relation(IA-REQ-004, scope=class)
    """
