function yp = ironair_sl_cell_dydt(u)
% u = [y_state(1:2*Nx+3); I_cell]
IronAir = evalin('base', 'IronAir');
Nx = IronAir.Electrolyte.Nx;
n = 2 * Nx + 3;
y = u(1:n);
I_cell = u(n + 1);
[yp, ~] = ironair_cell_step(0, y, I_cell, IronAir.CellBundle);
yp = yp(:);
end
