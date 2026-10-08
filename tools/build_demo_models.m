function build_demo_models()
%BUILD_DEMO_MODELS Create cell, stack, and plant demo models.
root = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(root, 'src')));
addpath(root);
addpath(fullfile(root, 'tools'));
lib_IronAir_init();
if ~isfile(fullfile(root, 'lib_IronAir.slx'))
    build_lib_IronAir();
end
modelsDir = fullfile(root, 'models');
if ~exist(modelsDir, 'dir'); mkdir(modelsDir); end

build_cell_demo(modelsDir);
build_stack_demo(modelsDir);
build_plant_demo(modelsDir);
end

function build_cell_demo(modelsDir)
name = 'demo_Cell_IronAir';
path = fullfile(modelsDir, [name '.slx']);
if bdIsLoaded(name); close_system(name, 0); end
if isfile(path); delete(path); end
new_system(name);
open_system(name);
load_system('lib_IronAir');
add_block('simulink/Sources/Constant', [name '/I_cell'], 'Value', '1.0', ...
    'Position', [50 100 80 130]);
add_block('lib_IronAir/Cell_IronAir', [name '/Cell'], 'Position', [150 60 280 180]);
add_block('simulink/Sinks/Scope', [name '/ScopeV'], 'Position', [400 70 430 100]);
add_line(name, 'I_cell/1', 'Cell/1');
add_line(name, 'Cell/1', 'ScopeV/1');
cfg = getActiveConfigSet(name);
set_param(cfg, 'Solver', 'ode15s', 'StopTime', '3600', 'RelTol', '1e-4');
save_system(name, path);
close_system(name, 0);
fprintf('Wrote %s\n', path);
end

function build_stack_demo(modelsDir)
name = 'demo_Stack_IronAir';
path = fullfile(modelsDir, [name '.slx']);
if bdIsLoaded(name); close_system(name, 0); end
if isfile(path); delete(path); end
new_system(name);
open_system(name);
load_system('lib_IronAir');
add_block('simulink/Sources/Constant', [name '/I_cell'], 'Value', '1.0', ...
    'Position', [40 120 70 150]);
add_block('lib_IronAir/Cell_IronAir', [name '/Cell'], 'Position', [120 60 250 200]);
add_block('simulink/Signal Routing/Mux', [name '/Mux'], 'Inputs', '7', ...
    'Position', [300 60 305 200]);
add_block('lib_IronAir/Stack_IronAir', [name '/Stack'], 'Position', [360 100 500 160]);
add_block('simulink/Sinks/Scope', [name '/Scope'], 'Position', [560 110 590 140]);
add_line(name, 'I_cell/1', 'Cell/1');
for k = 1:7
    add_line(name, sprintf('Cell/%d', k), sprintf('Mux/%d', k));
end
add_line(name, 'Mux/1', 'Stack/1');
add_line(name, 'Stack/1', 'Scope/1');
set_param(getActiveConfigSet(name), 'Solver', 'ode15s', 'StopTime', '1800');
save_system(name, path);
close_system(name, 0);
fprintf('Wrote %s\n', path);
end

function build_plant_demo(modelsDir)
name = 'demo_Plant_EnergyArb_24_100h';
path = fullfile(modelsDir, [name '.slx']);
if bdIsLoaded(name); close_system(name, 0); end
if isfile(path); delete(path); end
new_system(name);
open_system(name);
load_system('lib_IronAir');

% 48 h schedule: discharge days, charge nights (From Workspace via Constant for portability)
% Use clock + MATLAB fcn for schedule
add_block('simulink/Sources/Clock', [name '/Clock'], 'Position', [40 80 70 110]);
add_block('simulink/User-Defined Functions/Interpreted MATLAB Function', ...
    [name '/Schedule'], 'MATLABFcn', 'ironair_demo_schedule(u)', ...
    'OutputDimensions', '1', 'Position', [120 70 280 120]);
add_block('lib_IronAir/Cell_IronAir', [name '/Cell'], 'Position', [480 40 620 180]);
add_block('simulink/Signal Routing/Mux', [name '/MuxCell'], 'Inputs', '7', ...
    'Position', [660 40 665 180]);
add_block('lib_IronAir/Pack_IronAir', [name '/Pack'], 'Position', [720 80 860 140]);
add_block('lib_IronAir/Plant_BESS_Schedule', [name '/Plant'], 'Position', [320 60 450 120]);
add_block('simulink/Sources/Constant', [name '/Vpack0'], 'Value', '200', ...
    'Position', [200 150 230 180]);
add_block('simulink/Signal Routing/Mux', [name '/MuxPlant'], 'Inputs', '2', ...
    'Position', [270 70 275 130]);
add_block('simulink/Sources/Constant', [name '/Vpu'], 'Value', '1.0', ...
    'Position', [40 250 70 280]);
add_block('simulink/Sources/Constant', [name '/fHz'], 'Value', '60', ...
    'Position', [40 300 70 330]);
% Inject ride-through event via pulse
add_block('simulink/Sources/Step', [name '/Vdip'], 'Time', '3600*6', ...
    'Before', '1.0', 'After', '0.85', 'Position', [40 360 70 390]);
add_block('simulink/Signal Routing/Mux', [name '/MuxDER'], 'Inputs', '2', ...
    'Position', [120 300 125 380]);
add_block('lib_IronAir/DER_RideThrough_Monitors', [name '/DER'], ...
    'Position', [180 310 340 370]);
add_block('simulink/Signal Routing/Mux', [name '/MuxStd'], 'Inputs', '4', ...
    'Position', [900 200 905 280]);
add_block('lib_IronAir/Standards_Assert_ESS', [name '/Std'], ...
    'Position', [960 210 1120 270]);
add_block('simulink/Sinks/To Workspace', [name '/logPack'], ...
    'VariableName', 'pack_log', 'Position', [920 90 980 120]);
add_block('simulink/Sinks/To Workspace', [name '/logDER'], ...
    'VariableName', 'der_log', 'Position', [400 320 460 350]);

add_line(name, 'Clock/1', 'Schedule/1');
add_line(name, 'Schedule/1', 'MuxPlant/1');
add_line(name, 'Vpack0/1', 'MuxPlant/2');
add_line(name, 'MuxPlant/1', 'Plant/1');
% Plant y = [P_dc; I_pack] -> use I_pack (port via demux)
add_block('simulink/Signal Routing/Demux', [name '/DemuxPlant'], 'Outputs', '2', ...
    'Position', [460 70 465 110]);
add_line(name, 'Plant/1', 'DemuxPlant/1');
add_line(name, 'DemuxPlant/2', 'Cell/1');
for k = 1:7
    add_line(name, sprintf('Cell/%d', k), sprintf('MuxCell/%d', k));
end
add_line(name, 'MuxCell/1', 'Pack/1');
add_line(name, 'Pack/1', 'logPack/1');
add_line(name, 'Vdip/1', 'MuxDER/1');
add_line(name, 'fHz/1', 'MuxDER/2');
add_line(name, 'MuxDER/1', 'DER/1');
add_line(name, 'DER/1', 'logDER/1');
% Standards: T, H2, SOC, Power from pack vector indices via selector approx constants
add_block('simulink/Sources/Constant', [name '/Tref'], 'Value', '300', 'Position', [820 200 850 230]);
add_block('simulink/Sources/Constant', [name '/H2ref'], 'Value', '0.001', 'Position', [820 240 850 270]);
add_block('simulink/Sources/Constant', [name '/SOCref'], 'Value', '0.5', 'Position', [820 280 850 310]);
add_block('simulink/Sources/Constant', [name '/Pref'], 'Value', '1000', 'Position', [820 320 850 350]);
add_line(name, 'Tref/1', 'MuxStd/1');
add_line(name, 'H2ref/1', 'MuxStd/2');
add_line(name, 'SOCref/1', 'MuxStd/3');
add_line(name, 'Pref/1', 'MuxStd/4');
add_line(name, 'MuxStd/1', 'Std/1');

set_param(getActiveConfigSet(name), 'Solver', 'ode15s', ...
    'StopTime', 'num2str(IronAir.Plant.t_end_h*3600)', 'RelTol', '1e-3', ...
    'MaxStep', '60');
% Fix StopTime - cannot use num2str in set_param that way
set_param(name, 'StopTime', '172800'); % 48 h
save_system(name, path);
close_system(name, 0);
fprintf('Wrote %s\n', path);
end
