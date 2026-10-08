classdef test_Cell_IronAir_mock < matlab.unittest.TestCase
    % TD006 TP003
    methods (Test)
        function mockVoltageRmse(testCase)
            lib_IronAir_init();
            IronAir = evalin('base', 'IronAir');
            mock = IronAir.MockData;
            pb = IronAir.CellBundle;
            Nx = pb.Electrolyte.Nx;
            y0 = [pb.Electrolyte.c_init(:); pb.ORR.c_init(:); pb.Metal.u_init; pb.Thermal.T_init; 0];
            I = mock.I_A(1);
            t = mock.t_s;
            rhs = @(tt,y) ironair_cell_step_yp(tt, y, I, pb);
            opts = odeset('RelTol', 1e-4, 'AbsTol', 1e-6);
            [t, Y] = ode15s(rhs, t, y0, opts);
            Vsim = zeros(size(t));
            for k = 1:numel(t)
                out = ironair_cell_outputs(Y(k,:).', I, pb);
                Vsim(k) = out.Voltage_V;
            end
            Vmock = interp1(mock.t_s, mock.V_V, t, 'linear', 'extrap');
            rmse = sqrt(mean((Vsim - Vmock).^2));
            % TP003: within 50 mV after mock generated from same model
            testCase.verifyLessThan(rmse, 0.05);
            testCase.verifyEqual(size(Y,2), 2*Nx+3);
        end
    end
end

function yp = ironair_cell_step_yp(t, y, I, pb)
[yp, ~] = ironair_cell_step(t, y, I, pb);
yp = yp(:);
end
