function map = ironair_system_layout(p)
%IRONAIR_SYSTEM_LAYOUT Index the coupled cell and balance-of-plant states.
%   MAP = IRONAIR_SYSTEM_LAYOUT(P) matches ironair_system_initial_state.
%
%   Requirements: SRS001.2, SRS018.

arguments
    p (1, 1) struct
end

cell_map = ironair_cell_state_map(p);
n_cell = cell_map.count;
cursor = n_cell;
map = struct();
map.cell = cell_map;
map.n_cell = n_cell;
map.thermal = take(3);
map.air_system = take(3);
map.flow = take(2);
map.dc = take(1);
map.converter = take(2);
map.inverter = take(2);
map.transformer = take(1);
map.controller = take(1);
map.ride = take(1);
map.degradation = take(3);
map.sensor = take(2);
map.enclosure = take(1);
map.count = cursor;

    function indices = take(count)
        indices = cursor + (1:count);
        cursor = cursor + count;
    end
end
