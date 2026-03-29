function run_tc3(grid_connected)
%RUN_TC3  Runs OPF-2 for the 20-bus clustered-ring test case

clc; close all;

if nargin < 1 || isempty(grid_connected)
    fprintf('\nSelect grid connection mode for TC3:\n');
    fprintf('  1 = Grid-connected\n');
    fprintf('  0 = Islanded\n');
    grid_connected = input('Enter choice (1 or 0): ');
end
grid_connected = logical(grid_connected);

fprintf('\nSet PV availability level for TC3 (0 to 1):\n');
fprintf('  1 = Full PV generation\n');
fprintf('  0 = No PV generation\n');
pv_scale = input('Enter PV availability (0-1): ');
pv_scale = max(0, min(1, pv_scale));

sys = build_tc3_20bus(grid_connected);
sys.load_sheet = 'Test Case 3';

T = 24;

[pv_prof, load_prof, sys] = get_profiles_from_csv_or_default(sys, T);

pv_prof = pv_scale * pv_prof;
sys.pv_profile = pv_prof;

tic;
RES = solve_opf_24h(sys, pv_prof, load_prof);
elapsed_time = toc;
RES.runtime = elapsed_time;

tc_name = "TC3-20bus";
if grid_connected
    tc_name = "TC3-20bus-grid";
else
    tc_name = "TC3-20bus-islanded";
end

outdir = fullfile(pwd, "figures");
plot_testcase_figures(tc_name, sys, RES, outdir);

fprintf('\n==================== OPF2 ====================\n');
fprintf('Grid connected mode: %d\n', grid_connected);
fprintf('PV availability scale: %.2f\n', pv_scale);
print_summary(RES);
fprintf('Optimization runtime: %.4f seconds\n', elapsed_time);

fprintf('\nSelect result hour to generate tables (1 to %d):\n', T);
hour_idx = input(sprintf('Enter hour index (1-%d): ', T));

if isempty(hour_idx) || ~isscalar(hour_idx) || ~isfinite(hour_idx)
    error('Hour index must be a single numeric value.');
end

hour_idx = round(hour_idx);

if hour_idx < 1 || hour_idx > T
    error('Hour index must be between 1 and %d.', T);
end

tables_outdir = fullfile(pwd, "tables");
generate_tables(tc_name, sys, RES, tables_outdir, hour_idx);

end

function [pv_prof, load_prof, sys] = get_profiles_from_csv_or_default(sys, T)
    pv_prof   = [];
    load_prof = [];

    if exist('read_pv_and_load_csv','file') == 2
        try
            data = read_pv_and_load_csv( ...
                '1002919_27.05_18.02_tmy-2022.csv', ...
                '2 - Microgrid_Load_Profile_Explorer.xlsx', ...
                2022, 8, 1, 30, sys.load_sheet);

            pv_prof   = data.PV_profile(:).';
            load_prof = data.Load_profile(:).';
        catch ME
            warning('%s', sprintf(['[run_tc3] Profile file load failed. ', ...
                'Using zero PV fallback and default flat load fallback.\n%s'], ME.message));
        end
    else
        warning('[run_tc3] read_pv_and_load_csv.m not found. Using fallback profiles.');
    end

    if isempty(pv_prof)
        pv_prof = zeros(1,T);
    end

    if isempty(load_prof)
        load_prof = ones(1,T);
    end

    if numel(pv_prof) ~= T
        pv_prof = reshape_to_T_local(pv_prof, T);
    end
    if numel(load_prof) ~= T
        load_prof = reshape_to_T_local(load_prof, T);
    end

    pv_prof(~isfinite(pv_prof)) = 0;
    pv_prof = max(pv_prof, 0);

    if any(~isfinite(load_prof))
        error('[run_tc3] Load profile contains non-finite values.');
    end
    if any(load_prof < 0)
        error('[run_tc3] Load profile contains negative values.');
    end

    sys.pv_profile   = pv_prof;
    sys.load_profile = load_prof;
end

function v = reshape_to_T_local(raw, T)
    raw = raw(:).';
    if isempty(raw)
        v = zeros(1,T);
    elseif numel(raw) > T
        v = raw(1:T);
    elseif numel(raw) < T
        v = [raw, repmat(raw(end), 1, T-numel(raw))];
    else
        v = raw;
    end
end

function print_summary(RES)
fprintf('Successful hours: %d/%d\n', RES.success_hours, RES.T);
fprintf('Total dist loss (p.u.): %.6f\n', sum(RES.dist_loss,'omitnan'));
fprintf('Total conv loss (p.u.): %.6f\n', sum(RES.conv_loss,'omitnan'));

if isfield(RES, 'grid_conv_loss')
    fprintf('Total grid conv loss (p.u.): %.6f\n', sum(RES.grid_conv_loss,'omitnan'));
end

fprintf('Total system loss (p.u.): %.6f\n', sum(RES.total_loss,'omitnan'));
end