classdef test_H2_Evolution < matlab.unittest.TestCase
    % TD002
    methods (Test)
        function positivityAndEfficiency(testCase)
            lib_IronAir_init();
            IronAir = evalin('base', 'IronAir');
            [n_dot, ~, eta_F, i_H2] = ironair_h2_evolution(-0.2, 1.0, 298.15, IronAir.H2);
            testCase.verifyGreaterThanOrEqual(n_dot, 0);
            testCase.verifyGreaterThanOrEqual(i_H2, 0);
            testCase.verifyGreaterThanOrEqual(eta_F, 0);
            testCase.verifyLessThanOrEqual(eta_F, 1);
        end
    end
end
