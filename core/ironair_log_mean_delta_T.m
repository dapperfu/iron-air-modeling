function [delta_T_lm, used_limit] = ironair_log_mean_delta_T(delta_T_1, delta_T_2)
%IRONAIR_LOG_MEAN_DELTA_T Numerically stable log-mean temperature difference.
%   [DELTA_T_LM, USED_LIMIT] = IRONAIR_LOG_MEAN_DELTA_T(DELTA_T_1, DELTA_T_2)
%   returns the arithmetic mean when the two differences approach each other.
%
%   Equation: HEX-002
%   Requirements: SRS008.

arguments
    delta_T_1 double
    delta_T_2 double
end

scale = max(max(abs(delta_T_1), abs(delta_T_2)), realmin);
near = abs(delta_T_1 - delta_T_2) <= 1e-8 .* scale;
same_sign = delta_T_1 .* delta_T_2 > 0;
delta_T_lm = 0.5 .* (delta_T_1 + delta_T_2);
use_log = ~near & same_sign;
delta_T_lm(use_log) = (delta_T_1(use_log) - delta_T_2(use_log)) ./ ...
    log(delta_T_1(use_log) ./ delta_T_2(use_log));
if any(~same_sign & ~near, "all")
    error("ironair:hx:InvalidLMTD", ...
        "Log-mean temperature difference requires endpoint differences of the same sign.");
end
used_limit = near;
end
