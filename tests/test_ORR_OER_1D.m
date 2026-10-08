classdef test_ORR_OER_1D < matlab.unittest.TestCase
    % TD004
    methods (Test)
        function polarity(testCase)
            lib_IronAir_init();
            IronAir = evalin('base', 'IronAir');
            c = IronAir.ORR.c_init;
            [~, eta_orr, i_orr] = ironair_orr_ode(c, 50, 298.15, IronAir.ORR);
            testCase.verifyLessThan(i_orr, 0); % ORR cathodic convention in kinetics
            testCase.verifyTrue(isfinite(eta_orr));
            [eta_oer, i_oer] = ironair_oer_ode(-100, 298.15, IronAir.OER);
            testCase.verifyGreaterThan(i_oer, 0);
            testCase.verifyGreaterThanOrEqual(eta_oer, 0);
            [eta0, i0] = ironair_oer_ode(100, 298.15, IronAir.OER);
            testCase.verifyEqual(eta0, 0);
            testCase.verifyEqual(i0, 0);
        end
    end
end
