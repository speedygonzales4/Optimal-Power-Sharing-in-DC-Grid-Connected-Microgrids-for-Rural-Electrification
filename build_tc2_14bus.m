function sys = build_tc2_14bus(grid_connected)
%BUILD_TC2_14BUS  TC2: Modified IEEE 14-bus DC system (13 prosumers + 1 community load)

if nargin < 1 || isempty(grid_connected)
    grid_connected = true;
end
grid_connected = logical(grid_connected);

mpc = case14_dc_modified();

N = size(mpc.bus, 1);

% --- Voltage squared limits
v_min = (0.95)^2;
v_max = (1.05)^2;

% --- Loads from MATPOWER Pd
baseMVA = mpc.baseMVA;
Pd_MW = mpc.bus(:, 3);
PL_peak = Pd_MW / baseMVA;

% --- PV sizing
PG_peak = zeros(N,1);
PG_peak(1:13) = max(1.25 * PL_peak(1:13), 0.05);
PG_peak(14)   = 0.0;

% --- Flags
has_pv  = true(N,1);
has_bat = true(N,1);
has_pv(14)  = false;
has_bat(14) = false;

% --- Battery model
nb = 14;
SOC0 = 0.70 + 0.15*rand(nb,1);
SOC0(14) = 0;

SOC_min = 0.50*ones(N,1);
SOC_max = 0.90*ones(N,1);
SOC_min(14) = 0; SOC_max(14) = 0;

Cb = 4.0*ones(N,1);
Cb(14) = 0;

PB_max =  0.40*ones(N,1);
PB_min = -0.40*ones(N,1);
PB_max(14) = 0; PB_min(14) = 0;

% --- Converter loss model
conv.alpha = 0.001;
conv.beta  = 0.015;
conv.gamma = 0.02;

% --- Branch data
from = mpc.branch(:,1);
to   = mpc.branch(:,2);
r    = mpc.branch(:,3);

E = numel(r);
Imax = 10.0*ones(E,1);

% --- Grid extension block
grid.enabled  = grid_connected;
grid.pcc_bus  = 1;
grid.Pimp_max = 4.00;
grid.Pexp_max = 4.00;

% Quadratic grid converter loss model
grid.k0 = 0.002;
grid.k1 = 0.02;
grid.k2 = 0.025;

% Efficiencies still used in power balance
grid.eta_imp  = 0.97;
grid.eta_exp  = 0.97;

grid.Pconv_max = 4.00;

% Incidence matrices
inc_from = sparse(from, (1:E)', 1, N, E);
inc_to   = sparse(to,   (1:E)', 1, N, E);

% Pack sys struct
sys = struct();
sys.N = N;
sys.E = E;
sys.from = from;
sys.to   = to;
sys.r    = r;
sys.Imax = Imax;

sys.v_min = v_min;
sys.v_max = v_max;

sys.PG_peak = PG_peak;
sys.PL_peak = PL_peak;

sys.has_pv  = has_pv;
sys.has_bat = has_bat;

sys.SOC0    = SOC0;
sys.SOC_min = SOC_min;
sys.SOC_max = SOC_max;
sys.Cb      = Cb;
sys.PB_min  = PB_min;
sys.PB_max  = PB_max;

sys.conv = conv;
sys.grid = grid;

sys.inc_from = inc_from;
sys.inc_to   = inc_to;
end