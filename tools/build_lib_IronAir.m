function build_lib_IronAir()
%BUILD_LIB_IRONAIR Create lib_IronAir.slx with Integrator-based first-order ODEs.
% No S-Functions. Continuous states use Simulink Integrator + dy/dt equations.
% Requirement IDs: SRS009, SSS001, SSS002, SRS017
root = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(root, 'src')));
addpath(root);
if evalin('base', 'exist(''IronAir'',''var'')') ~= 1
    lib_IronAir_init();
end
IronAir = evalin('base', 'IronAir'); %#ok<NASGU>
Nx = evalin('base', 'IronAir.Electrolyte.Nx');

libName = 'lib_IronAir';
libPath = fullfile(root, [libName '.slx']);
if bdIsLoaded(libName)
    close_system(libName, 0);
end
if isfile(libPath)
    delete(libPath);
end

new_system(libName, 'Library');
open_system(libName);

add_electrolyte_block(libName, Nx, [30 30 160 120]);
add_metal_block(libName, [30 150 180 280]);
add_orr_block(libName, Nx, [30 310 170 420]);
add_oer_block(libName, [30 450 160 530]);
add_h2_block(libName, [30 560 180 680]);
add_thermal_block(libName, [30 710 160 790]);
add_cell_block(libName, Nx, [220 30 400 200]);

add_matlab_fcn_block(libName, 'Stack_IronAir', ...
    'ironair_aggregate_vector(u, IronAir.Stack.nSeries, IronAir.Stack.nParallel)', ...
    'SSS010', [220 230 360 310], 8);
add_matlab_fcn_block(libName, 'Module_IronAir', ...
    'ironair_aggregate_vector(u, IronAir.Module.nSeries, IronAir.Module.nParallel)', ...
    'SSS010', [220 340 360 420], 8);
add_matlab_fcn_block(libName, 'Pack_IronAir', ...
    'ironair_aggregate_vector(u, IronAir.Pack.nSeries, IronAir.Pack.nParallel)', ...
    'SSS010 IRS002', [220 450 360 530], 8);
add_matlab_fcn_block(libName, 'Plant_BESS_Schedule', ...
    'ironair_plant_schedule_vector(u)', ...
    'SSS011 SRS006', [220 560 380 640], 2);
add_matlab_fcn_block(libName, 'DER_RideThrough_Monitors', ...
    'ironair_der_ride_through_vector(u)', ...
    'SSS012 SRS011 SRS013', [420 30 600 120], 3);
add_matlab_fcn_block(libName, 'Standards_Assert_ESS', ...
    'ironair_standards_assert_vector(u)', ...
    'SSS013 SRS012 SRS014 SRS015', [420 150 600 240], 4);

set_param(libName, 'Lock', 'off');
save_system(libName, libPath);
close_system(libName, 0);
fprintf('Built library %s (Integrator / first-order ODEs, no S-Functions)\n', libPath);
end

function add_electrolyte_block(lib, Nx, pos)
% dx/dt = f(x,i_app,T); x = c_OH
parent = [lib '/Electrolyte_1D'];
add_block('built-in/SubSystem', parent, 'Position', pos);
Simulink.SubSystem.deleteContents(parent);
add_block('simulink/Sources/In1', [parent '/i_app'], 'Position', [30 100 60 114]);
add_block('simulink/Sources/In1', [parent '/T'], 'Position', [30 140 60 154]);
add_block('simulink/Continuous/Integrator', [parent '/Integrator'], ...
    'Position', [280 40 310 70], ...
    'InitialCondition', 'IronAir.Electrolyte.c_init');
add_block('simulink/Signal Routing/Mux', [parent '/Mux'], 'Inputs', '3', ...
    'Position', [140 40 145 160]);
add_block('simulink/User-Defined Functions/Interpreted MATLAB Function', ...
    [parent '/dydt'], 'Position', [180 50 260 90], ...
    'MATLABFcn', 'ironair_sl_electrolyte_dydt(u)', ...
    'OutputDimensions', num2str(Nx));
add_block('simulink/Sinks/Out1', [parent '/c_OH'], 'Position', [360 45 390 59]);
% Mux: c, i_app, T
add_line(parent, 'Integrator/1', 'Mux/1');
add_line(parent, 'i_app/1', 'Mux/2');
add_line(parent, 'T/1', 'Mux/3');
add_line(parent, 'Mux/1', 'dydt/1');
add_line(parent, 'dydt/1', 'Integrator/1');
add_line(parent, 'Integrator/1', 'c_OH/1');
apply_mask(parent, 'Electrolyte_1D', 'SSS003 SRS003 SRS017');
end

function add_metal_block(lib, pos)
parent = [lib '/Metal_Electrode_1D'];
add_block('built-in/SubSystem', parent, 'Position', pos);
Simulink.SubSystem.deleteContents(parent);
add_block('simulink/Sources/In1', [parent '/i_app'], 'Position', [30 80 60 94]);
add_block('simulink/Sources/In1', [parent '/c_OH'], 'Position', [30 120 60 134]);
add_block('simulink/Sources/In1', [parent '/T'], 'Position', [30 160 60 174]);
add_block('simulink/Continuous/Integrator', [parent '/Integrator'], ...
    'Position', [300 40 330 70], ...
    'InitialCondition', 'IronAir.Metal.u_init');
add_block('simulink/Signal Routing/Mux', [parent '/Mux'], 'Inputs', '4', ...
    'Position', [120 40 125 180]);
add_block('simulink/User-Defined Functions/Interpreted MATLAB Function', ...
    [parent '/dydt'], 'Position', [170 40 250 80], ...
    'MATLABFcn', 'ironair_sl_metal_dydt(u)', 'OutputDimensions', '1');
add_block('simulink/User-Defined Functions/Interpreted MATLAB Function', ...
    [parent '/out'], 'Position', [170 120 250 160], ...
    'MATLABFcn', 'ironair_sl_metal_out(u)', 'OutputDimensions', '3');
add_block('simulink/Signal Routing/Demux', [parent '/Demux'], 'Outputs', '3', ...
    'Position', [280 120 285 180]);
add_block('simulink/Sinks/Out1', [parent '/u'], 'Position', [360 40 390 54]);
add_block('simulink/Sinks/Out1', [parent '/eta'], 'Position', [360 130 390 144]);
add_block('simulink/Sinks/Out1', [parent '/i_far'], 'Position', [360 170 390 184]);
add_line(parent, 'Integrator/1', 'Mux/1');
add_line(parent, 'i_app/1', 'Mux/2');
add_line(parent, 'c_OH/1', 'Mux/3');
add_line(parent, 'T/1', 'Mux/4');
add_line(parent, 'Mux/1', 'dydt/1');
add_line(parent, 'Mux/1', 'out/1');
add_line(parent, 'dydt/1', 'Integrator/1');
add_line(parent, 'out/1', 'Demux/1');
add_line(parent, 'Integrator/1', 'u/1');
add_line(parent, 'Demux/2', 'eta/1');
add_line(parent, 'Demux/3', 'i_far/1');
apply_mask(parent, 'Metal_Electrode_1D', 'SSS004 SRS002 SRS017');
end

function add_orr_block(lib, Nx, pos)
parent = [lib '/ORR_Electrode_1D'];
add_block('built-in/SubSystem', parent, 'Position', pos);
Simulink.SubSystem.deleteContents(parent);
add_block('simulink/Sources/In1', [parent '/i_app'], 'Position', [30 100 60 114]);
add_block('simulink/Sources/In1', [parent '/T'], 'Position', [30 140 60 154]);
add_block('simulink/Continuous/Integrator', [parent '/Integrator'], ...
    'Position', [300 40 330 70], ...
    'InitialCondition', 'IronAir.ORR.c_init');
add_block('simulink/Signal Routing/Mux', [parent '/Mux'], 'Inputs', '3', ...
    'Position', [120 40 125 160]);
add_block('simulink/User-Defined Functions/Interpreted MATLAB Function', ...
    [parent '/dydt'], 'Position', [170 40 250 80], ...
    'MATLABFcn', 'ironair_sl_orr_dydt(u)', 'OutputDimensions', num2str(Nx));
add_block('simulink/User-Defined Functions/Interpreted MATLAB Function', ...
    [parent '/etaFcn'], 'Position', [170 120 250 160], ...
    'MATLABFcn', 'ironair_sl_orr_eta(u)', 'OutputDimensions', '1');
add_block('simulink/Sinks/Out1', [parent '/c_O2'], 'Position', [360 45 390 59]);
add_block('simulink/Sinks/Out1', [parent '/eta'], 'Position', [360 130 390 144]);
add_line(parent, 'Integrator/1', 'Mux/1');
add_line(parent, 'i_app/1', 'Mux/2');
add_line(parent, 'T/1', 'Mux/3');
add_line(parent, 'Mux/1', 'dydt/1');
add_line(parent, 'Mux/1', 'etaFcn/1');
add_line(parent, 'dydt/1', 'Integrator/1');
add_line(parent, 'Integrator/1', 'c_O2/1');
add_line(parent, 'etaFcn/1', 'eta/1');
apply_mask(parent, 'ORR_Electrode_1D', 'SSS005 SRS002 SRS017');
end

function add_oer_block(lib, pos)
% Algebraic only (quasi-steady kinetics)
parent = [lib '/OER_Electrode_1D'];
add_block('built-in/SubSystem', parent, 'Position', pos);
Simulink.SubSystem.deleteContents(parent);
add_block('simulink/Sources/In1', [parent '/i_app'], 'Position', [30 50 60 64]);
add_block('simulink/Sources/In1', [parent '/T'], 'Position', [30 100 60 114]);
add_block('simulink/Signal Routing/Mux', [parent '/Mux'], 'Inputs', '2', ...
    'Position', [100 50 105 110]);
add_block('simulink/User-Defined Functions/Interpreted MATLAB Function', ...
    [parent '/out'], 'Position', [150 60 260 110], ...
    'MATLABFcn', 'ironair_sl_oer_out(u)', 'OutputDimensions', '2');
add_block('simulink/Signal Routing/Demux', [parent '/Demux'], 'Outputs', '2', ...
    'Position', [300 60 305 110]);
add_block('simulink/Sinks/Out1', [parent '/eta'], 'Position', [360 55 390 69]);
add_block('simulink/Sinks/Out1', [parent '/i_oer'], 'Position', [360 100 390 114]);
add_line(parent, 'i_app/1', 'Mux/1');
add_line(parent, 'T/1', 'Mux/2');
add_line(parent, 'Mux/1', 'out/1');
add_line(parent, 'out/1', 'Demux/1');
add_line(parent, 'Demux/1', 'eta/1');
add_line(parent, 'Demux/2', 'i_oer/1');
apply_mask(parent, 'OER_Electrode_1D', 'SSS006 SRS002');
end

function add_h2_block(lib, pos)
parent = [lib '/H2_Evolution'];
add_block('built-in/SubSystem', parent, 'Position', pos);
Simulink.SubSystem.deleteContents(parent);
add_block('simulink/Sources/In1', [parent '/eta_metal'], 'Position', [30 80 60 94]);
add_block('simulink/Sources/In1', [parent '/I_cell'], 'Position', [30 120 60 134]);
add_block('simulink/Sources/In1', [parent '/T'], 'Position', [30 160 60 174]);
add_block('simulink/Continuous/Integrator', [parent '/Integrator'], ...
    'Position', [300 40 330 70], 'InitialCondition', '0');
add_block('simulink/Signal Routing/Mux', [parent '/Mux'], 'Inputs', '4', ...
    'Position', [120 40 125 180]);
add_block('simulink/User-Defined Functions/Interpreted MATLAB Function', ...
    [parent '/dydt'], 'Position', [170 40 250 80], ...
    'MATLABFcn', 'ironair_sl_h2_dydt(u)', 'OutputDimensions', '1');
add_block('simulink/User-Defined Functions/Interpreted MATLAB Function', ...
    [parent '/out'], 'Position', [170 120 250 160], ...
    'MATLABFcn', 'ironair_sl_h2_out(u)', 'OutputDimensions', '4');
add_block('simulink/Signal Routing/Demux', [parent '/Demux'], 'Outputs', '4', ...
    'Position', [280 120 285 200]);
add_block('simulink/Sinks/Out1', [parent '/n_dot_H2'], 'Position', [360 120 390 134]);
add_block('simulink/Sinks/Out1', [parent '/V_H2'], 'Position', [360 150 390 164]);
add_block('simulink/Sinks/Out1', [parent '/eta_F'], 'Position', [360 180 390 194]);
add_block('simulink/Sinks/Out1', [parent '/i_H2'], 'Position', [360 210 390 224]);
add_line(parent, 'Integrator/1', 'Mux/1');
add_line(parent, 'eta_metal/1', 'Mux/2');
add_line(parent, 'I_cell/1', 'Mux/3');
add_line(parent, 'T/1', 'Mux/4');
add_line(parent, 'Mux/1', 'dydt/1');
add_line(parent, 'Mux/1', 'out/1');
add_line(parent, 'dydt/1', 'Integrator/1');
add_line(parent, 'out/1', 'Demux/1');
add_line(parent, 'Demux/1', 'n_dot_H2/1');
add_line(parent, 'Demux/2', 'V_H2/1');
add_line(parent, 'Demux/3', 'eta_F/1');
add_line(parent, 'Demux/4', 'i_H2/1');
apply_mask(parent, 'H2_Evolution', 'SSS007 SRS004 SRS017');
end

function add_thermal_block(lib, pos)
parent = [lib '/Thermal_Node_1D'];
add_block('built-in/SubSystem', parent, 'Position', pos);
Simulink.SubSystem.deleteContents(parent);
add_block('simulink/Sources/In1', [parent '/Q_gen'], 'Position', [30 100 60 114]);
add_block('simulink/Continuous/Integrator', [parent '/Integrator'], ...
    'Position', [280 50 310 80], ...
    'InitialCondition', 'IronAir.Thermal.T_init');
add_block('simulink/Signal Routing/Mux', [parent '/Mux'], 'Inputs', '2', ...
    'Position', [120 50 125 120]);
add_block('simulink/User-Defined Functions/Interpreted MATLAB Function', ...
    [parent '/dydt'], 'Position', [160 60 250 100], ...
    'MATLABFcn', 'ironair_sl_thermal_dydt(u)', 'OutputDimensions', '1');
add_block('simulink/Sinks/Out1', [parent '/T'], 'Position', [360 55 390 69]);
add_line(parent, 'Integrator/1', 'Mux/1');
add_line(parent, 'Q_gen/1', 'Mux/2');
add_line(parent, 'Mux/1', 'dydt/1');
add_line(parent, 'dydt/1', 'Integrator/1');
add_line(parent, 'Integrator/1', 'T/1');
apply_mask(parent, 'Thermal_Node_1D', 'SSS008 SRS007 SRS017');
end

function add_cell_block(lib, Nx, pos)
nState = 2 * Nx + 3;
parent = [lib '/Cell_IronAir'];
add_block('built-in/SubSystem', parent, 'Position', pos);
Simulink.SubSystem.deleteContents(parent);
add_block('simulink/Sources/In1', [parent '/I_cell'], 'Position', [30 120 60 134]);
add_block('simulink/Continuous/Integrator', [parent '/Integrator'], ...
    'Position', [320 40 350 80], ...
    'InitialCondition', 'ironair_sl_cell_y0()');
add_block('simulink/Signal Routing/Mux', [parent '/Mux'], 'Inputs', '2', ...
    'Position', [140 40 145 150]);
add_block('simulink/User-Defined Functions/Interpreted MATLAB Function', ...
    [parent '/dydt'], 'Position', [180 40 280 90], ...
    'MATLABFcn', 'ironair_sl_cell_dydt(u)', 'OutputDimensions', num2str(nState));
add_block('simulink/User-Defined Functions/Interpreted MATLAB Function', ...
    [parent '/out'], 'Position', [180 120 280 170], ...
    'MATLABFcn', 'ironair_sl_cell_out(u)', 'OutputDimensions', '7');
add_block('simulink/Signal Routing/Demux', [parent '/Demux'], 'Outputs', '7', ...
    'Position', [320 120 325 220]);
outs = {'Voltage_V','Current_A','SOC','Temperature_K', ...
    'H2_Rate_mol_s','H2_Volume_m3','FaradaicEfficiency'};
for k = 1:7
    add_block('simulink/Sinks/Out1', [parent '/' outs{k}], ...
        'Position', [380 110+25*(k-1) 410 124+25*(k-1)]);
end
add_line(parent, 'Integrator/1', 'Mux/1');
add_line(parent, 'I_cell/1', 'Mux/2');
add_line(parent, 'Mux/1', 'dydt/1');
add_line(parent, 'Mux/1', 'out/1');
add_line(parent, 'dydt/1', 'Integrator/1');
add_line(parent, 'out/1', 'Demux/1');
for k = 1:7
    add_line(parent, sprintf('Demux/%d', k), sprintf('%s/1', outs{k}));
end
apply_mask(parent, 'Cell_IronAir', 'SSS009 IRS001 SRS017');
end

function apply_mask(parent, name, reqIds)
maskObj = Simulink.Mask.create(parent);
maskObj.Description = sprintf(['Iron-Air first-order ODE block %s (Integrator + dy/dt). ', ...
    'No S-Functions. Requirements: %s'], name, reqIds);
maskObj.Help = sprintf(['Continuous first-order ODE realization using Simulink Integrator.\n', ...
    'Requirements: %s'], reqIds);
maskObj.Type = 'IronAir';
maskObj.Display = sprintf('fprintf(''%s'')', name);
end

function add_matlab_fcn_block(lib, name, expr, reqIds, pos, outDim)
parent = [lib '/' name];
add_block('built-in/SubSystem', parent, 'Position', pos);
Simulink.SubSystem.deleteContents(parent);
add_block('simulink/Sources/In1', [parent '/u'], 'Position', [30 50 60 64]);
add_block('simulink/User-Defined Functions/Interpreted MATLAB Function', ...
    [parent '/Fcn'], 'Position', [120 40 280 80], 'MATLABFcn', expr, ...
    'OutputDimensions', num2str(outDim));
add_block('simulink/Sinks/Out1', [parent '/y'], 'Position', [340 50 370 64]);
add_line(parent, 'u/1', 'Fcn/1');
add_line(parent, 'Fcn/1', 'y/1');
apply_mask(parent, name, reqIds);
end
