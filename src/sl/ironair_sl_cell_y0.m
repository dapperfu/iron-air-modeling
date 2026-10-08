function y0 = ironair_sl_cell_y0()
% Initial state for Cell_IronAir Integrator
IronAir = evalin('base', 'IronAir');
p = IronAir;
y0 = [p.Electrolyte.c_init(:); p.ORR.c_init(:); p.Metal.u_init; p.Thermal.T_init; 0];
end
