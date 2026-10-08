function msfcn_Electrolyte_1D(block)
% Level-2 MATLAB S-Function: Electrolyte_1D continuous ODE
% Requirement IDs: SSS003
setup(block);
end

function setup(block)
block.NumInputPorts  = 2; % i_app, T
block.NumOutputPorts = 1; % c_OH vector
block.SetPreCompInpPortInfoToDynamic;
block.SetPreCompOutPortInfoToDynamic;
block.InputPort(1).Dimensions = 1;
block.InputPort(2).Dimensions = 1;
block.InputPort(1).DirectFeedthrough = false;
block.InputPort(2).DirectFeedthrough = false;
p = get_param_bundle();
Nx = p.Nx;
block.OutputPort(1).Dimensions = Nx;
block.NumContStates = Nx;
block.NumDialogPrms = 0;
block.SampleTimes = [0 0];
block.SimStateCompliance = 'DefaultSimState';
block.RegBlockMethod('InitializeConditions', @InitConditions);
block.RegBlockMethod('Outputs', @Outputs);
block.RegBlockMethod('Derivatives', @Derivatives);
end

function p = get_param_bundle()
IronAir = evalin('base', 'IronAir');
p = IronAir.Electrolyte;
end

function InitConditions(block)
p = get_param_bundle();
block.ContStates.Data = p.c_init(:);
end

function Outputs(block)
block.OutputPort(1).Data = block.ContStates.Data;
end

function Derivatives(block)
p = get_param_bundle();
p.T = block.InputPort(2).Data;
i_app = block.InputPort(1).Data;
c = block.ContStates.Data;
block.Derivatives.Data = ironair_electrolyte_ode(c, i_app, p);
end
