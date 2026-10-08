function y = ironair_standards_assert_vector(u)
% u = [T_K; H2_m3; SOC; Power_W]
IronAir = evalin('base', 'IronAir');
mon = ironair_standards_assert(u(1), u(2), u(3), u(4), IronAir.Standards);
y = [double(mon.Pass); double(mon.UL9540_pass); double(mon.NFPA855_pass); ...
    double(mon.IEEE1547_9_pass)];
end
