function generate_mock_cell_curves(outDir)
%GENERATE_MOCK_CELL_CURVES Synthetic mock curves from the cell ODE model.
% Requirement IDs: SRS016, SSS016
if nargin < 1
    outDir = fullfile(fileparts(mfilename('fullpath')), 'data', 'mock');
end
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

root = fileparts(mfilename('fullpath'));
addpath(genpath(fullfile(root, 'src')));

% Use default parameters without recursing into SLDD mock load
IronAir = lib_IronAir_init_params_only();
pb = IronAir.CellBundle;
Nx = pb.Electrolyte.Nx;
y0 = [pb.Electrolyte.c_init(:); pb.ORR.c_init(:); pb.Metal.u_init; pb.Thermal.T_init; 0];

I = 1.0; % A discharge
t = linspace(0, 3600, 121)'; % 1 h for mock regression speed
opts = odeset('RelTol', 1e-4, 'AbsTol', 1e-6);
rhs = @(tt, yy) local_yp(tt, yy, I, pb);
[t, Y] = ode15s(rhs, t, y0, opts);
V = zeros(size(t));
SOC = zeros(size(t));
CE = zeros(size(t));
for k = 1:numel(t)
    out = ironair_cell_outputs(Y(k, :).', I, pb);
    V(k) = out.Voltage_V;
    SOC(k) = out.SOC;
    CE(k) = out.FaradaicEfficiency;
end

mock.t_s = t;
mock.I_A = I * ones(size(t));
mock.V_V = V;
mock.SOC = SOC;
mock.CE = CE;
mock.description = 'Synthetic Fe-air discharge mock from ironair_cell_step';
save(fullfile(outDir, 'mock_discharge_VI.mat'), '-struct', 'mock');

% Charge
Ic = -1.0;
y0c = y0; y0c(2*Nx+1) = 0.2;
[t, Yc] = ode15s(@(tt, yy) local_yp(tt, yy, Ic, pb), t, y0c, opts);
Vc = zeros(size(t)); SOCc = zeros(size(t)); CEc = zeros(size(t));
for k = 1:numel(t)
    out = ironair_cell_outputs(Yc(k, :).', Ic, pb);
    Vc(k) = out.Voltage_V;
    SOCc(k) = out.SOC;
    CEc(k) = out.FaradaicEfficiency;
end
mockc.t_s = t;
mockc.I_A = Ic * ones(size(t));
mockc.V_V = Vc;
mockc.SOC = SOCc;
mockc.CE = CEc;
mockc.description = 'Synthetic Fe-air charge mock from ironair_cell_step';
save(fullfile(outDir, 'mock_charge_VI.mat'), '-struct', 'mockc');

fprintf('Wrote mock curves to %s\n', outDir);
end

function yp = local_yp(t, y, I, pb)
[yp, ~] = ironair_cell_step(t, y, I, pb);
yp = yp(:);
end

function IronAir = lib_IronAir_init_params_only()
% Parameter subset without SLDD / mock recursion
C = ironair_constants();
Nx = 5;
A = 0.01;
IronAir.Electrolyte.Nx = Nx;
IronAir.Electrolyte.L = 0.002;
IronAir.Electrolyte.D_OH = 2e-9;
IronAir.Electrolyte.E_act_D = 15000;
IronAir.Electrolyte.R = C.R;
IronAir.Electrolyte.T = C.T_ref;
IronAir.Electrolyte.T_ref = C.T_ref;
IronAir.Electrolyte.t_plus = 0.7;
IronAir.Electrolyte.F = C.F;
IronAir.Electrolyte.a_v = 1000;
IronAir.Electrolyte.eps_elyte = 0.4;
IronAir.Electrolyte.kappa0 = 40;
IronAir.Electrolyte.c0 = 6000;
IronAir.Electrolyte.c_init = 6000 * ones(Nx, 1);
IronAir.Metal.E0_Fe = -0.88;
IronAir.Metal.E0_cell = 1.28;
IronAir.Metal.c_OH_ref = 6000;
IronAir.Metal.i0_Fe = 50;
IronAir.Metal.E_act_Fe = 30000;
IronAir.Metal.T_ref = C.T_ref;
IronAir.Metal.alpha_a = 0.5;
IronAir.Metal.alpha_c = 0.5;
IronAir.Metal.Q_max = 3.6e6 * 20 / A;
IronAir.Metal.u_init = 1.0;
IronAir.Metal.gamma_OH = 0.25;
IronAir.Metal.soc_activity_mode = 1;
IronAir.Metal.soc_activity_min = 1e-4;
IronAir.Metal.soc_activity_exp = 0.5;
IronAir.Metal.bv_max_iter = 40;
IronAir.Metal.bv_tol = 1e-10;
IronAir.Metal.exp_arg_max = 80;
IronAir.ORR.Nx = Nx;
IronAir.ORR.L = 0.001;
IronAir.ORR.D_O2 = 1e-9;
IronAir.ORR.i0_ORR = 80;
IronAir.ORR.E_act_ORR = 40000;
IronAir.ORR.T_ref = C.T_ref;
IronAir.ORR.alpha_c = 0.5;
IronAir.ORR.c_O2_ref = 1.0;
IronAir.ORR.c_O2_amb = 1.2;
IronAir.ORR.k_gas = 0.1;
IronAir.ORR.a_v = 2000;
IronAir.ORR.c_init = 1.0 * ones(Nx, 1);
IronAir.OER.i0_OER = 40;
IronAir.OER.E_act_OER = 50000;
IronAir.OER.T_ref = C.T_ref;
IronAir.OER.alpha_a = 0.5;
IronAir.H2.i0_H2 = 0.05;
IronAir.H2.E_act_H2 = 35000;
IronAir.H2.T_ref = C.T_ref;
IronAir.H2.alpha_H2 = 0.5;
IronAir.H2.A = A;
IronAir.Thermal.Nx = 1;
IronAir.Thermal.L = 0.01;
IronAir.Thermal.k_th = 5;
IronAir.Thermal.rho = 2000;
IronAir.Thermal.cp = 800;
IronAir.Thermal.Vol = A * 0.01;
IronAir.Thermal.h_conv = 10;
IronAir.Thermal.A_surf = 0.02;
IronAir.Thermal.T_amb = C.T_ref;
IronAir.Thermal.m_th = IronAir.Thermal.rho * IronAir.Thermal.Vol;
IronAir.Thermal.T_init = C.T_ref;
IronAir.CellBundle.A = A;
IronAir.CellBundle.Electrolyte = IronAir.Electrolyte;
IronAir.CellBundle.Metal = IronAir.Metal;
IronAir.CellBundle.ORR = IronAir.ORR;
IronAir.CellBundle.OER = IronAir.OER;
IronAir.CellBundle.H2 = IronAir.H2;
IronAir.CellBundle.Thermal = IronAir.Thermal;
end
