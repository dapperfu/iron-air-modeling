function net = ironair_reaction_network()
%IRONAIR_REACTION_NETWORK Return the canonical species and reaction matrices.
%   NET = IRONAIR_REACTION_NETWORK() defines one stoichiometric mechanism used
%   by every fidelity. Reaction extents are moles of reaction as written per
%   second. Electrons are tracked for charge closure.
%
%   Output fields:
%     species        - Species names.
%     reactions      - Reaction names.
%     elements       - Conserved-element names including charge.
%     S              - Stoichiometry, species-by-reaction, mol/mol.
%     A_elements     - Element-by-species composition.
%     B_boundary     - Identity map from boundary molar flows.
%     nu_electrons   - Electrons produced per reaction extent.
%     nu_H2O         - Water produced per reaction extent.
%
%   Units: S and A_elements are dimensionless mole ratios.
%   Assumptions: Fe/FeOH2 two-electron conversion; optional magnetite;
%   ORR and OER are independent extents; HER is irreversible as written.
%   Equations: FE-001, FE-014, AIR-001, AIR-002, HER-001, ELY-009, SYS-001,
%   SYS-002
%   Requirements: SRS003, SRS004, SRS005.2, SRS019, SRS023.

net = struct();
net.species = [ ...
    "Fe", "FeOH2", "Fe3O4", "OH", "H2O", "O2", "H2", "CO2", "CO3", "e", "K"];
net.reactions = [ ...
    "Fe_ox", "magnetite", "ORR", "OER", "HER", "carbonation"];
net.elements = ["Fe", "H", "O", "C", "K", "charge"];

n_species = numel(net.species);
n_reactions = numel(net.reactions);
S = zeros(n_species, n_reactions);

% FE-001: Fe + 2OH- <-> FeOH2 + 2e-
S(:, 1) = species_column(net.species, ...
    "Fe", -1, "OH", -2, "FeOH2", 1, "e", 2);

% FE-014: 3FeOH2 + 2OH- <-> Fe3O4 + 4H2O + 2e-
S(:, 2) = species_column(net.species, ...
    "FeOH2", -3, "OH", -2, "Fe3O4", 1, "H2O", 4, "e", 2);

% AIR-001: O2 + 2H2O + 4e- -> 4OH-
S(:, 3) = species_column(net.species, ...
    "O2", -1, "H2O", -2, "e", -4, "OH", 4);

% AIR-002: 4OH- -> O2 + 2H2O + 4e-
S(:, 4) = species_column(net.species, ...
    "OH", -4, "O2", 1, "H2O", 2, "e", 4);

% HER-001: 2H2O + 2e- -> H2 + 2OH-
S(:, 5) = species_column(net.species, ...
    "H2O", -2, "e", -2, "H2", 1, "OH", 2);

% ELY-009: CO2 + 2OH- -> CO3^2- + H2O
S(:, 6) = species_column(net.species, ...
    "CO2", -1, "OH", -2, "CO3", 1, "H2O", 1);

A = zeros(numel(net.elements), n_species);
A(1, :) = composition(net.species, "Fe", 1, "FeOH2", 1, "Fe3O4", 3);
A(2, :) = composition(net.species, "FeOH2", 2, "OH", 1, "H2O", 2, "H2", 2);
A(3, :) = composition(net.species, "FeOH2", 2, "Fe3O4", 4, "OH", 1, ...
    "H2O", 1, "O2", 2, "CO2", 2, "CO3", 3);
A(4, :) = composition(net.species, "CO2", 1, "CO3", 1);
A(5, :) = composition(net.species, "K", 1);
A(6, :) = composition(net.species, "OH", -1, "CO3", -2, "e", -1, "K", 1);

net.S = S;
net.A_elements = A;
net.B_boundary = eye(n_species);
net.nu_electrons = S(species_index(net.species, "e"), :).';
net.nu_H2O = S(species_index(net.species, "H2O"), :).';
net.idx = struct();
for index = 1:n_species
    net.idx.(net.species(index)) = index;
end
for index = 1:n_reactions
    net.idx.(net.reactions(index)) = index;
end
end

function column = species_column(species, varargin)
column = zeros(numel(species), 1);
for pair_index = 1:2:numel(varargin)
    column(species_index(species, varargin{pair_index})) = varargin{pair_index + 1};
end
end

function row = composition(species, varargin)
row = zeros(1, numel(species));
for pair_index = 1:2:numel(varargin)
    row(species_index(species, varargin{pair_index})) = varargin{pair_index + 1};
end
end

function index = species_index(species, name)
index = find(species == string(name), 1);
if isempty(index)
    error("ironair:reaction:UnknownSpecies", "Unknown species %s.", name);
end
end
