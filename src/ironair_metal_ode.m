function [du_dt, eta, i_far] = ironair_metal_ode(u, i_app, c_OH, T, p)
%IRONAIR_METAL_ODE Iron-electrode utilization ODE, overpotential, and Faradaic current.
%
% Lumped-parameter electrochemical submodel of the iron electrode in an
% aqueous alkaline iron-air battery. Calculates the rate of change of
% reduced-iron utilization, activation overpotential, and Faradaic reaction
% current for charge, discharge, open-circuit, and transitions between them.
%
% -------------------------------------------------------------------------
% Reactions (principal alkaline iron couple)
% -------------------------------------------------------------------------
%   Discharge: Fe + 2 OH- -> Fe(OH)2 + 2 e-
%   Charge:    Fe(OH)2 + 2 e- -> Fe + 2 OH-
% Two electrons are transferred per iron atom. Parameter p.Q_max already
% embodies this stoichiometry in coulombic capacity (C or C/m^2). No extra
% electron-count multiplier is applied in du_dt.
%
% -------------------------------------------------------------------------
% State and sign conventions
% -------------------------------------------------------------------------
%   u      - Fraction of electrochemically active iron in the reduced
%            metallic state. u = 1 fully charged; u = 0 fully discharged.
%            Physically valid interval: 0 <= u <= 1.
%   i_app  - Externally applied / requested current density [A/m^2].
%            i_app > 0 discharge (oxidation, u decreases);
%            i_app < 0 charge (reduction, u increases);
%            i_app = 0 open circuit (no applied current).
%   i_far  - Faradaic current of the modeled Fe/Fe(OH)2 reaction only
%            [same units as i_app]. Not a claim of total electrode current
%            when parasitics or other pathways exist (not modeled here).
%   du_dt  - d(u)/dt [1/s], satisfying du_dt = -i_far / p.Q_max.
%   eta    - Activation overpotential [V], positive for anodic polarization.
%            eta = NaN marks an infeasible request (not a physical eta).
%
% Charge conservation (always):
%   p.Q_max * du_dt + i_far == 0
%
% -------------------------------------------------------------------------
% Kinetics
% -------------------------------------------------------------------------
% Temperature-dependent exchange current (Arrhenius):
%   i0 = p.i0_Fe * exp(-p.E_act_Fe/R * (1/T - 1/p.T_ref))
%
% Effective exchange current:
%   i0_eff = i0 * soc_activity * oh_activity
%
% SOC activity (configurable; empirical, not universal physics):
%   mode 0: unity (no SOC dependence)
%   mode 1: sqrt(max(u_act*(1-u_act), soc_activity_min))
%   mode 2: max(u_act*(1-u_act), soc_activity_min)^soc_activity_exp
% Geometric utilization u is distinct from electrochemically active area;
% soc_activity_min is numerical regularization, not physical residual Fe.
%
% Hydroxide correction (empirical kinetic order, not thermodynamic activity):
%   oh_activity = (c_OH / p.c_OH_ref)^p.gamma_OH
% Concentration [mol/m^3] is used directly; activity coefficients for
% concentrated KOH are not included.
%
% Butler-Volmer (transfer coefficients in the exponents; n is not applied
% a second time — stoichiometry lives in Q_max / i0 calibration):
%   i_far = i0_eff * (exp(alpha_a*F*eta/(R*T)) - exp(-alpha_c*F*eta/(R*T)))
% Symmetric (alpha_a == alpha_c): analytical inverse via asinh (inverse
% symmetric BV, not a Tafel-branch approximation).
% Asymmetric: bounded Newton inversion with bisection fallback.
%
% -------------------------------------------------------------------------
% Idealized current partitioning (limitations)
% -------------------------------------------------------------------------
% When the Fe reaction is feasible, this initial model sets i_far = i_app.
% Unsupported applied current is NOT silently forced through the iron
% reaction: i_far = 0, du_dt = 0, eta = NaN. Parasitic HER, double-layer
% charging, O2 electrode kinetics, and Faradaic efficiency are NOT
% implemented in this function. The enclosing cell model must decide how
% unavailable iron current is handled.
%
% -------------------------------------------------------------------------
% Boundary / infeasible conditions
% -------------------------------------------------------------------------
%   u <= 0 and i_app > 0  -> discharge blocked
%   u >= 1 and i_app < 0  -> charge blocked
%   i0_eff == 0 and i_app ~= 0 -> no finite eta sustains the request
%   c_OH == 0 with gamma_OH > 0 and i_app ~= 0 -> same
% Integrators must still enforce 0 <= u <= 1; this function does not rely
% on internal clipping of u as a complete state limiter.
%
% -------------------------------------------------------------------------
% Inputs
% -------------------------------------------------------------------------
%   u, i_app, c_OH, T - finite scalars (see units above; T in K)
%   p fields (required unless noted):
%     i0_Fe       > 0     reference exchange current density [A/m^2]
%     E_act_Fe   >= 0     apparent activation energy [J/mol]
%     T_ref       > 0     reference temperature [K]
%     alpha_a     > 0     anodic transfer coefficient [-]
%     alpha_c     > 0     cathodic transfer coefficient [-]
%     Q_max       > 0     capacity on same basis as i_app [C/m^2 or C]
%     c_OH_ref    > 0     reference OH- concentration [mol/m^3]
%     gamma_OH            OH reaction order [-] (default 0.25)
%     soc_activity_mode   0|1|2 (default 1)
%     soc_activity_min   >= 0 regularization (default 1e-4)
%     soc_activity_exp    exponent for mode 2 (default 0.5)
%     bv_max_iter         asymmetric solver max iterations (default 40)
%     bv_tol              relative residual tolerance (default 1e-10)
%     exp_arg_max         |argument| clamp for exp (default 80)
%
% Outputs: du_dt [1/s], eta [V], i_far [same as i_app]
%
% Requirement IDs: SSS004, SDD002
% Verification: tests/test_Metal_Electrode_1D.m (open-circuit, charge,
% discharge, boundaries, charge conservation, symmetric/asymmetric BV,
% temperature and concentration sensitivity, robustness).
%
% Not represented: Nernst equilibrium, KOH activity coefficients, HER,
% passivation, hysteresis, double-layer capacitance, mass transport,
% aging, or full-cell/BOP models.

    C = ironair_constants();
    F = C.F;
    R = C.R;

    du_dt = 0;
    eta = 0;
    i_far = 0;

    if ~ironair_metal_ode_validate(u, i_app, c_OH, T, p)
        du_dt = NaN;
        eta = NaN;
        i_far = NaN;
        return;
    end

    gamma_OH = 0.25;
    if isfield(p, 'gamma_OH')
        gamma_OH = p.gamma_OH;
    end
    soc_mode = 1;
    if isfield(p, 'soc_activity_mode')
        soc_mode = p.soc_activity_mode;
    end
    soc_min = 1e-4;
    if isfield(p, 'soc_activity_min')
        soc_min = p.soc_activity_min;
    end
    soc_exp = 0.5;
    if isfield(p, 'soc_activity_exp')
        soc_exp = p.soc_activity_exp;
    end
    bv_max_iter = 40;
    if isfield(p, 'bv_max_iter')
        bv_max_iter = p.bv_max_iter;
    end
    bv_tol = 1e-10;
    if isfield(p, 'bv_tol')
        bv_tol = p.bv_tol;
    end
    exp_arg_max = 80;
    if isfield(p, 'exp_arg_max')
        exp_arg_max = p.exp_arg_max;
    end

    if ~(isfinite(gamma_OH) && isfinite(soc_min) && soc_min >= 0 && ...
            isfinite(soc_exp) && isfinite(bv_tol) && bv_tol > 0 && ...
            isfinite(exp_arg_max) && exp_arg_max > 0)
        du_dt = NaN;
        eta = NaN;
        i_far = NaN;
        return;
    end
    if ~(soc_mode == 0 || soc_mode == 1 || soc_mode == 2)
        du_dt = NaN;
        eta = NaN;
        i_far = NaN;
        return;
    end
    max_iter = max(1, min(200, floor(bv_max_iter)));

    % Utilization for activity formulas only (does not replace integrator limits)
    u_act = min(max(u, 0), 1);

    % --- Feasibility: utilization boundaries ---
    discharge_blocked = (u <= 0) && (i_app > 0);
    charge_blocked = (u >= 1) && (i_app < 0);
    if discharge_blocked || charge_blocked
        i_far = 0;
        du_dt = 0;
        eta = NaN;
        return;
    end

    % --- Arrhenius exchange current ---
    inv_T = 1 / T;
    inv_T_ref = 1 / p.T_ref;
    arrhenius_arg = -p.E_act_Fe / R * (inv_T - inv_T_ref);
    arrhenius_arg = min(max(arrhenius_arg, -exp_arg_max), exp_arg_max);
    i0 = p.i0_Fe * exp(arrhenius_arg);
    if ~(isfinite(i0) && i0 > 0)
        i_far = 0;
        du_dt = 0;
        eta = NaN;
        return;
    end

    % --- SOC activity ---
    soc_activity = ironair_metal_ode_soc_activity(u_act, soc_mode, soc_min, soc_exp);
    if ~(isfinite(soc_activity) && soc_activity >= 0)
        i_far = 0;
        du_dt = 0;
        eta = NaN;
        return;
    end

    % --- Hydroxide empirical activity ---
    [oh_activity, oh_ok] = ironair_metal_ode_oh_activity( ...
        c_OH, p.c_OH_ref, gamma_OH, exp_arg_max);
    if ~oh_ok
        i_far = 0;
        du_dt = 0;
        eta = NaN;
        return;
    end

    i0_eff = i0 * soc_activity * oh_activity;
    if ~(isfinite(i0_eff) && i0_eff >= 0)
        i_far = 0;
        du_dt = 0;
        eta = NaN;
        return;
    end

    % Idealized partition: admissible iron current equals applied request
    i_far = i_app;

    if i_far == 0
        eta = 0;
        du_dt = 0;
        return;
    end

    if i0_eff == 0
        % No finite activation overpotential can sustain nonzero i_far
        i_far = 0;
        du_dt = 0;
        eta = NaN;
        return;
    end

    eta = ironair_metal_ode_inverse_bv( ...
        i_far, i0_eff, p.alpha_a, p.alpha_c, F, R, T, ...
        max_iter, bv_tol, exp_arg_max);

    if ~isfinite(eta)
        i_far = 0;
        du_dt = 0;
        eta = NaN;
        return;
    end

    du_dt = -i_far / p.Q_max;
end

function ok = ironair_metal_ode_validate(u, i_app, c_OH, T, p)
    ok = false;
    if ~(isfinite(u) && isfinite(i_app) && isfinite(c_OH) && isfinite(T))
        return;
    end
    if c_OH < 0 || T <= 0
        return;
    end
    if ~isstruct(p)
        return;
    end
    if ~(isfield(p, 'i0_Fe') && isfield(p, 'E_act_Fe') && isfield(p, 'T_ref') && ...
            isfield(p, 'alpha_a') && isfield(p, 'alpha_c') && ...
            isfield(p, 'Q_max') && isfield(p, 'c_OH_ref'))
        return;
    end
    if ~(isfinite(p.i0_Fe) && p.i0_Fe > 0)
        return;
    end
    if ~(isfinite(p.E_act_Fe) && p.E_act_Fe >= 0)
        return;
    end
    if ~(isfinite(p.T_ref) && p.T_ref > 0)
        return;
    end
    if ~(isfinite(p.alpha_a) && p.alpha_a > 0 && isfinite(p.alpha_c) && p.alpha_c > 0)
        return;
    end
    if ~(isfinite(p.Q_max) && p.Q_max > 0)
        return;
    end
    if ~(isfinite(p.c_OH_ref) && p.c_OH_ref > 0)
        return;
    end
    ok = true;
end

function soc_activity = ironair_metal_ode_soc_activity(u_act, soc_mode, soc_min, soc_exp)
    prod_u = u_act * (1 - u_act);
    if soc_mode == 0
        soc_activity = 1;
    elseif soc_mode == 1
        soc_activity = sqrt(max(prod_u, soc_min));
    else
        % mode 2: power-law in u*(1-u) with configurable exponent
        soc_activity = max(prod_u, soc_min) ^ soc_exp;
    end
end

function [oh_activity, ok] = ironair_metal_ode_oh_activity(c_OH, c_OH_ref, gamma_OH, exp_arg_max)
    ok = true;
    oh_activity = 1;
    if gamma_OH == 0
        oh_activity = 1;
        return;
    end
    if c_OH == 0
        if gamma_OH > 0
            oh_activity = 0;
        else
            ok = false;
            oh_activity = NaN;
        end
        return;
    end
    ratio = c_OH / c_OH_ref;
    if ratio <= 0
        ok = false;
        oh_activity = NaN;
        return;
    end
    log_term = gamma_OH * log(ratio);
    log_term = min(max(log_term, -exp_arg_max), exp_arg_max);
    oh_activity = exp(log_term);
    if ~(isfinite(oh_activity) && oh_activity >= 0)
        ok = false;
        oh_activity = NaN;
    end
end

function eta = ironair_metal_ode_inverse_bv( ...
        i_far, i0_eff, alpha_a, alpha_c, F, R, T, max_iter, tol, exp_arg_max)
    % Invert Butler-Volmer for eta given i_far.
    if i_far == 0
        eta = 0;
        return;
    end

    RT_inv = F / (R * T);
    ba = alpha_a * RT_inv;
    bc = alpha_c * RT_inv;

    if alpha_a == alpha_c
        % Analytical inverse symmetric Butler-Volmer (asinh form)
        alpha = alpha_a;
        eta = (R * T) / (alpha * F) * asinh(i_far / (2 * i0_eff));
        return;
    end

    % Asymmetric: Newton with bisection safeguard (bounded iterations)
    % Initial guess from symmetric asinh using alpha_a (sign-preserving seed only)
    alpha_seed = 0.5 * (alpha_a + alpha_c);
    eta = (R * T) / (alpha_seed * F) * asinh(i_far / (2 * i0_eff));

    % Bracket: overpotential sign matches current sign for alpha_a, alpha_c > 0
    if i_far > 0
        eta_lo = 0;
        eta_hi = max(eta, 0);
        f_hi = ironair_metal_ode_bv_residual(eta_hi, i_far, i0_eff, ba, bc, exp_arg_max);
        expand = 0;
        while f_hi < 0 && expand < max_iter
            eta_hi = max(eta_hi * 2, 1e-6);
            f_hi = ironair_metal_ode_bv_residual(eta_hi, i_far, i0_eff, ba, bc, exp_arg_max);
            expand = expand + 1;
        end
        if f_hi < 0
            eta = NaN;
            return;
        end
    else
        eta_hi = 0;
        eta_lo = min(eta, 0);
        f_lo = ironair_metal_ode_bv_residual(eta_lo, i_far, i0_eff, ba, bc, exp_arg_max);
        expand = 0;
        while f_lo > 0 && expand < max_iter
            eta_lo = min(eta_lo * 2, -1e-6);
            f_lo = ironair_metal_ode_bv_residual(eta_lo, i_far, i0_eff, ba, bc, exp_arg_max);
            expand = expand + 1;
        end
        if f_lo > 0
            eta = NaN;
            return;
        end
    end

    for iter = 1:max_iter
        [f, df] = ironair_metal_ode_bv_residual_jac( ...
            eta, i_far, i0_eff, ba, bc, exp_arg_max);
        if abs(f) <= tol * max(1, abs(i_far))
            return;
        end
        if abs(df) > 0 && isfinite(df)
            eta_new = eta - f / df;
        else
            eta_new = 0.5 * (eta_lo + eta_hi);
        end
        if ~(isfinite(eta_new))
            eta_new = 0.5 * (eta_lo + eta_hi);
        end
        % Keep inside bracket
        if eta_new <= eta_lo || eta_new >= eta_hi
            eta_new = 0.5 * (eta_lo + eta_hi);
        end
        f_new = ironair_metal_ode_bv_residual( ...
            eta_new, i_far, i0_eff, ba, bc, exp_arg_max);
        if f_new > 0
            eta_hi = eta_new;
        else
            eta_lo = eta_new;
        end
        eta = eta_new;
    end

    f_final = ironair_metal_ode_bv_residual(eta, i_far, i0_eff, ba, bc, exp_arg_max);
    if abs(f_final) > tol * max(1, abs(i_far))
        eta = NaN;
    end
end

function f = ironair_metal_ode_bv_residual(eta, i_far, i0_eff, ba, bc, exp_arg_max)
    ea = min(max(ba * eta, -exp_arg_max), exp_arg_max);
    ec = min(max(-bc * eta, -exp_arg_max), exp_arg_max);
    f = i0_eff * (exp(ea) - exp(ec)) - i_far;
end

function [f, df] = ironair_metal_ode_bv_residual_jac( ...
        eta, i_far, i0_eff, ba, bc, exp_arg_max)
    ea = min(max(ba * eta, -exp_arg_max), exp_arg_max);
    ec = min(max(-bc * eta, -exp_arg_max), exp_arg_max);
    exp_a = exp(ea);
    exp_c = exp(ec);
    f = i0_eff * (exp_a - exp_c) - i_far;
    df = i0_eff * (ba * exp_a + bc * exp_c);
end
