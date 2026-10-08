function ironair_step_check()
ironair_setup();
p = ironair_configuration_profile("single_cell", "smoke");
p.fidelity_level = 1;
scenario = ironair_scenario_inputs(0, "discharge", p);
[x0, map] = ironair_system_initial_state(p, scenario.I_cell_command_A);
fprintf("states %d map %d\n", numel(x0), map.count);
try
    [dx, outputs, diagnostics] = ironair_system_ode(0, x0, p, "discharge");
    fprintf("V %g I %g max|dx| %g element %d current %d\n", ...
        outputs.V_cell_V, outputs.I_cell_A, max(abs(dx)), ...
        diagnostics.element_ok, diagnostics.current_ok);
    [~, order] = sort(abs(dx), "descend");
    labels = state_labels(map);
    for index = 1:8
        fprintf("  %s = %g\n", labels(order(index)), dx(order(index)));
    end
    fprintf("conv di %g dV %g duty path Pdc %g\n", ...
        outputs.converter.di_L_dt, outputs.converter.dV_out_dt, outputs.inverter.P_DC_W);
    fprintf("air dnO2 %g dN %g fanW %g\n", outputs.air.dn_O2_gas_dt, outputs.air.dN_fan_dt, outputs.air.P_fan_electric_W);
    fprintf("flow dV %g domega %g Re %g\n", outputs.flow.dV_reservoir_dt, outputs.flow.domega_pump_dt, outputs.flow.Re_flow);
catch ME
    fprintf("ERROR %s\n%s\n", ME.identifier, ME.message);
    for index = 1:min(8, numel(ME.stack))
        fprintf("  %s line %d\n", ME.stack(index).name, ME.stack(index).line);
    end
end

function labels = state_labels(map)
labels = strings(map.count, 1);
labels(1:map.n_cell) = "cell." + string(1:map.n_cell);
labels(map.thermal) = ["T_cell"; "T_collector"; "T_air"];
labels(map.air_system) = ["n_O2"; "n_inert"; "N_fan"];
labels(map.flow) = ["V_res"; "omega"];
labels(map.dc) = "V_dc";
labels(map.converter) = ["i_L"; "V_out"];
labels(map.inverter) = ["int_P"; "int_Q"];
labels(map.transformer) = "T_tr";
labels(map.controller) = "int_I";
labels(map.ride) = "t_viol";
labels(map.degradation) = ["f_area"; "R_extra"; "n_inactive"];
labels(map.sensor) = ["y_sensor"; "bias"];
labels(map.enclosure) = "T_enc";
end
end
