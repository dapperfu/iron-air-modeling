function msfcn_H2_Evolution(block)
% Continuous cumulative H2 moles + algebraic rates. Requirement IDs: SSS007
setup(block);
end

function setup(block)
block.NumInputPorts  = 3; % eta_metal, I_cell, T
block.NumOutputPorts = 4; % n_dot, V_H2_cum, eta_F, i_H2
block.SetPreCompInpPortInfoToDynamic;
block.SetPreCompOutPortInfoToDynamic;
for k = 1:3
    block.InputPort(k).Dimensions = 1;
    block.InputPort(k).DirectFeedthrough = true;
end
for k = 1:4
    block.OutputPort(k).Dimensions = 1;
end
block.NumContStates = 1; % cumulative moles
block.SampleTimes = [0 0];
block.SimStateCompliance = 'DefaultSimState';
block.RegBlockMethod('InitializeConditions', @InitConditions);
block.RegBlockMethod('Outputs', @Outputs);
block.RegBlockMethod('Derivatives', @Derivatives);
end

function InitConditions(block)
block.ContStates.Data = 0;
end

function Outputs(block)
p = evalin('base', 'IronAir');
[n_dot, V_dot, eta_F, i_H2] = ironair_h2_evolution( ...
    block.InputPort(1).Data, block.InputPort(2).Data, block.InputPort(3).Data, p.H2); %#ok<ASGLU>
C = ironair_constants();
T = block.InputPort(3).Data;
V_cum = block.ContStates.Data * C.R * T / C.P_atm;
block.OutputPort(1).Data = n_dot;
block.OutputPort(2).Data = V_cum;
block.OutputPort(3).Data = eta_F;
block.OutputPort(4).Data = i_H2;
end

function Derivatives(block)
p = evalin('base', 'IronAir');
[n_dot, ~, ~, ~] = ironair_h2_evolution( ...
    block.InputPort(1).Data, block.InputPort(2).Data, block.InputPort(3).Data, p.H2);
block.Derivatives.Data = n_dot;
end
