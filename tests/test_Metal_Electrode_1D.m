classdef test_Metal_Electrode_1D < matlab.unittest.TestCase
    % TD003 - Metal electrode utilization / kinetics (SSS004, SDD002)
    methods (TestClassSetup)
        function addProjectPaths(~)
            root = fileparts(fileparts(mfilename('fullpath')));
            addpath(genpath(fullfile(root, 'src')));
            addpath(fullfile(root, 'tests'));
            clear('ironair_metal_ode');
        end
    end
    methods (Test)
        function utilizationBounds(testCase)
            p = local_metal_params();
            u = 0.5;
            [du, ~, ~] = ironair_metal_ode(u, 10, 6000, 298.15, p);
            testCase.verifyTrue(isfinite(du));
            [du0, eta0, i0] = ironair_metal_ode(0, 10, 6000, 298.15, p);
            testCase.verifyEqual(du0, 0);
            testCase.verifyEqual(i0, 0);
            testCase.verifyTrue(isnan(eta0));
            [du1, eta1, i1] = ironair_metal_ode(1, -10, 6000, 298.15, p);
            testCase.verifyEqual(du1, 0);
            testCase.verifyEqual(i1, 0);
            testCase.verifyTrue(isnan(eta1));
        end

        function openCircuit(testCase)
            p = local_metal_params();
            [du, eta, i_far] = ironair_metal_ode(0.5, 0, 6000, 298.15, p);
            testCase.verifyEqual(du, 0);
            testCase.verifyEqual(i_far, 0);
            testCase.verifyEqual(eta, 0);
        end

        function dischargeInterior(testCase)
            p = local_metal_params();
            [du, eta, i_far] = ironair_metal_ode(0.5, 10, 6000, 298.15, p);
            testCase.verifyLessThan(du, 0);
            testCase.verifyGreaterThan(i_far, 0);
            testCase.verifyGreaterThan(eta, 0);
        end

        function chargeInterior(testCase)
            p = local_metal_params();
            [du, eta, i_far] = ironair_metal_ode(0.5, -10, 6000, 298.15, p);
            testCase.verifyGreaterThan(du, 0);
            testCase.verifyLessThan(i_far, 0);
            testCase.verifyLessThan(eta, 0);
        end

        function chargeConservation(testCase)
            p = local_metal_params();
            cases = [0.5, 10; 0.5, -10; 0.5, 0; 0, -5; 1, 5; 0, 10; 1, -10];
            for k = 1:size(cases, 1)
                [du, ~, i_far] = ironair_metal_ode( ...
                    cases(k, 1), cases(k, 2), 6000, 298.15, p);
                testCase.verifyEqual(p.Q_max * du + i_far, 0, 'AbsTol', 1e-12);
            end
        end

        function symmetricButlerVolmer(testCase)
            p = local_metal_params();
            p.alpha_a = 0.5;
            p.alpha_c = 0.5;
            C = ironair_constants();
            u = 0.5;
            i_app = 25;
            T = 298.15;
            c_OH = 6000;
            [~, eta, i_far] = ironair_metal_ode(u, i_app, c_OH, T, p);
            i0 = p.i0_Fe * exp(-p.E_act_Fe / C.R * (1 / T - 1 / p.T_ref));
            soc = sqrt(max(u * (1 - u), p.soc_activity_min));
            oh = (c_OH / p.c_OH_ref)^p.gamma_OH;
            i0_eff = i0 * soc * oh;
            eta_ref = (C.R * T) / (p.alpha_a * C.F) * asinh(i_far / (2 * i0_eff));
            testCase.verifyEqual(eta, eta_ref, 'AbsTol', 1e-12);
        end

        function asymmetricButlerVolmer(testCase)
            p = local_metal_params();
            p.alpha_a = 0.4;
            p.alpha_c = 0.6;
            C = ironair_constants();
            u = 0.5;
            i_app = 20;
            T = 310;
            c_OH = 6000;
            [~, eta, i_far] = ironair_metal_ode(u, i_app, c_OH, T, p);
            testCase.verifyTrue(isfinite(eta));
            i0 = p.i0_Fe * exp(-p.E_act_Fe / C.R * (1 / T - 1 / p.T_ref));
            soc = sqrt(max(u * (1 - u), p.soc_activity_min));
            oh = (c_OH / p.c_OH_ref)^p.gamma_OH;
            i0_eff = i0 * soc * oh;
            i_fwd = i0_eff * ( ...
                exp(p.alpha_a * C.F * eta / (C.R * T)) - ...
                exp(-p.alpha_c * C.F * eta / (C.R * T)));
            testCase.verifyEqual(i_fwd, i_far, 'RelTol', 1e-8, 'AbsTol', 1e-8);
            [~, eta_n, i_n] = ironair_metal_ode(u, -i_app, c_OH, T, p);
            testCase.verifyLessThan(eta_n, 0);
            i_fwd_n = i0_eff * ( ...
                exp(p.alpha_a * C.F * eta_n / (C.R * T)) - ...
                exp(-p.alpha_c * C.F * eta_n / (C.R * T)));
            testCase.verifyEqual(i_fwd_n, i_n, 'RelTol', 1e-8, 'AbsTol', 1e-8);
        end

        function temperatureSensitivity(testCase)
            p = local_metal_params();
            p.E_act_Fe = 30000;
            T_ref = p.T_ref;
            T_hi = T_ref + 20;
            i_app = 15;
            [~, eta_lo, ~] = ironair_metal_ode(0.5, i_app, 6000, T_ref, p);
            [~, eta_hi, ~] = ironair_metal_ode(0.5, i_app, 6000, T_hi, p);
            testCase.verifyGreaterThan(abs(eta_lo), abs(eta_hi));
            C = ironair_constants();
            i0_lo = p.i0_Fe * exp(-p.E_act_Fe / C.R * (1 / T_ref - 1 / p.T_ref));
            i0_hi = p.i0_Fe * exp(-p.E_act_Fe / C.R * (1 / T_hi - 1 / p.T_ref));
            testCase.verifyGreaterThan(i0_hi, i0_lo);
        end

        function concentrationSensitivity(testCase)
            p = local_metal_params();
            p.gamma_OH = 0.25;
            [~, eta_hi, ~] = ironair_metal_ode(0.5, 10, 6000, 298.15, p);
            [~, eta_lo, ~] = ironair_metal_ode(0.5, 10, 1500, 298.15, p);
            testCase.verifyGreaterThan(abs(eta_lo), abs(eta_hi));
            [du_z, eta_z, i_z] = ironair_metal_ode(0.5, 10, 0, 298.15, p);
            testCase.verifyEqual(du_z, 0);
            testCase.verifyEqual(i_z, 0);
            testCase.verifyTrue(isnan(eta_z));
            [du0, eta0, i0] = ironair_metal_ode(0.5, 0, 0, 298.15, p);
            testCase.verifyEqual(du0, 0);
            testCase.verifyEqual(i0, 0);
            testCase.verifyEqual(eta0, 0);
        end

        function currentReversalContinuous(testCase)
            p = local_metal_params();
            i_vals = [-20, -1e-9, 0, 1e-9, 20];
            eta_vals = zeros(size(i_vals));
            for k = 1:numel(i_vals)
                [~, eta_vals(k), ~] = ironair_metal_ode(0.5, i_vals(k), 6000, 298.15, p);
            end
            testCase.verifyEqual(eta_vals(3), 0);
            testCase.verifyLessThan(eta_vals(1), 0);
            testCase.verifyGreaterThan(eta_vals(5), 0);
            testCase.verifyLessThan(eta_vals(2), 0);
            testCase.verifyGreaterThan(eta_vals(4), 0);
        end

        function numericalRobustness(testCase)
            p = local_metal_params();
            [du, eta, i_far] = ironair_metal_ode(0.5, 1e-15, 6000, 298.15, p);
            testCase.verifyTrue(isfinite(du) && isfinite(eta) && isfinite(i_far));
            [~, eta_big, ~] = ironair_metal_ode(0.5, 1e5, 6000, 298.15, p);
            testCase.verifyTrue(isfinite(eta_big));
            [~, eta_u0, ~] = ironair_metal_ode(1e-8, 5, 6000, 298.15, p);
            testCase.verifyTrue(isfinite(eta_u0));
            [~, eta_u1, ~] = ironair_metal_ode(1 - 1e-8, -5, 6000, 298.15, p);
            testCase.verifyTrue(isfinite(eta_u1));
            [~, eta_T, ~] = ironair_metal_ode(0.5, 10, 6000, 273.15, p);
            testCase.verifyTrue(isfinite(eta_T));
            [~, eta_Th, ~] = ironair_metal_ode(0.5, 10, 6000, 333.15, p);
            testCase.verifyTrue(isfinite(eta_Th));
            p_as = p;
            p_as.alpha_a = 0.3;
            p_as.alpha_c = 0.7;
            [~, eta_as, ~] = ironair_metal_ode(0.5, -50, 6000, 298.15, p_as);
            testCase.verifyTrue(isfinite(eta_as));
        end

        function invalidInputs(testCase)
            p = local_metal_params();
            [du, eta, i_far] = ironair_metal_ode(0.5, 10, 6000, -1, p);
            testCase.verifyTrue(isnan(du) && isnan(eta) && isnan(i_far));
            [du2, eta2, i2] = ironair_metal_ode(NaN, 10, 6000, 298.15, p);
            testCase.verifyTrue(isnan(du2) && isnan(eta2) && isnan(i2));
            p_bad = p;
            p_bad.Q_max = -1;
            [du3, eta3, i3] = ironair_metal_ode(0.5, 10, 6000, 298.15, p_bad);
            testCase.verifyTrue(isnan(du3) && isnan(eta3) && isnan(i3));
            p_bad2 = p;
            p_bad2.i0_Fe = 0;
            [du4, eta4, i4] = ironair_metal_ode(0.5, 10, 6000, 298.15, p_bad2);
            testCase.verifyTrue(isnan(du4) && isnan(eta4) && isnan(i4));
            [du5, eta5, i5] = ironair_metal_ode(0.5, 10, -1, 298.15, p);
            testCase.verifyTrue(isnan(du5) && isnan(eta5) && isnan(i5));
        end

        function boundaryChargeStillAllowed(testCase)
            p = local_metal_params();
            [du, eta, i_far] = ironair_metal_ode(0, -10, 6000, 298.15, p);
            testCase.verifyGreaterThan(du, 0);
            testCase.verifyLessThan(i_far, 0);
            testCase.verifyTrue(isfinite(eta) && eta < 0);
            [du2, eta2, i2] = ironair_metal_ode(1, 10, 6000, 298.15, p);
            testCase.verifyLessThan(du2, 0);
            testCase.verifyGreaterThan(i2, 0);
            testCase.verifyTrue(isfinite(eta2) && eta2 > 0);
        end

        function configurableGammaOH(testCase)
            p = local_metal_params();
            p.gamma_OH = 0;
            [~, eta0, ~] = ironair_metal_ode(0.5, 10, 100, 298.15, p);
            [~, eta1, ~] = ironair_metal_ode(0.5, 10, 6000, 298.15, p);
            testCase.verifyEqual(eta0, eta1, 'AbsTol', 1e-12);
        end
    end
end

function p = local_metal_params()
    C = ironair_constants();
    p = struct();
    p.i0_Fe = 50;
    p.E_act_Fe = 30000;
    p.T_ref = C.T_ref;
    p.alpha_a = 0.5;
    p.alpha_c = 0.5;
    p.Q_max = 3.6e6 * 20 / 0.01;
    p.c_OH_ref = 6000;
    p.gamma_OH = 0.25;
    p.soc_activity_mode = 1;
    p.soc_activity_min = 1e-4;
    p.soc_activity_exp = 0.5;
    p.bv_max_iter = 40;
    p.bv_tol = 1e-10;
    p.exp_arg_max = 80;
end
