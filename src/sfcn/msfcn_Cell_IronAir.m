function msfcn_Cell_IronAir(block)
% Full cell continuous ODE composition. Requirement IDs: SSS009, IRS001
setup(block);
end

function setup(block)
block.NumInputPorts  = 1; % I_cell
block.NumOutputPorts = 7;
block.SetPreCompInpPortInfoToDynamic;
block.SetPreCompOutPortInfoToDynamic;
block.InputPort(1).Dimensions = 1;
block.InputPort(1).DirectFeedthrough = true;
for k = 1:7
    block.OutputPort(k).Dimensions = 1;
end
IronAir = evalin('base', 'IronAir');
Nx = IronAir.Electrolyte.Nx;
block.NumContStates = 2 * Nx + 3; % cOH, cO2, u, T, nH2
block.SampleTimes = [0 0];
block.SimStateCompliance = 'DefaultSimState';
block.RegBlockMethod('InitializeConditions', @InitConditions);
block.RegBlockMethod('Outputs', @Outputs);
block.RegBlockMethod('Derivatives', @Derivatives);
end

function y0 = initial_state()
p = evalin('base', 'IronAir');
Nx = p.Electrolyte.Nx;
y0 = [p.Electrolyte.c_init(:); p.ORR.c_init(:); p.Metal.u_init; p.Thermal.T_init; 0];
assert(numel(y0) == 2 * Nx + 3);
end

function InitConditions(block)
block.ContStates.Data = initial_state();
end

function Outputs(block)
p = evalin('base', 'IronAir');
pb = p.CellBundle;
out = ironair_cell_outputs(block.ContStates.Data, block.InputPort(1).Data, pb);
block.OutputPort(1).Data = out.Voltage_V;
block.OutputPort(2).Data = out.Current_A;
block.OutputPort(3).Data = out.SOC;
block.OutputPort(4).Data = out.Temperature_K;
block.OutputPort(5).Data = out.H2_Rate_mol_s;
block.OutputPort(6).Data = out.H2_Volume_m3;
block.OutputPort(7).Data = out.FaradaicEfficiency;
end

function Derivatives(block)
p = evalin('base', 'IronAir');
[yp, ~] = ironair_cell_step(0, block.ContStates.Data, block.InputPort(1).Data, p.CellBundle);
block.Derivatives.Data = yp(:);
end
