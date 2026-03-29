function RES = solve_opf_24h(sys, pv_prof, load_prof)
%SOLVE_OPF_24H  Hour-by-hour OPF-2 with SOC coupling

T = numel(pv_prof);
N = sys.N;
E = sys.E;
use_grid = isfield(sys, 'grid') && isfield(sys.grid, 'enabled') && sys.grid.enabled;

RES = struct();
RES.mode = "OPF2";
RES.T = T;

RES.v      = nan(T,N);
RES.PG     = nan(T,N);
RES.PB     = nan(T,N);
RES.Pinj   = nan(T,N);
RES.SOC    = nan(T+1,N);
RES.Pij    = nan(T,E);
RES.Pji    = nan(T,E);
RES.lij    = nan(T,E);
RES.Pconv  = nan(T,N);

if use_grid
    RES.PgImp          = nan(T,1);
    RES.PgExp          = nan(T,1);
    RES.Pgrid          = nan(T,1);
    RES.grid_conv_loss = nan(T,1);
end

RES.dist_loss  = nan(T,1);
RES.conv_loss  = nan(T,1);
RES.total_loss = nan(T,1);

SOC_prev = sys.SOC0(:);
RES.SOC(1,:) = SOC_prev';

success = 0;

for t = 1:T
    data_t = struct();
    data_t.t = t;
    data_t.PG_max = sys.PG_peak .* pv_prof(t);
    data_t.PL     = sys.PL_peak .* load_prof(t);

    [sol, ok] = solve_opf_hour_fmincon(sys, data_t, SOC_prev);

    if ok
        success = success + 1;
        RES.v(t,:)     = sol.v(:)';
        RES.PG(t,:)    = sol.PG(:)';
        RES.PB(t,:)    = sol.PB(:)';
        RES.Pinj(t,:)  = sol.Pinj(:)';
        RES.SOC(t+1,:) = sol.SOC_next(:)';

        RES.Pij(t,:)   = sol.Pij(:)';
        RES.Pji(t,:)   = sol.Pji(:)';
        RES.lij(t,:)   = sol.lij(:)';

        RES.Pconv(t,:) = sol.Pconv(:)';

        if use_grid
            RES.PgImp(t) = sol.PgImp;
            RES.PgExp(t) = sol.PgExp;
            RES.Pgrid(t) = sol.Pgrid;
            RES.grid_conv_loss(t) = sol.grid_conv_loss;
        end

        RES.dist_loss(t)  = sol.dist_loss;
        RES.conv_loss(t)  = sol.conv_loss;
        RES.total_loss(t) = sol.total_loss;

        SOC_prev = sol.SOC_next(:);
    else
        RES.SOC(t+1,:) = SOC_prev';
    end
end

RES.success_hours = success;
end
