function [dx, outputs, diagnostics] = ironair_dc_bus_ode(t, x, inputs, p)
%IRONAIR_DC_BUS_ODE DC-link capacitor dynamics and bus loss.
%   [DX, OUTPUTS, DIAGNOSTICS] = IRONAIR_DC_BUS_ODE(T, X, INPUTS, P)
%
%   State x:
%     V_dc_V
%
%   Equation: DC-001 through DC-004
%   Requirements: SRS012, SRS007.

arguments
    t (1, 1) double
    x (1, 1) double
    inputs (1, 1) struct
    p (1, 1) struct
end

V_dc = x(1);
I_source = inputs.I_source_A;
I_load = inputs.I_load_A;
I_bus = I_source - I_load;
% DC-001
dV_dc_dt = I_bus ./ p.dc_bus.C_dc_F;
% DC-002
E_dc = 0.5 .* p.dc_bus.C_dc_F .* V_dc.^2;
% DC-003
dE_dc_dt = V_dc .* I_bus;
% DC-004
P_bus_loss = I_bus.^2 .* p.dc_bus.R_bus_Ohm;
dx = dV_dc_dt;
outputs = struct( ...
    "V_dc_V", V_dc, ...
    "dV_dc_dt", dV_dc_dt, ...
    "E_dc_J", E_dc, ...
    "dE_dc_dt", dE_dc_dt, ...
    "P_bus_loss_W", P_bus_loss, ...
    "I_bus_A", I_bus);
diagnostics = struct("t", t, "within_voltage_window", ...
    V_dc >= p.dc_bus.V_dc_min_V && V_dc <= p.dc_bus.V_dc_max_V);
end
