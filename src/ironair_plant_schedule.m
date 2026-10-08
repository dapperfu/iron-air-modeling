function [P_dc, I_pack] = ironair_plant_schedule(P_ac_ref, V_pack, eta_pcs)
%IRONAIR_PLANT_SCHEDULE Plant power schedule to DC pack current.
% P_ac_ref > 0 discharge to grid. Requirement IDs: SSS011
eta_pcs = min(max(eta_pcs, 0.5), 1);
if P_ac_ref >= 0
    P_dc = P_ac_ref / eta_pcs;
else
    P_dc = P_ac_ref * eta_pcs; % charge: AC more negative than DC
end
I_pack = P_dc / max(V_pack, 0.1);
end
