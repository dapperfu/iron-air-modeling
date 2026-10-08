classdef test_Plant_RideThrough < matlab.unittest.TestCase
    % TD008
    methods (Test)
        function envelopes(testCase)
            lib_IronAir_init();
            IronAir = evalin('base', 'IronAir');
            p = IronAir.Standards;
            mon = ironair_der_ride_through(1.0, 60.0, p);
            testCase.verifyTrue(mon.Pass);
            mon2 = ironair_der_ride_through(0.5, 60.0, p);
            testCase.verifyFalse(mon2.Pass);
            mon3 = ironair_der_ride_through(1.0, 55.0, p);
            testCase.verifyFalse(mon3.Pass);
            sa = ironair_standards_assert(300, 0.01, 0.5, 1000, p);
            testCase.verifyTrue(sa.Pass);
            sa2 = ironair_standards_assert(400, 0.01, 0.5, 1000, p);
            testCase.verifyFalse(sa2.Pass);
        end
    end
end
