function [u, dintegral_dt, saturated] = ironair_pi_antiwindup(error_value, integral_value, Kp, Ki, u_min, u_max)
%IRONAIR_PI_ANTIWINDUP PI control with conditional-integration anti-windup.
%   [U, DINTEGRAL_DT, SATURATED] = IRONAIR_PI_ANTIWINDUP(ERROR_VALUE,
%   INTEGRAL_VALUE, KP, KI, U_MIN, U_MAX) freezes the integrator when the
%   unsaturated command is outside limits and the error drives it further out.
%
%   Equation: INV-005, INV-006, CTRL-004
%   Requirements: SRS012, SRS014.

arguments
    error_value double
    integral_value double
    Kp double
    Ki double
    u_min double
    u_max double
end

u_unsaturated = Kp .* error_value + Ki .* integral_value;
u = min(max(u_unsaturated, u_min), u_max);
saturated = abs(u - u_unsaturated) > 0;
driving_out = saturated & (error_value .* (u_unsaturated - u) > 0);
dintegral_dt = error_value;
dintegral_dt(driving_out) = 0;
end
