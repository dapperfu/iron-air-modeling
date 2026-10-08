function [dx, outputs, diagnostics] = ironair_dcdc_converter(t, x, inputs, p)
%IRONAIR_DCDC_CONVERTER Averaged bidirectional converter.
%   [DX, OUTPUTS, DIAGNOSTICS] = IRONAIR_DCDC_CONVERTER(T, X, INPUTS, P)
%   uses the buck state equation when the output is at or below the input,
%   and the boost state equation otherwise.
%
%   State x:
%     i_L_A, V_out_V
%
%   Equation: CONV-001 through CONV-006
%   Requirements: SRS012, SRS018.

arguments
    t (1, 1) double
    x (2, 1) double
    inputs (1, 1) struct
    p (1, 1) struct
end

i_L = x(1);
V_out = x(2);
V_in = max(inputs.V_in_V, 1e-6);
I_out = inputs.I_out_A;
d_duty = min(max(inputs.d_duty, 0), 1 - 1e-4);
topology = "buck";
% CONV-001: averaged buck inductor equation. Boost uses its own inductor law.
if V_out <= V_in + 1e-9
    di_L_dt = (d_duty .* V_in - V_out) ./ p.dcdc_converter.L_converter_H;
    % CONV-002: buck output capacitor.
    dV_out_dt = (i_L - I_out) ./ p.dcdc_converter.C_out_F;
else
    topology = "boost";
    di_L_dt = (V_in - (1 - d_duty) .* V_out) ./ p.dcdc_converter.L_converter_H;
    % Boost capacitor current is the diode current, (1-d)*i_L - I_out.
    dV_out_dt = ((1 - d_duty) .* i_L - I_out) ./ p.dcdc_converter.C_out_F;
end
% CONV-004 and CONV-005
I_RMS = abs(i_L);
P_conduction = I_RMS.^2 .* p.dcdc_converter.R_equivalent_Ohm;
P_switching = p.dcdc_converter.f_switching_Hz .* ...
    (p.dcdc_converter.E_on_J + p.dcdc_converter.E_off_J);
P_converter_loss = P_conduction + P_switching;
E_L = 0.5 .* p.dcdc_converter.L_converter_H .* i_L.^2;
E_C = 0.5 .* p.dcdc_converter.C_out_F .* V_out.^2;
dE_converter_dt = p.dcdc_converter.L_converter_H .* i_L .* di_L_dt + ...
    p.dcdc_converter.C_out_F .* V_out .* dV_out_dt;
if topology == "buck"
    P_in = d_duty .* V_in .* i_L;
    P_out = V_out .* I_out;
else
    P_in = V_in .* i_L;
    P_out = V_out .* I_out;
end
% CONV-003: power balance residual. Conservation law.
power_residual = P_in - (P_out + P_converter_loss + dE_converter_dt);
P_out_positive = max(P_out, 0);
P_in_positive = max(P_in, 0);
% CONV-006
if P_in_positive > 1e-9
    eta_converter = P_out_positive ./ P_in_positive;
else
    eta_converter = 1;
end

dx = [di_L_dt; dV_out_dt];
outputs = struct( ...
    "di_L_dt", di_L_dt, ...
    "dV_out_dt", dV_out_dt, ...
    "P_in_W", P_in, ...
    "P_out_W", P_out, ...
    "P_converter_loss_W", P_converter_loss, ...
    "P_conduction_W", P_conduction, ...
    "P_switching_W", P_switching, ...
    "dE_converter_dt", dE_converter_dt, ...
    "power_residual_W", power_residual, ...
    "eta_converter", eta_converter, ...
    "topology", topology, ...
    "E_stored_J", E_L + E_C);
diagnostics = struct("t", t, "topology", topology);
end
