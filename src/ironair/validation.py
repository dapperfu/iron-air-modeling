"""Track software verification versus independent model validation.

Passing tests is not experimental hardware validation.

@relation(IA-TST-006, scope=module)
@relation(IA-REQ-005, scope=module)
"""

from __future__ import annotations

from dataclasses import dataclass
from enum import Enum


class ValidationKind(str, Enum):
    """What a record claims.

    @relation(IA-TST-006, scope=class)
    """

    SOFTWARE_VERIFICATION = "software_verification"
    EXPERIMENTAL_CALIBRATION = "experimental_calibration"
    INDEPENDENT_PHYSICAL_VALIDATION = "independent_physical_validation"


@dataclass(frozen=True, slots=True)
class ValidationRecord:
    """A single verification or validation claim.

    @relation(IA-TST-006, scope=class)
    @relation(IA-DOC-001, scope=class)
    """

    name: str
    kind: ValidationKind
    requirement_ids: tuple[str, ...]
    notes: str
    hardware_validated: bool = False

    def __post_init__(self) -> None:
        if self.kind is ValidationKind.SOFTWARE_VERIFICATION and self.hardware_validated:
            raise ValueError("software verification must not be marked hardware_validated")


SOFTWARE_VERIFICATION_NOTICE: str = (
    "Passing ironair tests verifies the software against the SDRS. "
    "It does not constitute physical validation against experimental hardware."
)
