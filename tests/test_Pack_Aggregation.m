classdef test_Pack_Aggregation < matlab.unittest.TestCase
    % TD007
    methods (Test)
        function seriesParallelScaling(testCase)
            cellOut.Voltage_V = 1.2;
            cellOut.Current_A = 2;
            cellOut.SOC = 0.5;
            cellOut.Temperature_K = 300;
            cellOut.H2_Rate_mol_s = 1e-6;
            cellOut.H2_Volume_m3 = 1e-4;
            cellOut.FaradaicEfficiency = 0.9;
            pack = ironair_aggregate(cellOut, 5, 3);
            testCase.verifyEqual(pack.Voltage_V, 6.0, 'AbsTol', 1e-12);
            testCase.verifyEqual(pack.Current_A, 6.0, 'AbsTol', 1e-12);
        end
    end
end
