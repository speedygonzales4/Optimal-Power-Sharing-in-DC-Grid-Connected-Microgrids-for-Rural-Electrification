function sys = build_tc3_20bus(grid_connected)
%BUILD_TC3_20BUS  20-bus clustered ring (4 clusters x 5 nodes)

if nargin < 1 || isempty(grid_connected)
    grid_connected = true;
end
grid_connected = logical(grid_connected);

rng(42);

N = 20;

% --- Bus parameters (p.u.)
% Community load at bus 20 (index 20) with no PV/battery.
PG_peak = zeros(N,1);
PL_peak = zeros(N,1);
SOC0    = zeros(N,1);

has_pv  = true(N,1);
has_bat = true(N,1);

for i = 1:N-1
    PG_peak(i) = 0.35 + 0.20*rand();   % p.u.
    PL_peak(i) = 0.08 + 0.08*rand();   % p.u.
    SOC0(i)    = 0.70 + 0.15*rand();   % fraction
end

% Community load bus (20)
PG_peak(N) = 0.0;
PL_peak(N) = 0.50;
SOC0(N)    = 0.0;
has_pv(N)  = false;
has_bat(N) = false;

% --- Battery parameters
% SOC limits are the 50%-90% band referenced
SOC_min = 0.50*ones(N,1);
SOC_max = 0.90*ones(N,1);
SOC_min(N) = 0; SOC_max(N) = 0;

Cb = 4.0*ones(N,1);    % p.u.-h capacity
Cb(N) = 0;

% Battery power limits (charge positive, discharge negative)
PB_max =  0.40*ones(N,1);
PB_min = -0.40*ones(N,1);
PB_max(N) = 0; PB_min(N) = 0;

% --- Converter loss coefficients (OPF-2)
conv.alpha = 0.001;
conv.beta  = 0.015;
conv.gamma = 0.02;

% --- Voltage squared limits (0.95)^2 to (1.05)^2
v_min = (0.95)^2;
v_max = (1.05)^2;

% --- Build clustered-ring edges
% Cluster rings: (1-2-3-4-5-1), (6-7-8-9-10-6), (11-12-13-14-15-11), (16-17-18-19-20-16)
r_intra = 0.04;
r_inter = 0.06;

from = [];
to   = [];
r    = [];
Imax = [];

clusters = {1:5, 6:10, 11:15, 16:20};
for c = 1:numel(clusters)
    nodes = clusters{c};
    for k = 1:numel(nodes)
        i = nodes(k);
        j = nodes(mod(k, numel(nodes)) + 1);
        from(end+1,1) = i;
        to(end+1,1)   = j;
        r(end+1,1)    = r_intra + 0.01*rand();
        Imax(end+1,1) = 10.0;
    end
end

% Gateway ring among gateways 3,8,13,18
gateways = [3 8 13 18];
for k = 1:numel(gateways)
    i = gateways(k);
    j = gateways(mod(k,numel(gateways))+1);
    from(end+1,1) = i;
    to(end+1,1)   = j;
    r(end+1,1)    = r_inter + 0.01*rand();
    Imax(end+1,1) = 10.0;
end

E = numel(r);

% --- Grid extension for TC3 only (utility AC grid via PCC AC/DC converter)
grid.enabled   = grid_connected;
grid.pcc_bus   = 3;       % utility point-of-common-coupling bus on DC network
grid.Pimp_max  = 4.00;    % max AC-side import from utility (p.u.)
grid.Pexp_max  = 4.00;    % max AC-side export to utility (p.u.)

% Quadratic grid converter loss model
grid.k0 = 0.002;
grid.k1 = 0.02;
grid.k2 = 0.025;

% Efficiencies still used in power balance
grid.eta_imp   = 0.97;    % import path efficiency (AC->DC)
grid.eta_exp   = 0.97;    % export path efficiency (DC->AC)

grid.Pconv_max = 4.00;    % max DC-side throughput of PCC converter (p.u.)

% Incidence helper (for fast injection equations)
inc_from = sparse(from, (1:E)', 1, N, E);
inc_to   = sparse(to,   (1:E)', 1, N, E);

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