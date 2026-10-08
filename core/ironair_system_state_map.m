function map = ironair_system_state_map(p)
%IRONAIR_SYSTEM_STATE_MAP Index map for the coupled plant without allocating x0.

arguments
    p (1, 1) struct
end

cell_map = ironair_cell_state_map(p);
n = cell_map.count;
map = struct();
map.cell = 1:n;
map.thermal = n + (1:5); n = n + 5;
map.airsys = n + (1:5); n = n + 5;
map.flow = n + (1:5); n = n + 5;
map.enclosure = n + 1; n = n + 1;
map.dc = n + 1; n = n + 1;
map.converter = n + (1:2); n = n + 2;
map.inverter = n + (1:2); n = n + 2;
map.transformer = n + 1; n = n + 1;
map.grid = n + (1:5); n = n + 5;
map.control = n + (1:4); n = n + 4;
map.estimator = n + (1:4); n = n + 4;
map.degradation = n + (1:4); n = n + 4;
map.sensors = n + (1:6); n = n + 6;
map.ledger = n + (1:6);
map.cell_map = cell_map;
map.count = n + 6;
end
