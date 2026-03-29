function [c, ceq] = opf_constraints(x, sys, data_t, SOC_prev, idx)
%OPF_CONSTRAINTS  Nonlinear constraints for fmincon

N = sys.N;

v    = x(idx.v);
PG   = x(idx.PG);
PB   = x(idx.PB);
Pinj = x(idx.Pinj);
SOCn = x(idx.SOCn);

if ~isempty(idx.PgImp)
    PgImp = x(idx.PgImp);
    PgExp = x(idx.PgExp);
else
    PgImp = 0;
    PgExp = 0;
end

Pij  = x(idx.Pij);
Pji  = x(idx.Pji);
l    = x(idx.lij);

% Converter terms (OPF-2 only)
Po    = x(idx.Po);
Pconv = x(idx.Pconv);

PL = data_t.PL;

% --- Grid injection at PCC via bidirectional AC/DC converter
grid_term = zeros(N,1);
if isfield(sys, 'grid') && isfield(sys.grid, 'enabled') && sys.grid.enabled
    k_pcc = sys.grid.pcc_bus;
    if k_pcc < 1 || k_pcc > N
        error('sys.grid.pcc_bus (%d) is out of bounds for N=%d.', k_pcc, N);
    end
    eta_imp = max(sys.grid.eta_imp, 1e-9);
    eta_exp = max(sys.grid.eta_exp, 1e-9);
    grid_term(k_pcc) = eta_imp * PgImp - (PgExp / eta_exp);
end

% --- Power balance
ceq_balance = PG - PB - PL - Pconv + grid_term - Pinj;

% --- Pinj definition via outgoing flows
sum_out = sys.inc_from * Pij + sys.inc_to * Pji;
ceq_inj = Pinj - sum_out;

% --- Branch loss
ceq_loss = (Pij + Pji) - (sys.r(:) .* l);

% --- Voltage drop
vf = v(sys.from);
vt = v(sys.to);
ceq_vdrop = (vf - vt) - (sys.r(:) .* (Pij - Pji));

% --- SOC update
Cb = sys.Cb(:);
Cb_safe = max(Cb, 1e-9);
ceq_soc = SOCn - (SOC_prev + PB ./ Cb_safe);

% --- Enforce no-PV/no-battery buses exactly
no_pv = ~sys.has_pv;
no_bat = ~sys.has_bat;

ceq_nopv  = PG(no_pv);
ceq_nobat = [PB(no_bat); SOCn(no_bat)];

% --- Battery capability constraints
SOC_max = sys.SOC_max(:);
SOC_min = sys.SOC_min(:);

c_bat_chg = PB - (Cb_safe .* (SOC_max - SOC_prev));
c_bat_dis = (-PB) - (Cb_safe .* (SOC_prev - SOC_min));
c_bat = [c_bat_chg; c_bat_dis];

% --- SOCP relaxation
v_i = v(sys.from);
c_socp = (Pij.^2) - (v_i .* l);

% --- Grid operating constraints
if ~isempty(idx.PgImp)
    eta_imp = max(sys.grid.eta_imp, 1e-9);
    eta_exp = max(sys.grid.eta_exp, 1e-9);

    % No simultaneous import and export
    c_grid_mode = [];

    % PCC converter DC-side throughput limits
    if isfield(sys.grid, 'Pconv_max') && ~isempty(sys.grid.Pconv_max)
        Pconv_max = sys.grid.Pconv_max;
    else
        Pconv_max = inf;
    end
    c_grid_conv_imp = eta_imp * PgImp - Pconv_max;
    c_grid_conv_exp = (PgExp / eta_exp) - Pconv_max;
else
    c_grid_mode = [];
    c_grid_conv_imp = [];
    c_grid_conv_exp = [];
end

% --- Converter constraints
alpha = sys.conv.alpha;
beta  = sys.conv.beta;
gamma = sys.conv.gamma;

c_conv1 = (alpha + beta*Po + gamma*(Po.^2)) - Pconv;
c_conv2 = Pinj - Po;
c_conv3 = -Pinj - Po;

c = [c_bat;
     c_socp;
     c_conv1;
     c_conv2;
     c_conv3;
     c_grid_mode;
     c_grid_conv_imp;
     c_grid_conv_exp];

ceq = [ceq_balance;
       ceq_inj;
       ceq_loss;
       ceq_vdrop;
       ceq_soc;
       ceq_nopv;
       ceq_nobat];
end