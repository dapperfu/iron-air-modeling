function [outputs, diagnostics] = ironair_stack_model(t, inputs, p)
%IRONAIR_STACK_MODEL Series-parallel stack voltage, current, and power.
%   [OUTPUTS, DIAGNOSTICS] = IRONAIR_STACK_MODEL(T, INPUTS, P)
%
%   Equation: STK-001 through STK-006
%   Requirements: SRS011, SRS007.

arguments
    t (1, 1) double
    inputs (1, 1) struct
    p (1, 1) struct
end

V_cell = inputs.V_cell_V;
if isscalar(V_cell)
    V_cell_series = V_cell .* ones(p.stack.N_series, 1);
else
    V_cell_series = V_cell(:);
end
% STK-001
V_stack = sum(V_cell_series);
I_string = inputs.I_cell_A;
% STK-002: series cells share one terminal current when shunts are absent.
I_cell_series = I_string;
I_parallel = I_string .* ones(p.stack.N_parallel, 1);
if isfield(inputs, "I_parallel_strings_A")
    I_parallel = inputs.I_parallel_strings_A(:);
end
% STK-003
I_stack = sum(I_parallel);
% STK-004
V_stack_nominal = p.stack.N_series .* p.reference.E_cell_nominal_V;
% STK-005
P_stack = V_stack .* I_stack;

if isfield(inputs, "e_string_V") && isfield(inputs, "V_bus_V") && isfield(inputs, "R_string_Ohm")
    e_string = inputs.e_string_V(:);
    R_string = inputs.R_string_Ohm(:);
    % STK-006: linear Thevenin current sharing. Constitutive approximation.
    I_string_k = (e_string - inputs.V_bus_V) ./ R_string;
else
    R_string = p.stack.R_busbar_Ohm + p.stack.sigma_mismatch;
    e_string = V_stack .* ones(p.stack.N_parallel, 1);
    I_string_k = I_parallel;
end

outputs = struct( ...
    "V_stack_V", V_stack, ...
    "I_cell_series_A", I_cell_series, ...
    "I_stack_A", I_stack, ...
    "V_stack_nominal_V", V_stack_nominal, ...
    "P_stack_W", P_stack, ...
    "I_string_k_A", I_string_k, ...
    "e_string_V", e_string, ...
    "R_string_Ohm", R_string);
diagnostics = struct("t", t, "series_count", p.stack.N_series, ...
    "parallel_count", p.stack.N_parallel);
end
