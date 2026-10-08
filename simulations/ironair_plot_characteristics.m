function summary = ironair_plot_characteristics()
%IRONAIR_PLOT_CHARACTERISTICS Plot polarization and component trajectories.
%   SUMMARY = IRONAIR_PLOT_CHARACTERISTICS() evaluates the single-cell smoke model,
%   draws the figures in the MATLAB desktop, and writes PNG files under
%   results/figures.
%
%   Discharge-positive current is used throughout. Development parameters are
%   ASSUMED or CALIBRATION_REQUIRED research values, not commercial cell data.
%
%   Requirements: SRS007, SRS024.

ironair_setup();
root = fileparts(fileparts(mfilename("fullpath")));
out_dir = fullfile(root, "results", "figures");
if ~isfolder(out_dir)
    mkdir(out_dir);
end

p = ironair_configuration_profile("single_cell", "smoke");
p.fidelity_level = 1;
polarization = cell_polarization(p);
metal = run_component("metal", @() ironair_sim_metal_electrode("smoke"));
her = run_component("HER", @() ironair_sim_HER("smoke"));
air = run_component("air", @() ironair_sim_air_electrode("smoke"));
electrolyte = run_component("electrolyte", @() ironair_sim_electrolyte("smoke"));
gdl = run_component("GDL", @() ironair_sim_gdl("smoke"));

fig_pol = plot_polarization(polarization);
fig_dyn = plot_dynamics(metal, her, air, electrolyte, gdl);
exportgraphics(fig_pol, fullfile(out_dir, "cell_polarization.png"), ...
    "Resolution", 150);
exportgraphics(fig_dyn, fullfile(out_dir, "component_trajectories.png"), ...
    "Resolution", 150);

summary = struct("polarization", polarization, "out_dir", string(out_dir));
print_polarization(polarization);
fprintf("Figures written to %s\n", out_dir);
end

function polarization = cell_polarization(p)
I_cell_A = [-20; -10; -5; -2; -1; 0; 1; 2; 5; 10; 20];
n_points = numel(I_cell_A);
V_cell_V = nan(n_points, 1);
P_cell_W = nan(n_points, 1);
I_Fe_A = nan(n_points, 1);
I_HER_A = nan(n_points, 1);
I_ORR_A = nan(n_points, 1);
I_OER_A = nan(n_points, 1);
SOC = nan(n_points, 1);
for index = 1:n_points
    try
        x0 = ironair_cell_initial_state(p, I_cell_A(index));
        inputs = struct("I_cell_A", I_cell_A(index), ...
            "T_cell_K", p.reference.T_initial_K);
        [~, outputs] = ironair_cell_model(0, x0, inputs, p);
        V_cell_V(index) = outputs.V_cell_V;
        P_cell_W(index) = outputs.P_cell_W;
        I_Fe_A(index) = outputs.I_Fe_A;
        I_HER_A(index) = outputs.I_HER_A;
        I_ORR_A(index) = outputs.I_ORR_A;
        I_OER_A(index) = outputs.I_OER_A;
        SOC(index) = outputs.SOC;
    catch exception
        warning("ironair:plot:PolarizationPoint", ...
            "Skipped I_cell = %g A: %s", I_cell_A(index), exception.message);
    end
end
polarization = struct("I_cell_A", I_cell_A, "V_cell_V", V_cell_V, ...
    "P_cell_W", P_cell_W, "I_Fe_A", I_Fe_A, "I_HER_A", I_HER_A, ...
    "I_ORR_A", I_ORR_A, "I_OER_A", I_OER_A, "SOC", SOC);
end

function fig = plot_polarization(polarization)
fig = figure("Name", "Iron-air cell polarization", "Color", "w");
tiledlayout(fig, 2, 1, "Padding", "compact", "TileSpacing", "compact");

nexttile;
plot(polarization.I_cell_A, polarization.V_cell_V, "o-", "LineWidth", 1.2);
grid on;
xlabel("Cell current (A), discharge positive");
ylabel("Terminal voltage (V)");
title("Quasi-steady polarization at the initial inventory");

nexttile;
hold on;
plot(polarization.I_cell_A, polarization.I_Fe_A, "o-", "LineWidth", 1.2);
plot(polarization.I_cell_A, polarization.I_HER_A, "s-", "LineWidth", 1.2);
plot(polarization.I_cell_A, polarization.I_ORR_A, "^-", "LineWidth", 1.2);
plot(polarization.I_cell_A, polarization.I_OER_A, "d-", "LineWidth", 1.2);
hold off;
grid on;
xlabel("Cell current (A), discharge positive");
ylabel("Partial current (A)");
legend("Iron", "HER", "ORR", "OER", "Location", "best");
title("Electrode partial currents");
end

function fig = plot_dynamics(metal, her, air, electrolyte, gdl)
fig = figure("Name", "Iron-air component trajectories", "Color", "w");
tiledlayout(fig, 2, 2, "Padding", "compact", "TileSpacing", "compact");

nexttile;
if isempty(metal)
    title("Iron electrode unavailable");
else
plot(metal.t_s, metal.x(:, 1), "LineWidth", 1.2);
hold on;
plot(metal.t_s, metal.x(:, 2), "LineWidth", 1.2);
hold off;
grid on;
xlabel("Time (s)");
ylabel("Inventory (mol)");
legend("Fe", "Fe(OH)_2", "Location", "best");
title("Iron electrode, 5 A oxidation");
end

nexttile;
if isempty(her)
    title("HER unavailable");
else
plot(her.t_s, her.x(:, 1) * 1e3, "LineWidth", 1.2);
grid on;
xlabel("Time (s)");
ylabel("Hydrogen inventory (mmol)");
title("Cathodic HER at -1.05 V");
end

nexttile;
if isempty(electrolyte)
    title("Electrolyte unavailable");
else
plot(electrolyte.t_s, electrolyte.x(:, 1), "LineWidth", 1.2);
hold on;
plot(electrolyte.t_s, electrolyte.x(:, 3), "LineWidth", 1.2);
hold off;
grid on;
xlabel("Time (s)");
ylabel("Inventory (mol)");
legend("OH^-", "H_2O", "Location", "best");
title("Electrolyte during iron oxidation");
end

nexttile;
if isempty(gdl)
    title("Gas-diffusion layer unavailable");
else
n_cv = size(gdl.x, 2) - 1;
plot(gdl.t_s, gdl.x(:, 1:n_cv), "LineWidth", 1.2);
grid on;
xlabel("Time (s)");
ylabel("Oxygen concentration (mol/m^3)");
title("Gas-diffusion layer");
end
end

function results = run_component(name, runner)
try
    results = runner();
catch exception
    warning("ironair:plot:ComponentFailed", ...
        "%s simulation failed: %s", name, exception.message);
    results = [];
end
end

function print_polarization(polarization)
fprintf("I_cell_A,V_cell_V,P_cell_W,I_Fe_A,I_HER_A,I_ORR_A,I_OER_A\n");
for index = 1:numel(polarization.I_cell_A)
    fprintf("%.8g,%.8g,%.8g,%.8g,%.8g,%.8g,%.8g\n", ...
        polarization.I_cell_A(index), polarization.V_cell_V(index), ...
        polarization.P_cell_W(index), polarization.I_Fe_A(index), ...
        polarization.I_HER_A(index), polarization.I_ORR_A(index), ...
        polarization.I_OER_A(index));
end
end
