function [dx, outputs, diagnostics] = ironair_gas_diffusion_layer(t, x, inputs, p)
%IRONAIR_GAS_DIFFUSION_LAYER Oxygen diffusion, saturation, and capillary pressure.
%   [DX, OUTPUTS, DIAGNOSTICS] = IRONAIR_GAS_DIFFUSION_LAYER(T, X, INPUTS, P)
%
%   State x:
%     c_O2_mol_m3 over oxygen control volumes, then liquid saturation.
%
%   Equation: GDL-001 through GDL-006
%   Requirements: SRS006, SRS004.4.

arguments
    t (1, 1) double
    x (:, 1) double
    inputs (1, 1) struct
    p (1, 1) struct
end

n_cv = max(1, p.resolution.oxygen_control_volumes);
if numel(x) ~= n_cv + 1
    error("ironair:gdl:StateSize", ...
        "GDL state must contain oxygen cells plus liquid saturation.");
end
c_O2 = max(x(1:n_cv), 0);
S_liquid = min(max(x(end), 0), 1);
T = inputs.T_air_K;
p_gas = inputs.p_gas_Pa;
p_liquid = inputs.p_liquid_Pa;
% GDL-004
p_capillary = p_gas - p_liquid;
% GDL-005
p_capillary_pore = 2 .* p.gas_diffusion_layer.gamma_surface_N_m .* ...
    cos(p.gas_diffusion_layer.theta_contact_rad) ./ p.gas_diffusion_layer.r_pore_m;

D_bulk = ironair_gas_diffusivity(T, p_gas, p);
epsilon_g = p.gas_diffusion_layer.epsilon_g .* (1 - S_liquid);
tau_g = p.gas_diffusion_layer.tau_g ./ max(1 - S_liquid, 1e-3);
% GDL-002, GDL-006
D_O2_eff = D_bulk .* epsilon_g ./ tau_g;

dx_cell = p.gas_diffusion_layer.L_gdl_m / max(n_cv, 1);
R_O2 = zeros(n_cv, 1);
R_O2(end) = inputs.n_dot_O2_consumed_mol_s ./ ...
    max(p.air_electrode.A_geometric_air_m2 * dx_cell, 1e-12);
if n_cv == 1
    c_boundary = inputs.c_O2_gas_mol_m3;
    grad_c_O2 = (c_O2 - c_boundary) / dx_cell;
    % GDL-001: Fickian oxygen diffusion. Constitutive equation.
    N_O2 = -D_O2_eff .* grad_c_O2;
    % GDL-003: transient oxygen concentration. Conservation law.
    dc_O2_dt = (-N_O2 / dx_cell) - R_O2;
else
    D_field = D_O2_eff * ones(n_cv, 1);
    phi = zeros(n_cv, 1);
    [div_N, N_faces, grad_c] = ironair_finite_volume_1d(c_O2, D_field, 0, ...
        phi, 0, dx_cell, T, p.constants);
    % GDL-001: Fickian flux at the gas boundary. Constitutive equation.
    N_faces(1) = -D_O2_eff * (c_O2(1) - inputs.c_O2_gas_mol_m3) / dx_cell;
    div_N = (N_faces(2:end) - N_faces(1:end-1)) / dx_cell;
    % GDL-003: finite-volume divergence minus reaction. Conservation law.
    dc_O2_dt = -div_N - R_O2;
    grad_c_O2 = grad_c;
    N_O2 = N_faces;
end

dS_dt = p.air_electrode.k_flood_1_s .* S_liquid .* 0;
dx = [dc_O2_dt; dS_dt];
outputs = struct( ...
    "c_O2_mol_m3", c_O2, ...
    "S_liquid", S_liquid, ...
    "D_O2_eff_m2_s", D_O2_eff, ...
    "N_O2_mol_m2s", N_O2, ...
    "grad_c_O2_mol_m4", grad_c_O2, ...
    "p_capillary_Pa", p_capillary, ...
    "p_capillary_pore_Pa", p_capillary_pore, ...
    "epsilon_g_S", epsilon_g);
diagnostics = struct("t", t, "min_c_O2", min(c_O2));
end
