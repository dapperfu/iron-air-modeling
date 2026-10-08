function msfcn_ORR_Electrode_1D(block)
% Requirement IDs: SSS005
setup(block);
end

function setup(block)
block.NumInputPorts  = 2; % i_app, T
block.NumOutputPorts = 2; % cO2, eta
block.SetPreCompInpPortInfoToDynamic;
block.SetPreCompOutPortInfoToDynamic;
block.InputPort(1).Dimensions = 1;
block.InputPort(2).Dimensions = 1;
block.InputPort(1).DirectFeedthrough = true;
block.InputPort(2).DirectFeedthrough = true;
p = evalin('base', 'IronAir'); Nx = p.ORR.Nx;
block.OutputPort(1).Dimensions = Nx;
block.OutputPort(2).Dimensions = 1;
block.NumContStates = Nx;
block.SampleTimes = [0 0];
block.SimStateCompliance = 'DefaultSimState';
block.RegBlockMethod('InitializeConditions', @InitConditions);
block.RegBlockMethod('Outputs', @Outputs);
block.RegBlockMethod('Derivatives', @Derivatives);
end

function InitConditions(block)
p = evalin('base', 'IronAir');
block.ContStates.Data = p.ORR.c_init(:);
end

function Outputs(block)
p = evalin('base', 'IronAir');
c = block.ContStates.Data;
[~, eta] = ironair_orr_ode(c, block.InputPort(1).Data, block.InputPort(2).Data, p.ORR);
block.OutputPort(1).Data = c;
block.OutputPort(2).Data = eta;
end

function Derivatives(block)
p = evalin('base', 'IronAir');
[dc, ~] = ironair_orr_ode(block.ContStates.Data, block.InputPort(1).Data, ...
    block.InputPort(2).Data, p.ORR);
block.Derivatives.Data = dc(:);
end
