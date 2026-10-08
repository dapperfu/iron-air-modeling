function IronAir = lib_IronAir_init(slddPath)
%LIB_IRONAIR_INIT Build IronAir parameter structs and update SLDD.
% Requirement IDs: SRS008, SSS014, IRS005
if nargin < 1
    slddPath = fullfile(fileparts(mfilename('fullpath')), 'lib_IronAir.sldd');
end

root = fileparts(mfilename('fullpath'));
addpath(genpath(fullfile(root, 'src')));
addpath(fullfile(root, 'tools'));

C = ironair_constants();
Nx = 5;
A = 0.01; % m^2 electrode area

IronAir = struct();
IronAir.Cell.A = A;
IronAir.Cell.Nx = Nx;

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
IronAir.Metal.Q_max = 3.6e6 * 20 / A; % ~20 Ah/m^2 scaled
IronAir.Metal.u_init = 1.0;

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

IronAir.Stack.nSeries = 10;
IronAir.Stack.nParallel = 1;
IronAir.Module.nSeries = 2;
IronAir.Module.nParallel = 2;
IronAir.Pack.nSeries = 5;
IronAir.Pack.nParallel = 4;

IronAir.Plant.eta_pcs = 0.96;
IronAir.Plant.t_end_h = 48;
IronAir.Plant.P_nom_W = 5000;

% Standards envelopes (IEEE 1547-2018 / UL 1741 / UL 9540 / NFPA 855 / 1547.9)
IronAir.Standards.V_min_pu = 0.88;
IronAir.Standards.V_max_pu = 1.10;
IronAir.Standards.f_min_Hz = 58.5;
IronAir.Standards.f_max_Hz = 61.5;
IronAir.Standards.T_min_K = 273.15;
IronAir.Standards.T_max_K = 333.15;
IronAir.Standards.H2_max_m3 = 0.05;
IronAir.Standards.SOC_min = 0.05;
IronAir.Standards.SOC_max = 0.95;
IronAir.Standards.P_max_W = 1.1 * IronAir.Plant.P_nom_W;

% Nested cell param bundle for ironair_cell_step
IronAir.CellBundle.A = A;
IronAir.CellBundle.Electrolyte = IronAir.Electrolyte;
IronAir.CellBundle.Metal = IronAir.Metal;
IronAir.CellBundle.ORR = IronAir.ORR;
IronAir.CellBundle.OER = IronAir.OER;
IronAir.CellBundle.H2 = IronAir.H2;
IronAir.CellBundle.Thermal = IronAir.Thermal;

% Mock data
mockFile = fullfile(root, 'data', 'mock', 'mock_discharge_VI.mat');
if ~isfile(mockFile)
    generate_mock_cell_curves(fullfile(root, 'data', 'mock'));
end
IronAir.MockData = load(mockFile);

assignin('base', 'IronAir', IronAir);
write_sldd(slddPath, IronAir);
fprintf('lib_IronAir_init: wrote %s\n', slddPath);
end

function write_sldd(slddPath, IronAir)
if isfile(slddPath)
    try
        Simulink.data.dictionary.closeAll('-discard');
    catch
    end
    delete(slddPath);
end
dictObj = Simulink.data.dictionary.create(slddPath);
dDataSectObj = getSection(dictObj, 'Design Data');
addEntry(dDataSectObj, 'IronAir', IronAir);
saveChanges(dictObj);
close(dictObj);
end
