function run_tc1(grid_connected)
%RUN_TC1  Runs OPF-2 for TC1 (7-bus radial)

clc; close all;

if nargin < 1 || isempty(grid_connected)
    fprintf('\nSelect grid connection mode for TC1:\n');
    fprintf('  1 = Grid-connected\n');
    fprintf('  0 = Islanded\n');
    grid_connected = input('Enter choice (1 or 0): ');
end
grid_connected = logical(grid_connected);

fprintf('\nSet PV availability level for TC1 (0 to 1):\n');
fprintf('  1 = Full PV generation\n');
fprintf('  0 = No PV generation\n');
pv_scale = input('Enter PV availability (0-1): ');
pv_scale = max(0, min(1, pv_scale));

sys = build_tc1_7bus(grid_connected);
sys.load_sheet = 'Test Case 1';

T = 24;

[pv_prof, load_prof, sys] = get_profiles_from_csv_or_default(sys, T);

pv_prof = pv_scale * pv_prof;
sys.pv_profile = pv_prof;

tic;
RES = solve_opf_24h(sys, pv_prof, load_prof);
elapsed_time = toc;
RES.runtime = elapsed_time;

tc_name = "TC1-7bus";
if grid_connected
    tc_name = tc_name + "-grid";
else
    tc_name = tc_name + "-islanded";
end

outdir = fullfile(pwd, "figures");
plot_testcase_figures(tc_name, sys, RES, outdir);

fprintf('\n==================== TC1 OPF2 ====================\n');
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
    if exist('read_pv_and_load_csv','file') ~= 2
        error('read_pv_and_load_csv.m not found. Cannot proceed without input data.');
    end

    data = read_pv_and_load_csv( ...
        '1002919_27.05_18.02_tmy-2022.csv', ...
        '2 - Microgrid_Load_Profile_Explorer.xlsx', ...
        2022, 8, 1, 30, sys.load_sheet);

    pv_prof   = data.PV_profile(:).';
    load_prof = data.Load_profile(:).';

    if numel(pv_prof) ~= T
        pv_prof = reshape_to_T_local(pv_prof, T);
    end
    if numel(load_prof) ~= T
        load_prof = reshape_to_T_local(load_prof, T);
    end

    sys.pv_profile   = pv_prof;
    sys.load_profile = load_prof;
end

function v = reshape_to_T_local(raw, T)
    raw = raw(:).';
    if numel(raw) > T
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
