function msfcn_OER_Electrode_1D(block)
% Algebraic OER overpotential (no continuous state). Requirement IDs: SSS006
setup(block);
end

function setup(block)
block.NumInputPorts  = 2; % i_app (A/m^2), T
block.NumOutputPorts = 2; % eta, i_oer
block.SetPreCompInpPortInfoToDynamic;
block.SetPreCompOutPortInfoToDynamic;
block.InputPort(1).Dimensions = 1;
block.InputPort(2).Dimensions = 1;
block.InputPort(1).DirectFeedthrough = true;
block.InputPort(2).DirectFeedthrough = true;
block.OutputPort(1).Dimensions = 1;
block.OutputPort(2).Dimensions = 1;
block.NumContStates = 0;
block.SampleTimes = [0 0];
block.SimStateCompliance = 'DefaultSimState';
block.RegBlockMethod('Outputs', @Outputs);
end

function Outputs(block)
p = evalin('base', 'IronAir');
[eta, i_oer] = ironair_oer_ode(block.InputPort(1).Data, block.InputPort(2).Data, p.OER);
block.OutputPort(1).Data = eta;
block.OutputPort(2).Data = i_oer;
end
