function [outputs, diagnostics] = ironair_module_model(t, inputs, p)
%IRONAIR_MODULE_MODEL Module power, auxiliary loads, and stored-energy sum.
%   [OUTPUTS, DIAGNOSTICS] = IRONAIR_MODULE_MODEL(T, INPUTS, P)
%
%   Chemical storage uses the reversible iron inventory and the equilibrium
%   cell potential. It is not nominal voltage times nominal capacity.
%
%   Equation: MOD-001, MOD-002, MOD-004, MOD-005
%   Requirements: SRS011.

arguments
    t (1, 1) double
    inputs (1, 1) struct
    p (1, 1) struct
end

P_stack_array = inputs.P_stack_W .* ones(p.module.N_stacks, 1);
if isfield(inputs, "P_stack_array_W")
    P_stack_array = inputs.P_stack_array_W(:);
end
% MOD-001
P_module = sum(P_stack_array);
P_fan = inputs.P_fan_W;
P_pump = inputs.P_pump_W;
P_HVAC = inputs.P_HVAC_W;
P_controls = p.module.P_controls_W;
P_other = p.enclosure.P_other_W;
% MOD-004
P_aux = P_fan + P_pump + P_HVAC + P_controls + P_other;
% MOD-002
P_module_net = P_module - P_aux;

E_chemical = inputs.n_Fe_mol .* 2 .* p.constants.F_C_mol .* inputs.e_cell_eq_V;
E_thermal = p.thermal_properties.m_thermal_kg .* p.thermal_properties.cp_thermal_J_kgK .* ...
    (inputs.T_cell_K - p.constants.T_ref_K);
E_dc = inputs.E_dc_J;
E_kinetic = 0.5 .* p.pumps.J_pump_kg_m2 .* inputs.omega_pump_rad_s.^2;
% MOD-005
E_stored_total = sum([E_chemical, E_thermal, E_dc, E_kinetic]);

outputs = struct( ...
    "P_module_W", P_module, ...
    "P_module_net_W", P_module_net, ...
    "P_aux_W", P_aux, ...
    "P_fan_W", P_fan, ...
    "P_pump_W", P_pump, ...
    "P_HVAC_W", P_HVAC, ...
    "P_controls_W", P_controls, ...
    "P_other_W", P_other, ...
    "E_stored_total_J", E_stored_total, ...
    "E_chemical_J", E_chemical, ...
    "E_thermal_J", E_thermal, ...
    "E_dc_J", E_dc, ...
    "E_kinetic_J", E_kinetic);
diagnostics = struct("t", t);
end
