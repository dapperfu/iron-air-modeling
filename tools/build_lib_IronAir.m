function build_lib_IronAir()
%BUILD_LIB_IRONAIR Create lib_IronAir.slx with masked first-principles blocks.
% Requirement IDs: SRS009, SSS001
root = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(root, 'src')));
addpath(root);
if evalin('base', 'exist(''IronAir'',''var'')') ~= 1
    lib_IronAir_init();
end

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

% Atomic S-Function wrappers
add_masked_sfcn(libName, 'Electrolyte_1D', 'msfcn_Electrolyte_1D', ...
    {'i_app','T'}, {'c_OH'}, 'SSS003 SRS003', [30 30 130 100]);
add_masked_sfcn(libName, 'Metal_Electrode_1D', 'msfcn_Metal_Electrode_1D', ...
    {'i_app','c_OH','T'}, {'u','eta','i_far'}, 'SSS004 SRS002', [30 140 150 230]);
add_masked_sfcn(libName, 'ORR_Electrode_1D', 'msfcn_ORR_Electrode_1D', ...
    {'i_app','T'}, {'c_O2','eta'}, 'SSS005 SRS002', [30 260 140 340]);
add_masked_sfcn(libName, 'OER_Electrode_1D', 'msfcn_OER_Electrode_1D', ...
    {'i_app','T'}, {'eta','i_oer'}, 'SSS006 SRS002', [30 370 140 450]);
add_masked_sfcn(libName, 'H2_Evolution', 'msfcn_H2_Evolution', ...
    {'eta_metal','I_cell','T'}, {'n_dot_H2','V_H2','eta_F','i_H2'}, ...
    'SSS007 SRS004', [30 480 160 580]);
add_masked_sfcn(libName, 'Thermal_Node_1D', 'msfcn_Thermal_Node_1D', ...
    {'Q_gen'}, {'T'}, 'SSS008 SRS007', [30 610 130 680]);
add_masked_sfcn(libName, 'Cell_IronAir', 'msfcn_Cell_IronAir', ...
    {'I_cell'}, {'Voltage_V','Current_A','SOC','Temperature_K', ...
    'H2_Rate_mol_s','H2_Volume_m3','FaradaicEfficiency'}, ...
    'SSS009 IRS001', [220 30 380 160]);

% Aggregation / plant / monitors as MATLAB Function subsystems (Interpreted)
add_matlab_fcn_block(libName, 'Stack_IronAir', ...
    'ironair_aggregate_vector(u, IronAir.Stack.nSeries, IronAir.Stack.nParallel)', ...
    'SSS010', [220 200 360 280], 8);
add_matlab_fcn_block(libName, 'Module_IronAir', ...
    'ironair_aggregate_vector(u, IronAir.Module.nSeries, IronAir.Module.nParallel)', ...
    'SSS010', [220 310 360 390], 8);
add_matlab_fcn_block(libName, 'Pack_IronAir', ...
    'ironair_aggregate_vector(u, IronAir.Pack.nSeries, IronAir.Pack.nParallel)', ...
    'SSS010 IRS002', [220 420 360 500], 8);
add_matlab_fcn_block(libName, 'Plant_BESS_Schedule', ...
    'ironair_plant_schedule_vector(u)', ...
    'SSS011 SRS006', [220 530 380 610], 2);
add_matlab_fcn_block(libName, 'DER_RideThrough_Monitors', ...
    'ironair_der_ride_through_vector(u)', ...
    'SSS012 SRS011 SRS013', [420 30 600 120], 3);
add_matlab_fcn_block(libName, 'Standards_Assert_ESS', ...
    'ironair_standards_assert_vector(u)', ...
    'SSS013 SRS012 SRS014 SRS015', [420 150 600 240], 4);

set_param(libName, 'Lock', 'off');
save_system(libName, libPath);
close_system(libName, 0);
fprintf('Built library %s\n', libPath);
end

function add_masked_sfcn(lib, name, sfcn, inNames, outNames, reqIds, pos)
parent = [lib '/' name];
add_block('built-in/SubSystem', parent, 'Position', pos);
% Clear default
Simulink.SubSystem.deleteContents(parent);
nIn = numel(inNames);
nOut = numel(outNames);
sfcnPath = [parent '/SFcn'];
add_block('simulink/User-Defined Functions/Level-2 MATLAB S-Function', sfcnPath, ...
    'Position', [150 50 250 50+30*max(nIn,nOut)], ...
    'FunctionName', sfcn);
for i = 1:nIn
    ip = sprintf('%s/%s', parent, inNames{i});
    add_block('simulink/Sources/In1', ip, 'Position', [30 40+40*(i-1) 60 54+40*(i-1)]);
    add_line(parent, sprintf('%s/1', inNames{i}), sprintf('SFcn/%d', i));
end
for i = 1:nOut
    op = sprintf('%s/%s', parent, outNames{i});
    add_block('simulink/Sinks/Out1', op, 'Position', [320 40+40*(i-1) 350 54+40*(i-1)]);
    add_line(parent, sprintf('SFcn/%d', i), sprintf('%s/1', outNames{i}));
end
maskObj = Simulink.Mask.create(parent);
maskObj.Description = sprintf('Iron-Air library block %s. Requirements: %s', name, reqIds);
maskObj.Help = sprintf('First-principles continuous ODE block.\nRequirements: %s', reqIds);
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
maskObj = Simulink.Mask.create(parent);
maskObj.Description = sprintf('%s. Requirements: %s', name, reqIds);
maskObj.Help = sprintf('Requirements: %s', reqIds);
maskObj.Display = sprintf('fprintf(''%s'')', name);
end
