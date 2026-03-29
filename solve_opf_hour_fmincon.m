function [sol, ok] = solve_opf_hour_fmincon(sys, data_t, SOC_prev)
%SOLVE_OPF_HOUR_FMINCON  Single-hour OPF-2 solved by fmincon

use_grid = isfield(sys, 'grid') && isfield(sys.grid, 'enabled') && sys.grid.enabled;

N = sys.N;
E = sys.E;

idx = opf_index(N, E, use_grid);

% --- Bounds
lb = -inf(idx.nx,1);
ub =  inf(idx.nx,1);

% v bounds
lb(idx.v) = sys.v_min;
ub(idx.v) = sys.v_max;

% PG bounds
lb(idx.PG) = 0;
ub(idx.PG) = data_t.PG_max;

% Enforce no-PV buses
no_pv = ~sys.has_pv;
lb(idx.PG(no_pv)) = 0;
ub(idx.PG(no_pv)) = 0;

% PB bounds (charge +, discharge -)
lb(idx.PB) = sys.PB_min;
ub(idx.PB) = sys.PB_max;

no_bat = ~sys.has_bat;
lb(idx.PB(no_bat)) = 0;
ub(idx.PB(no_bat)) = 0;

% Pinj: leave wide but finite helps numerics
lb(idx.Pinj) = -5;
ub(idx.Pinj) =  5;

% SOC_next bounds
lb(idx.SOCn) = sys.SOC_min;
ub(idx.SOCn) = sys.SOC_max;
lb(idx.SOCn(no_bat)) = 0;
ub(idx.SOCn(no_bat)) = 0;

% Grid import/export bounds (AC side)
if use_grid
    lb(idx.PgImp) = 0;
    ub(idx.PgImp) = sys.grid.Pimp_max;

    lb(idx.PgExp) = 0;
    ub(idx.PgExp) = sys.grid.Pexp_max;
end

% l_ij bounds: 0 <= l <= Imax^2
lb(idx.lij) = 0;
ub(idx.lij) = (sys.Imax(:)).^2;

% OPF-2 converter bounds
lb(idx.Po)    = 0;
ub(idx.Po)    = 10;
lb(idx.Pconv) = 0;
ub(idx.Pconv) = 10;

% --- Initial guess
x0 = zeros(idx.nx,1);
x0(idx.v) = 1.0;

PG0 = data_t.PG_max;

PB0 = PG0 - data_t.PL;
PB0 = max(min(PB0, sys.PB_max), sys.PB_min);

x0(idx.PG) = PG0;
x0(idx.PB) = PB0;
x0(idx.SOCn) = max(min(SOC_prev + PB0 ./ max(sys.Cb,1e-6), sys.SOC_max), sys.SOC_min);

grid_term0 = zeros(N,1);

if use_grid
    residual0 = sum(data_t.PL + PB0 - PG0);

    k_pcc = sys.grid.pcc_bus;
    eta_imp = max(sys.grid.eta_imp, 1e-9);
    eta_exp = max(sys.grid.eta_exp, 1e-9);

    if residual0 >= 0
        % Need net import from grid
        x0(idx.PgImp) = min(residual0 / eta_imp, sys.grid.Pimp_max);
        x0(idx.PgExp) = 0;
    else
        % Need net export to grid
        x0(idx.PgImp) = 0;
        x0(idx.PgExp) = min((-residual0) * eta_exp, sys.grid.Pexp_max);
    end

    grid_term0(k_pcc) = eta_imp * x0(idx.PgImp) - x0(idx.PgExp) / eta_exp;
end

Pinj0 = PG0 - PB0 - data_t.PL + grid_term0;
x0(idx.Pinj) = Pinj0;

x0(idx.Pij) = 0;
x0(idx.Pji) = 0;
x0(idx.lij) = 0;

x0(idx.Po)    = abs(Pinj0);
x0(idx.Pconv) = sys.conv.alpha + sys.conv.beta*x0(idx.Po) + sys.conv.gamma*(x0(idx.Po).^2);

% --- fmincon
opts = optimoptions('fmincon', ...
    'Algorithm','interior-point', ...
    'Display','off', ...
    'MaxIterations', 4000, ...
    'MaxFunctionEvaluations', 40000, ...
    'ConstraintTolerance', 1e-6, ...
    'OptimalityTolerance', 1e-6);

try
    fun = @(x) opf_objective(x, sys, data_t, idx);
    nonlcon = @(x) opf_constraints(x, sys, data_t, SOC_prev, idx);

    [xsol, ~, exitflag, output] = fmincon(fun, x0, [], [], [], [], lb, ub, nonlcon, opts);

max_violation = output.constrviolation;
ok = (exitflag > 0) || (max_violation <= 1e-5);

if ~ok
    fprintf('\n[Hour %d] fmincon failed. exitflag = %d\n', data_t.t, exitflag);
    fprintf('Max constraint violation: %.3e\n', max_violation);
    disp(output.message);
end
catch ME
    fprintf('\n[Hour %d] Solver error:\n%s\n', data_t.t, ME.message);
    xsol = [];
    ok = false;
end

if ~ok
    sol = struct();
    return;
end

sol = opf_unpack(xsol, sys, idx);
end