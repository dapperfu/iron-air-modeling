"""Typed physical parameters with source classification.

@relation(IA-CON-002, scope=module)
"""

from __future__ import annotations

from collections.abc import Iterator, Mapping
from dataclasses import dataclass
from enum import Enum
from typing import Any

from ironair.exceptions import DomainError, InvalidPhysicalState


class SourceClass(str, Enum):
    """Provenance of a numeric parameter.

    @relation(IA-CON-002, scope=class)
    """

    FUNDAMENTAL_CONSTANT = "fundamental_constant"
    LITERATURE_VALUE = "literature_value"
    EXPERIMENTAL_MEASUREMENT = "experimental_measurement"
    ENGINEERING_DESIGN_ASSUMPTION = "engineering_design_assumption"
    CALIBRATED_COEFFICIENT = "calibrated_coefficient"
    UNVERIFIED_PLACEHOLDER = "unverified_placeholder"


class CalibrationStatus(str, Enum):
    """Whether a parameter has been calibrated to data.

    @relation(IA-CON-002, scope=class)
    """

    NOT_APPLICABLE = "not_applicable"
    UNCALIBRATED = "uncalibrated"
    CALIBRATED = "calibrated"
    PLACEHOLDER = "placeholder"


@dataclass(frozen=True, slots=True)
class PhysicalParameter:
    """A single named SI parameter.

    @relation(IA-CON-002, scope=class)
    """

    name: str
    value: float
    si_unit: str
    meaning: str
    valid_min: float
    valid_max: float
    source_class: SourceClass
    literature_reference: str | None = None
    uncertainty: float | None = None
    calibration_status: CalibrationStatus = CalibrationStatus.UNCALIBRATED

    def __post_init__(self) -> None:
        if self.valid_max < self.valid_min:
            raise InvalidPhysicalState(f"{self.name}: valid_max < valid_min")
        self.validate(self.value)

    def validate(self, value: float) -> float:
        """Return value if it lies in [valid_min, valid_max].

        @relation(IA-CON-002, scope=function)
        """
        if not (self.valid_min <= value <= self.valid_max):
            raise DomainError(f"{self.name}={value} {self.si_unit} outside [{self.valid_min}, {self.valid_max}]")
        return value


class ParameterSet:
    """Ordered collection of PhysicalParameter objects.

    @relation(IA-CON-002, scope=class)
    """

    def __init__(self, parameters: Mapping[str, PhysicalParameter]) -> None:
        self._parameters = dict(parameters)

    def __getitem__(self, name: str) -> PhysicalParameter:
        return self._parameters[name]

    def value(self, name: str) -> float:
        """Return the numeric value of a named parameter.

        @relation(IA-CON-002, scope=function)
        """
        return self._parameters[name].value

    def __iter__(self) -> Iterator[str]:
        return iter(self._parameters)

    def __len__(self) -> int:
        return len(self._parameters)

    def placeholders(self) -> list[PhysicalParameter]:
        """Return parameters that are unverified placeholders.

        @relation(IA-CON-002, scope=function)
        """
        return [
            p
            for p in self._parameters.values()
            if p.source_class is SourceClass.UNVERIFIED_PLACEHOLDER
            or p.calibration_status is CalibrationStatus.PLACEHOLDER
        ]

    def as_dict(self) -> dict[str, Any]:
        """Serialize values for reproducibility metadata.

        @relation(IA-TST-011, scope=function)
        """
        return {name: p.value for name, p in self._parameters.items()}
