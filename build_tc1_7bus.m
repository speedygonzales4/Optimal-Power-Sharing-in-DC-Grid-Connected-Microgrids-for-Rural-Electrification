function sys = build_tc1_7bus(grid_connected)
%BUILD_TC1_7BUS  TC1: 7-bus radial test case (1 community load + 6 prosumers)

if nargin < 1 || isempty(grid_connected)
    grid_connected = true;
end
grid_connected = logical(grid_connected);

N = 7;

% --- Voltage squared limits
v_min = (0.95)^2;
v_max = (1.05)^2;

% --- Bus data (p.u.)
PG_peak = zeros(N,1);
PL_peak = zeros(N,1);
SOC0    = zeros(N,1);

has_pv  = true(N,1);
has_bat = true(N,1);

% Bus 1: community load
has_pv(1)  = false;
has_bat(1) = false;
PG_peak(1) = 0.0;
PL_peak(1) = 0.30;
SOC0(1)    = 0.0;

% Buses 2-7: prosumers
PG_peak(2:7) = [0.50; 0.55; 0.45; 0.48; 0.52; 0.50];
PL_peak(2:7) = [0.10; 0.12; 0.08; 0.11; 0.09; 0.12];
SOC0(2:7)    = [0.80; 0.75; 0.70; 0.78; 0.72; 0.76];

% --- Battery parameters
SOC_min = 0.50*ones(N,1);
SOC_max = 0.90*ones(N,1);
SOC_min(1) = 0; SOC_max(1) = 0;

Cb = 4.0*ones(N,1);
Cb(1) = 0;

PB_max =  0.40*ones(N,1);
PB_min = -0.40*ones(N,1);
PB_max(1) = 0; PB_min(1) = 0;

% --- Converter loss coefficients
conv.alpha = 0.001;
conv.beta  = 0.015;
conv.gamma = 0.02;

% --- Branches (radial)
from = [1;2;3;2;5;6];
to   = [2;3;4;5;6;7];
r    = [0.05;0.04;0.06;0.05;0.04;0.05];
Imax = 10.0*ones(numel(r),1);

E = numel(r);

% --- Grid extension block
grid.enabled  = grid_connected;
grid.pcc_bus  = 2;
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

% Pack system struct
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