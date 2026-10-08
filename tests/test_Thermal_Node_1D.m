classdef test_Thermal_Node_1D < matlab.unittest.TestCase
    % TD005
    methods (Test)
        function heatsUp(testCase)
            lib_IronAir_init();
            IronAir = evalin('base', 'IronAir');
            p = IronAir.Thermal;
            T = p.T_init;
            dT = ironair_thermal_ode(T, 100, p);
            testCase.verifyGreaterThan(dT, 0);
            testCase.verifyTrue(isfinite(dT));
        end
    end
end
