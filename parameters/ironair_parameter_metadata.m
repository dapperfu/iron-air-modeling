function metadata = ironair_parameter_metadata(unit, classification, ...
        valid_range, applicability, reference_id)
%IRONAIR_PARAMETER_METADATA Construct validated parameter provenance metadata.
%   METADATA = IRONAIR_PARAMETER_METADATA(UNIT, CLASSIFICATION, VALID_RANGE,
%   APPLICABILITY, REFERENCE_ID) creates one immutable metadata record.
%
%   Inputs:
%     unit           - SI unit text or "1" for dimensionless.
%     classification - PHYSICAL_CONSTANT, REFERENCE_CONDITION,
%       LITERATURE, ASSUMED, EMPIRICAL, or CALIBRATION_REQUIRED.
%     valid_range    - Two-element numeric [minimum maximum].
%     applicability  - Physical configuration or model scope.
%     reference_id   - Citation identifier or "NONE".
%
%   Output:
%     metadata - Scalar structure.
%
%   Requirements: SRS002.3, SRS021.

arguments
    unit (1, 1) string
    classification (1, 1) string {mustBeMember(classification, [ ...
        "PHYSICAL_CONSTANT", "REFERENCE_CONDITION", "LITERATURE", ...
        "ASSUMED", "EMPIRICAL", "CALIBRATION_REQUIRED"])}
    valid_range (1, 2) double
    applicability (1, 1) string
    reference_id (1, 1) string = "NONE"
end

if valid_range(1) > valid_range(2)
    error("ironair:parameter:InvalidRange", ...
        "Parameter minimum exceeds maximum.");
end
if classification == "LITERATURE" && reference_id == "NONE"
    error("ironair:parameter:MissingCitation", ...
        "Literature parameters require a reference identifier.");
end

metadata = struct( ...
    "unit", unit, ...
    "classification", classification, ...
    "valid_range", valid_range, ...
    "applicability", applicability, ...
    "reference_id", reference_id);
end
