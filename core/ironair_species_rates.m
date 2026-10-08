function [dn_dt, diagnostics] = ironair_species_rates(r_reactions, q_boundary, net)
%IRONAIR_SPECIES_RATES Assemble conservation-form species derivatives.
%   [DN_DT, DIAGNOSTICS] = IRONAIR_SPECIES_RATES(R_REACTIONS, Q_BOUNDARY, NET)
%   evaluates dn/dt = S * r + B * q for the canonical reaction network.
%
%   Inputs:
%     r_reactions - Reaction extents, mol/s, aligned with net.reactions.
%     q_boundary  - Boundary molar flows, mol/s, aligned with net.species.
%     net         - Structure from ironair_reaction_network.
%
%   Outputs:
%     dn_dt       - Species inventory derivatives, mol/s.
%     diagnostics - Elemental residual of S and instantaneous balances.
%
%   Equation: SYS-001, SYS-002, ELY-011
%   Requirements: SRS019, SRS023.

arguments
    r_reactions (:, 1) double
    q_boundary (:, 1) double
    net (1, 1) struct
end

if numel(r_reactions) ~= numel(net.reactions)
    error("ironair:reaction:RateSize", ...
        "Reaction rate vector must match the network reaction count.");
end
if numel(q_boundary) ~= numel(net.species)
    error("ironair:reaction:BoundarySize", ...
        "Boundary flow vector must match the network species count.");
end
if any(~isfinite(r_reactions)) || any(~isfinite(q_boundary))
    error("ironair:reaction:NonfiniteRate", ...
        "Reaction and boundary rates must be finite.");
end

% SYS-001
dn_dt = net.S * r_reactions + net.B_boundary * q_boundary;

% SYS-002
e_element_balance = net.A_elements * net.S;
tolerance_element_balance = 1e-12;
residual_inf = max(abs(e_element_balance), [], "all");
if residual_inf > tolerance_element_balance
    error("ironair:reaction:ElementImbalance", ...
        "The stoichiometric network does not conserve modeled elements.");
end

dn_H2O_dt = dn_dt(net.idx.H2O); % ELY-011
diagnostics = struct( ...
    "e_element_balance", e_element_balance, ...
    "residual_inf", residual_inf, ...
    "dn_H2O_dt", dn_H2O_dt, ...
    "electron_rate_mol_s", dn_dt(net.idx.e));
end
