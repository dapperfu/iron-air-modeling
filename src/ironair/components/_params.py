"""Internal helpers for typed component parameters."""

from __future__ import annotations

from ironair.parameters import (
    CalibrationStatus,
    PhysicalParameter,
    SourceClass,
)


def param(
    name: str,
    value: float,
    si_unit: str,
    meaning: str,
    valid_min: float,
    valid_max: float,
    source_class: SourceClass = SourceClass.UNVERIFIED_PLACEHOLDER,
    literature_reference: str | None = None,
    uncertainty: float | None = None,
    calibration_status: CalibrationStatus | None = None,
) -> PhysicalParameter:
    """Build a PhysicalParameter with placeholder defaults.

    @relation(IA-CON-002, scope=function)
    """
    status = calibration_status
    if status is None:
        status = (
            CalibrationStatus.PLACEHOLDER
            if source_class is SourceClass.UNVERIFIED_PLACEHOLDER
            else CalibrationStatus.UNCALIBRATED
        )
    return PhysicalParameter(
        name=name,
        value=value,
        si_unit=si_unit,
        meaning=meaning,
        valid_min=valid_min,
        valid_max=valid_max,
        source_class=source_class,
        literature_reference=literature_reference,
        uncertainty=uncertainty,
        calibration_status=status,
    )
