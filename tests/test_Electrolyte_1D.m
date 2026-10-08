classdef test_Electrolyte_1D < matlab.unittest.TestCase
    % TD001
    methods (Test)
        function massConservedZeroFlux(testCase)
            lib_IronAir_init();
            IronAir = evalin('base', 'IronAir');
            p = IronAir.Electrolyte;
            p.a_v = 0; % no Faradaic source
            c0 = p.c_init;
            moles0 = sum(c0);
            dc = ironair_electrolyte_ode(c0, 0, p);
            testCase.verifyEqual(sum(dc), 0, 'AbsTol', 1e-12);
            % Integrate briefly
            rhs = @(t,c) ironair_electrolyte_ode(c, 0, p);
            [~, c] = ode15s(rhs, [0 100], c0);
            moles1 = sum(c(end,:));
            testCase.verifyEqual(moles1, moles0, 'RelTol', 1e-6);
        end
    end
end
