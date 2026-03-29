function plot_testcase_figures(tc_name, sys, res, outdir)
%PLOT_TESTCASE_FIGURES
% Generates:
%   (1) PV vs Load profiles
%   (2) Total losses (dist, converter, total)
%   (3) Active converters
%   (4) Bus net power injection schedule
%   (5) Grid and battery exchange (if grid-connected)


    tc = string(tc_name);

    T = infer_T(res);
    hours = 0:(T-1);

    [pv_mult, load_mult] = infer_profiles(sys, T);

    if ~isempty(pv_mult) && ~isempty(load_mult)
        f0 = figure('Name', "Profiles_" + tc, 'Color', 'w');

        pv_mult   = pv_mult(:).';
        load_mult = load_mult(:).';

        if numel(pv_mult) > T
            pv_mult = pv_mult(1:T);
        elseif numel(pv_mult) < T
            pv_mult = [pv_mult, nan(1, T-numel(pv_mult))];
        end

        if numel(load_mult) > T
            load_mult = load_mult(1:T);
        elseif numel(load_mult) < T
            load_mult = [load_mult, nan(1, T-numel(load_mult))];
        end

        plot(hours, load_mult, '-o', 'LineWidth', 1.5, 'MarkerSize', 4); hold on;
        plot(hours, pv_mult,   '-o', 'LineWidth', 1.5, 'MarkerSize', 4);
        grid on;
        xlabel('Time (h)');
        ylabel('Normalized Profile');
        title("PV vs Load Profiles - " + tc);
        legend({'Load Profile','PV Profile'}, 'Location','best');

    else
        warning("[plot_testcase_figures] PV/Load profiles not found.");
    end

    dist = get_series(res, ["distLoss_hour","dist_loss","distloss_hour","distLoss","dist_loss_hour"], T);
    conv = get_series(res, ["convLoss_hour","conv_loss","convloss_hour","convLoss","conv_loss_hour"], T);
    grid_conv = get_series(res, ["grid_conv_loss"], T);
    tot  = get_series(res, ["totalLoss_hour","total_loss","totalloss_hour","totalLoss","total_loss_hour"], T);
    if all(isnan(tot))
        tot = safe_sum(safe_sum(dist, conv), grid_conv);
    end

    Pinj = get_matrix(res, ["P_inj","Pinj","Pij_node","Pnet","P","Pinj_hour"], T);

    thresh = 1e-3;
    active = count_active(Pinj, thresh, T);

       f1 = figure('Name', "TotalLoss_" + tc, 'Color', 'w');
    plot(hours, dist,      '-o', 'LineWidth', 1.3); hold on;
    plot(hours, conv,      '-s', 'LineWidth', 1.3);
    plot(hours, grid_conv, '-^', 'LineWidth', 1.3);
    plot(hours, tot,       '-d', 'LineWidth', 1.5);
    grid on;
    xlabel('Hour of Day');
    ylabel('Loss (p.u.)');
    title("Total Losses - OPF-2 - " + tc);
    legend({'Distribution','Converter','Grid converter','Total'}, 'Location','best');

    f2 = figure('Name', "ActiveConverters_" + tc, 'Color', 'w');
    bar(hours, active(:));
    grid on;
    xlabel('Hour of Day');
    ylabel('Number of Active Converters');
    title("Operating Converters - OPF-2 - " + tc);

    f3 = figure('Name', "PowerSchedule_" + tc, 'Color', 'w');
    hold on; grid on;
    plot_power_schedule_lines(Pinj, hours);
    xlabel('Time (h)');
    ylabel('Net Bus Injection, P_{inj} (p.u.)');
    title("Bus Net Power Injection - OPF-2 - " + tc);

    if isfield(sys, 'grid') && isfield(sys.grid, 'enabled') && sys.grid.enabled && ...
       isfield(res, 'PgImp') && isfield(res, 'PgExp') && isfield(res, 'PB')

        Pimp = get_series(res, ["PgImp"], T);
        Pexp = get_series(res, ["PgExp"], T);
        Pgrid_net = Pexp - Pimp;   % +export, -import

        PBmat = get_matrix(res, ["PB"], T);
        if isempty(PBmat)
            PBtot = nan(T,1);
        else
            PBtot = sum(PBmat, 2, 'omitnan');   % +charge, -discharge
        end

        f4 = figure('Name', "GridBatteryExchange_" + tc, 'Color', 'w');
        hold on; grid on;

        exch_data = [Pgrid_net(:), PBtot(:)];
        bar(hours, exch_data, 1.0, 'grouped');

        yline(0, ':', 'LineWidth', 0.8);
        xlabel('Hour of Day');
        ylabel('Power (p.u.)');
        title("Grid and Battery Power Exchange - OPF-2 - " + tc);
        legend({'Grid exchange', ...
                'Battery power'}, ...
                'Location', 'best');

    end
end

function [pv_mult, load_mult] = infer_profiles(sys, T)
    pv_mult   = [];
    load_mult = [];

    if isstruct(sys)
        pv_mult   = try_profile_field(sys, ["pv_profile","PV_profile","pv_mult","PV_mult","pv_multiplier","PV_multiplier"], T);
        load_mult = try_profile_field(sys, ["load_profile","Load_profile","load_mult","Load_mult","load_multiplier","Load_multiplier"], T);
    end

    if isempty(pv_mult) && exist('generate_pv_profile','file') == 2
        try
            pv_mult = generate_pv_profile(T);
            pv_mult = pv_mult(:).';
        catch
            pv_mult = [];
        end
    end
    if isempty(load_mult) && exist('generate_load_profile','file') == 2
        try
            load_mult = generate_load_profile(T);
            load_mult = load_mult(:).';
        catch
            load_mult = [];
        end
    end

    if ~isempty(pv_mult) && numel(pv_mult) ~= T
        pv_mult = reshape_to_T(pv_mult, T);
    end
    if ~isempty(load_mult) && numel(load_mult) ~= T
        load_mult = reshape_to_T(load_mult, T);
    end

    if ~isempty(pv_mult) && numel(pv_mult) ~= T
        pv_mult = [];
    end
    if ~isempty(load_mult) && numel(load_mult) ~= T
        load_mult = [];
    end
end

function v = try_profile_field(sys, names, T)
    v = [];
    for k = 1:numel(names)
        nm = names(k);
        if isfield(sys, nm)
            raw = sys.(nm);
            if isnumeric(raw)
                raw = raw(:).';
                if numel(raw) == T
                    v = raw;
                    return;
                elseif numel(raw) == T+1
                    v = raw(1:T);
                    return;
                end
            end
        end
    end
end

function v = reshape_to_T(raw, T)
    raw = raw(:).';
    if numel(raw) > T
        v = raw(1:T);
    elseif numel(raw) < T
        v = [raw, repmat(raw(end), 1, T-numel(raw))];
    else
        v = raw;
    end
end

function T = infer_T(res)
    candidates = [];
    candidates(end+1) = try_len(res, "totalLoss_hour");
    candidates(end+1) = try_len(res, "total_loss");
    candidates(end+1) = try_len(res, "distLoss_hour");
    candidates(end+1) = try_len(res, "dist_loss");
    candidates(end+1) = try_len(res, "convLoss_hour");
    candidates(end+1) = try_len(res, "conv_loss");
    candidates(end+1) = try_len(res, "grid_conv_loss");
    candidates(end+1) = try_rows(res, "P_inj");
    candidates(end+1) = try_rows(res, "Pinj");
    candidates(end+1) = try_len(res, "Pgrid");
    candidates(end+1) = try_len(res, "PgImp");
    candidates(end+1) = try_len(res, "PgExp");
    candidates(end+1) = try_rows(res, "PB");

    candidates = candidates(candidates > 0);

    if isempty(candidates)
        T = 24;
    else
        T = mode(candidates);
    end
end

function n = try_len(s, fname)
    n = 0;
    if isstruct(s) && isfield(s, fname)
        v = s.(fname);
        if isnumeric(v) && isvector(v)
            n = numel(v);
        end
    end
end

function n = try_rows(s, fname)
    n = 0;
    if isstruct(s) && isfield(s, fname)
        v = s.(fname);
        if isnumeric(v) && ~isvector(v)
            n = size(v,1);
        end
    end
end

function v = get_series(res, names, T)
    v = nan(1,T);
    for k = 1:numel(names)
        nm = names(k);
        if isfield(res, nm)
            raw = res.(nm);
            if isnumeric(raw)
                raw = raw(:).';
                if numel(raw) == T
                    v = raw;
                    return;
                end
            end
        end
    end
end

function M = get_matrix(res, names, T)
    M = [];
    for k = 1:numel(names)
        nm = names(k);
        if isfield(res, nm)
            raw = res.(nm);
            if isnumeric(raw)
                if size(raw,1) == T
                    M = raw;
                    return;
                elseif size(raw,2) == T
                    M = raw.';
                    return;
                end
            end
        end
    end
end

function y = safe_sum(a,b)
    if isempty(a) && isempty(b)
        y = nan;
        return;
    end
    if isempty(a)
        a = zeros(size(b));
    end
    if isempty(b)
        b = zeros(size(a));
    end
    y = a + b;
end

function active = count_active(Pinj, thresh, T)
    if isempty(Pinj)
        active = nan(T,1);
        return;
    end
    active = sum(abs(Pinj) > thresh, 2);
end

function plot_power_schedule_lines(Pinj, hours)
    if isempty(Pinj)
        text(0.1,0.5,"Pinj/Pi data not found","Units","normalized");
        return;
    end

    if size(Pinj,1) ~= numel(hours) && size(Pinj,2) == numel(hours)
        Pinj = Pinj.';
    end

    T = numel(hours);
    if size(Pinj,1) ~= T
        Pinj = Pinj(1:min(end,T), :);
        if size(Pinj,1) < T
            Pinj = [Pinj; nan(T-size(Pinj,1), size(Pinj,2))];
        end
    end

    N = size(Pinj,2);
    for i = 1:N
        plot(hours, Pinj(:,i), '-o', 'LineWidth', 1.2, 'MarkerSize', 3);
    end

    leg = strings(N,1);
    for i = 1:N
        leg(i) = sprintf("Bus %d net injection", i);
    end
    legend(leg, 'Location', 'eastoutside');

    yline(0, ':', 'LineWidth', 0.8);
end

function s = safe_filename(tc)
    s = regexprep(tc, "[^\w\-]", "_");
end