function msfcn_Metal_Electrode_1D(block)
% Level-2 MATLAB S-Function: Metal utilization continuous ODE
% Requirement IDs: SSS004
setup(block);
end

function setup(block)
block.NumInputPorts  = 3; % i_app, c_OH_mean, T
block.NumOutputPorts = 3; % u, eta, i_far
block.SetPreCompInpPortInfoToDynamic;
block.SetPreCompOutPortInfoToDynamic;
for k = 1:3
    block.InputPort(k).Dimensions = 1;
    block.InputPort(k).DirectFeedthrough = true;
end
block.OutputPort(1).Dimensions = 1;
block.OutputPort(2).Dimensions = 1;
block.OutputPort(3).Dimensions = 1;
block.NumContStates = 1;
block.SampleTimes = [0 0];
block.SimStateCompliance = 'DefaultSimState';
block.RegBlockMethod('InitializeConditions', @InitConditions);
block.RegBlockMethod('Outputs', @Outputs);
block.RegBlockMethod('Derivatives', @Derivatives);
end

function p = getp()
IronAir = evalin('base', 'IronAir');
p = IronAir.Metal;
end

function InitConditions(block)
p = getp();
block.ContStates.Data = p.u_init;
end

function Outputs(block)
p = getp();
u = block.ContStates.Data;
i_app = block.InputPort(1).Data;
c_OH = block.InputPort(2).Data;
T = block.InputPort(3).Data;
[~, eta, i_far] = ironair_metal_ode(u, i_app, c_OH, T, p);
block.OutputPort(1).Data = u;
block.OutputPort(2).Data = eta;
block.OutputPort(3).Data = i_far;
end

function Derivatives(block)
p = getp();
u = block.ContStates.Data;
i_app = block.InputPort(1).Data;
c_OH = block.InputPort(2).Data;
T = block.InputPort(3).Data;
[du_dt, ~, ~] = ironair_metal_ode(u, i_app, c_OH, T, p);
block.Derivatives.Data = du_dt;
end
