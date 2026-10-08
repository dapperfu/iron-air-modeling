function [x0, map] = ironair_cell_initial_state(p, I_cell_A)
%IRONAIR_CELL_INITIAL_STATE Pack the coupled electrochemical cell state.
%   [X0, MAP] = IRONAIR_CELL_INITIAL_STATE(P, I_CELL_A) returns a named state
%   map and inventories with double-layer overpotentials consistent with I.
%
%   Requirements: SRS001.2, SRS007.

arguments
    p (1, 1) struct
    I_cell_A (1, 1) double = 0
end

map = ironair_cell_state_map(p);
n_nodes = map.n_nodes;
n_gdl = map.n_gdl;
c_O2_gas = p.reference.x_O2_dry_air .* p.reference.p_ambient_Pa ./ ...
    (p.constants.R_J_molK .* p.reference.T_initial_K);

n_Fe = (p.cell_geometry.n_Fe_initial_mol / n_nodes) * ones(n_nodes, 1);
n_FeOH2 = (p.cell_geometry.n_FeOH2_initial_mol / n_nodes) * ones(n_nodes, 1);
n_Fe3O4 = zeros(n_nodes, 1);
delta_pass = zeros(n_nodes, 1);
x_metal = [n_Fe; n_FeOH2; n_Fe3O4; delta_pass];
x_her = 0;
x_air = [p.air_electrode.flooding_initial; p.orr_catalyst.activity_initial; ...
    p.oer_catalyst.activity_initial];
n_OH = p.electrolyte.c_OH_initial_mol_m3 * p.electrolyte.V_electrolyte_initial_m3;
n_K = p.electrolyte.c_K_initial_mol_m3 * p.electrolyte.V_electrolyte_initial_m3;
n_H2O = p.electrolyte.n_H2O_initial_mol;
n_O2 = p.electrolyte.c_O2_initial_mol_m3 * p.electrolyte.V_electrolyte_initial_m3;
n_CO2 = p.electrolyte.c_CO2_initial_mol_m3 * p.electrolyte.V_electrolyte_initial_m3;
n_CO3 = p.electrolyte.c_CO3_initial_mol_m3 * p.electrolyte.V_electrolyte_initial_m3;
x_ely = [n_OH; n_K; n_H2O; n_O2; n_CO2; n_CO3; p.electrolyte.V_electrolyte_initial_m3];
x_gdl = [c_O2_gas * ones(n_gdl, 1); p.air_electrode.flooding_initial];
eta_Fe0 = 0;
eta_air0 = 0;
if I_cell_A ~= 0
    metal_in = struct("T_Fe_K", p.reference.T_initial_K, "a_OH", 6, ...
        "I_Fe_A", I_cell_A, "n_nodes", n_nodes);
    [~, metal] = ironair_metal_ode(0, x_metal, metal_in, p);
    eta_Fe0 = mean(metal.eta_Fe_V);
    eta_air0 = -0.04 * sign(I_cell_A);
end
x_extra = [0; eta_Fe0; eta_air0];

x0 = [x_metal; x_her; x_air; x_ely; x_gdl; x_extra];
if numel(x0) ~= map.count
    error("ironair:cell:MapMismatch", "Initial state does not match the cell map.");
end
end
