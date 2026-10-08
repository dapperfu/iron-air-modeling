function mon = ironair_standards_assert(T_K, H2_m3, SOC, Power_W, p)
%IRONAIR_STANDARDS_ASSERT UL 9540 / NFPA 855 / IEEE 1547.9 monitors.
% Requirement IDs: SRS012, SRS014, SRS015, SSS013
mon.thermal_pass = (T_K >= p.T_min_K) && (T_K <= p.T_max_K);
mon.H2_pass = H2_m3 <= p.H2_max_m3;
mon.SOC_pass = (SOC >= p.SOC_min) && (SOC <= p.SOC_max);
mon.power_pass = abs(Power_W) <= p.P_max_W;
mon.Pass = mon.thermal_pass && mon.H2_pass && mon.SOC_pass && mon.power_pass;
mon.UL9540_pass = mon.thermal_pass && mon.SOC_pass;
mon.NFPA855_pass = mon.thermal_pass && mon.H2_pass;
mon.IEEE1547_9_pass = mon.power_pass && mon.SOC_pass;
end
