function map = ironair_cell_state_map(p)
%IRONAIR_CELL_STATE_MAP Index map for the coupled cell without allocating x0.

arguments
    p (1, 1) struct
end

n_nodes = 1;
if p.fidelity_level >= 2
    n_nodes = p.resolution.representative_groups;
end
if p.fidelity_level >= 3
    n_nodes = p.resolution.electrode_control_volumes;
end
n_gdl = p.resolution.oxygen_control_volumes;
n_metal = 4 * n_nodes;
map = struct();
map.n_nodes = n_nodes;
map.n_gdl = n_gdl;
map.metal = 1:n_metal;
map.her = n_metal + 1;
map.air = map.her + (1:3);
map.electrolyte = map.air(end) + (1:7);
map.gdl = map.electrolyte(end) + (1:(n_gdl + 1));
map.Q_throughput = map.gdl(end) + 1;
map.eta_dl_Fe = map.gdl(end) + 2;
map.eta_dl_air = map.gdl(end) + 3;
map.count = map.eta_dl_air;
end
