# Numerical methods

Default integrator is `ode15s` with state-specific absolute tolerances, max-step limits, optional events, Jacobian patterns, and mass-matrix support.

Algebraic closures use a damped Newton method implemented in base MATLAB. Optimization Toolbox functions are not used.

Smoke/standard/reference presets define fast, default, and convergence gates.
