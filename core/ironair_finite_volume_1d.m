function [div_N, N_faces, grad_c] = ironair_finite_volume_1d(c, D, z, phi, v, dx, T_K, constants)
%IRONAIR_FINITE_VOLUME_1D Discretize one-dimensional Nernst-Planck transport.
%   [DIV_N, N_FACES, GRAD_C] = IRONAIR_FINITE_VOLUME_1D(...) returns cell
%   divergences of species flux using harmonic-mean diffusivities.
%
%   Inputs:
%     c         - Cell concentrations, n_cells-by-n_species, mol/m3.
%     D         - Cell diffusivities, same size, m2/s.
%     z         - Species charges, 1-by-n_species.
%     phi       - Ionic potential at cell centers, V.
%     v         - Superficial velocity at interior faces, m/s.
%     dx        - Cell width, m.
%     T_K       - Temperature, K.
%     constants - Physical constants.
%
%   Outputs:
%     div_N   - Divergence of flux at cells, mol/(m3 s).
%     N_faces - Face fluxes including boundaries, mol/(m2 s).
%     grad_c  - Interior concentration gradients, mol/m4.
%
%   Equation: ELY-001, ELY-002, GDL-001, GDL-003
%   Requirements: SRS005.1, SRS006, SRS018.

arguments
    c (:, :) double
    D (:, :) double
    z (1, :) double
    phi (:, 1) double
    v (:, 1) double
    dx (1, 1) double {mustBePositive}
    T_K (1, 1) double {mustBePositive}
    constants (1, 1) struct
end

[n_cells, n_species] = size(c);
if n_cells < 2
    error("ironair:fv:NeedTwoCells", ...
        "Finite-volume transport requires at least two control volumes.");
end

D_faces = 2 ./ (1 ./ D(1:end-1, :) + 1 ./ D(2:end, :));
grad_c = (c(2:end, :) - c(1:end-1, :)) ./ dx;
grad_phi = (phi(2:end) - phi(1:end-1)) ./ dx;
c_faces = 0.5 * (c(1:end-1, :) + c(2:end, :));
if numel(v) == 1
    v_faces = repmat(v, n_cells - 1, 1);
else
    v_faces = v;
end
mig_coeff = (constants.F_C_mol ./ (constants.R_J_molK .* T_K)) .* z;
% ELY-001
N_interior = -D_faces .* grad_c ...
    - D_faces .* c_faces .* (grad_phi * mig_coeff) ...
    + c_faces .* v_faces;

N_faces = zeros(n_cells + 1, n_species);
N_faces(2:end-1, :) = N_interior;
% Zero-flux default boundaries; callers overwrite electrode faces.
div_N = (N_faces(2:end, :) - N_faces(1:end-1, :)) ./ dx;
end
