function generate_tables(tc_name, sys, RES, outdir, hour_idx)
%GENERATE_IEEE14_PAPER_TABLES
% Paper-style per-bus OPF-2 snapshot table:
%   BusNo | Pi(p.u.) | PBi(p.u.) | SOCi(%) | Nodal Voltage (p.u.) | Converter Efficiency (% or Non-Op)

if nargin < 5 || isempty(hour_idx)
    hour_idx = 1;
end

if ~exist(outdir, 'dir')
    mkdir(outdir);
end

T = build_bus_table(sys, RES, hour_idx);

pretty_print_table(T, sprintf('%s - OPF-2 (Hour %d snapshot)', tc_name, hour_idx));

base = fullfile(outdir, sprintf('%s_OPF2_hour%02d', tc_name, hour_idx));
writetable(T, base + ".csv");
save(base + ".mat", "T");

fprintf("\nSaved table to: %s\n", outdir);

end


function T = build_bus_table(sys, RES, hour_idx)
% Assembles the per-bus snapshot results table for the requested hour by extracting bus-level variables from RES, converting
% voltage magnitude from squared values, formatting SOC, and computing converter efficiency strings

nb = get_nbus(sys, RES);

% RES arrays are stored as [T x N] in your solver.
Pi   = get_hour_vec(RES, hour_idx, nb, {"Pinj","Pi"});
PBi  = get_hour_vec(RES, hour_idx, nb, {"PB","PBi"});
SOC  = get_hour_vec(RES, hour_idx, nb, {"SOC"});
v_sq = get_hour_vec(RES, hour_idx, nb, {"v","V"});

V = sqrt(max(v_sq, 0));

SOC = SOC(:);
if all(isfinite(SOC)) && max(SOC) <= 1.5
    SOC = 100 * SOC;
end

Pconv = get_hour_vec(RES, hour_idx, nb, {"Pconv"});
eta_str = compute_eta_string(sys, Pi, Pconv);

BusNo = (1:nb).';

T = table(BusNo, Pi(:), PBi(:), SOC(:), V(:), eta_str(:), ...
    'VariableNames', {'Bus No.','Pi (p.u.)','PBi (p.u.)','SOCi (%)','NodalVoltage (p.u.)','Converter Efficiency (%)'});

end

function eta_str = compute_eta_string(sys, Pi, Pconv)
% Computes per-bus converter efficiency as formatted strings

nb = numel(Pi);
eta_str = strings(nb,1);

eps_pi = 1e-3;

hasConvModel = isfield(sys,'conv') && all(isfield(sys.conv,{'alpha','beta','gamma'}));
if hasConvModel
    alpha = sys.conv.alpha;
    beta  = sys.conv.beta;
    gamma = sys.conv.gamma;
else
    alpha = NaN;
    beta = NaN;
    gamma = NaN;
end

for i = 1:nb

    if Pi(i) >= -1e-3 && Pi(i) < 2e-3
        eta_str(i) = "Non-Op";
        continue;
    end

    if ~isfinite(Pi(i)) || abs(Pi(i)) <= eps_pi
        eta_str(i) = "Non-Op";
        continue;
    end

    if numel(Pconv) >= i && isfinite(Pconv(i))
        Pconv_i = max(Pconv(i), 0);
    else
        if ~hasConvModel
            eta_str(i) = "Non-Op";
            continue;
        end
        Po_i = abs(Pi(i));
        Pconv_i = alpha + beta * Po_i + gamma * (Po_i^2);
        Pconv_i = max(Pconv_i, 0);
    end

    denom = abs(Pi(i)) + Pconv_i;
    if denom <= 1e-12
        eta_str(i) = "Non-Op";
        continue;
    end

    eta = 100 * abs(Pi(i)) / denom;
    eta_str(i) = sprintf("%.3f", eta);
end

end

function pretty_print_table(T, title_str)
% Displays the results table in the command window in a cleaner format by zeroing near-zero Pi values and rounding all numeric columns for easier reading

fprintf("\n==================== %s ====================\n", title_str);

Tp = T;

pi_col = strcmp(Tp.Properties.VariableNames, 'Pi (p.u.)');
Pi_vals = Tp{:, pi_col};

mask = (Pi_vals >= -1e-3) & (Pi_vals < 2e-3);
Pi_vals(mask) = 0;

Tp{:, pi_col} = Pi_vals;

isNum = varfun(@isnumeric, Tp, 'OutputFormat','uniform');
Tp{:, isNum} = round(Tp{:, isNum}, 3);

disp(Tp);
end

function nb = get_nbus(sys, RES)
% Determines the number of buses in the system using metadata from sys when available, otherwise infers it from the dimensions of common
% result fields stored in RES

if isstruct(sys)
    if isfield(sys,'N') && ~isempty(sys.N)
        nb = sys.N;
        return;
    end
    if isfield(sys,'nbus') && ~isempty(sys.nbus)
        nb = sys.nbus;
        return;
    end
end

cand = {'v','PB','Pinj','SOC','PG'};
for k = 1:numel(cand)
    f = cand{k};
    if isfield(RES,f) && ~isempty(RES.(f))
        A = RES.(f);
        if ismatrix(A)
            [r,c] = size(A);
            if r > 1 && c > 1
                if isfield(RES,'T') && ~isempty(RES.T) && r == RES.T
                    nb = c;
                    return;
                end
                nb = max(r,c);
                return;
            end
        elseif isvector(A)
            nb = numel(A);
            return;
        end
    end
end

error("Could not determine number of buses from sys or RES.");
end

function vec = get_hour_vec(RES, hour_idx, nb, field_candidates)
% Returns a [nb x 1] vector from RES at hour_idx by trying candidate field names.
% Handles [T x N], [N x T], [N x 1], scalar.

vec = nan(nb,1);

for k = 1:numel(field_candidates)
    f = field_candidates{k};
    if ~isfield(RES,f) || isempty(RES.(f))
        continue;
    end

    A = RES.(f);

    if isscalar(A)
        vec = repmat(double(A), nb, 1);
        return;
    end

    if isvector(A)
        v = double(A(:));
        if numel(v) == nb
            vec = v;
            return;
        end
    end

    if ismatrix(A)
        A = double(A);
        [r,c] = size(A);

        if c == nb && hour_idx <= r
            vec = A(hour_idx,:).';
            return;
        end

        if r == nb && hour_idx <= c
            vec = A(:,hour_idx);
            return;
        end
    end
end

end
