function msfcn_Thermal_Node_1D(block)
% Requirement IDs: SSS008
setup(block);
end

function setup(block)
block.NumInputPorts  = 1; % Q_gen
block.NumOutputPorts = 1; % T
block.SetPreCompInpPortInfoToDynamic;
block.SetPreCompOutPortInfoToDynamic;
block.InputPort(1).Dimensions = 1;
block.InputPort(1).DirectFeedthrough = false;
block.OutputPort(1).Dimensions = 1;
block.NumContStates = 1;
block.SampleTimes = [0 0];
block.SimStateCompliance = 'DefaultSimState';
block.RegBlockMethod('InitializeConditions', @InitConditions);
block.RegBlockMethod('Outputs', @Outputs);
block.RegBlockMethod('Derivatives', @Derivatives);
end

function InitConditions(block)
p = evalin('base', 'IronAir');
block.ContStates.Data = p.Thermal.T_init;
end

function Outputs(block)
block.OutputPort(1).Data = block.ContStates.Data;
end

function Derivatives(block)
p = evalin('base', 'IronAir');
block.Derivatives.Data = ironair_thermal_ode(block.ContStates.Data, ...
    block.InputPort(1).Data, p.Thermal);
end
