classdef test_Metal_Electrode_1D < matlab.unittest.TestCase
    % TD003
    methods (Test)
        function utilizationBounds(testCase)
            lib_IronAir_init();
            IronAir = evalin('base', 'IronAir');
            p = IronAir.Metal;
            u = 0.5;
            [du, ~, ~] = ironair_metal_ode(u, 10, 6000, 298.15, p);
            testCase.verifyTrue(isfinite(du));
            [du0, ~, ~] = ironair_metal_ode(0, 10, 6000, 298.15, p);
            testCase.verifyEqual(du0, 0);
            [du1, ~, ~] = ironair_metal_ode(1, -10, 6000, 298.15, p);
            testCase.verifyEqual(du1, 0);
        end
    end
end
