function mpc = case14_dc_modified()
%CASE14_DC_MODIFIED  IEEE 14-bus adapted for DC microgrid studies
% - Reactance set to zero
% - Reactive power demand/generation removed
% - Line resistance reduced by 10%
% - Zero-resistance branches replaced with 0.005 p.u.
% - Voltage magnitude limits set to [0.95, 1.05] p.u.

% Requires MATPOWER on path (case14.m available)
mpc = case14;                 % MATPOWER's IEEE 14-bus test case
mpc.version = '2';

% --- BUS: set Qd = 0, enforce voltage bounds
% bus columns: [BUS_I, TYPE, Pd, Qd, Gs, Bs, AREA, Vm, Va, baseKV, zone, Vmax, Vmin]
mpc.bus(:, 4)  = 0;           % Qd = 0
mpc.bus(:, 6)  = 0;           % Bs = 0 (optional for DC)
mpc.bus(:, 8)  = 1.0;         % Vm = 1.0
mpc.bus(:, 9)  = 0.0;         % Va = 0.0
mpc.bus(:, 12) = 1.05;        % Vmax
mpc.bus(:, 13) = 0.95;        % Vmin

% --- GEN: set Qg/Q limits = 0
% gen columns: [bus Pg Qg Qmax Qmin Vg mBase status Pmax Pmin ...]
mpc.gen(:, 3) = 0;            % Qg
mpc.gen(:, 4) = 0;            % Qmax
mpc.gen(:, 5) = 0;            % Qmin

% --- BRANCH: set x=0, b=0, reduce r by 10%, replace r=0 with 0.005
% branch columns: [f t r x b rateA rateB rateC tap shift status angmin angmax]
r = mpc.branch(:, 3);
x = mpc.branch(:, 4);

% reduce resistance by 10%
r_new = 0.9 .* r;

% replace exact zero-resistance branches with small DC-link resistance
r_new(r == 0) = 0.005;

mpc.branch(:, 3) = r_new;
mpc.branch(:, 4) = 0;         % x = 0 for DC
mpc.branch(:, 5) = 0;         % b = 0 for DC

% taps/phase shifts don't apply in DC link abstraction -> neutralize
mpc.branch(:, 9)  = 0;        % tap = 0 means "line" in MATPOWER
mpc.branch(:, 10) = 0;        % shift = 0
mpc.branch(:, 12) = -360;     % keep unconstrained
mpc.branch(:, 13) =  360;

end