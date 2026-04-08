function f = opf_objective(x, sys, data_t, idx)
%OPF_OBJECTIVE Computes the scalar objective value for the OPF problem
% The objective includes:
%   1. Distribution line losses
%   2. Converter losses at the buses
%   3. Optional grid-side converter loss if grid connection is enabled

% Extract squared branch current magnitudes for all lines
% These are the lij variables used in the loss expression r_ij * l_ij
l = x(idx.lij);

% Compute total distribution loss across all branches
% sys.r contains the branch resistances
dist = sum(sys.r(:) .* l(:));

% Extract converter loss variables for all buses
Pconv = x(idx.Pconv);
base = dist + sum(Pconv);


grid_conv_loss = 0;
if isfield(idx,'PgImp') && ~isempty(idx.PgImp) && ...
   isfield(sys,'grid') && isfield(sys.grid,'enabled') && sys.grid.enabled
   
   % Extract grid import and export decision variables
    PgImp = x(idx.PgImp);
    PgExp = x(idx.PgExp);

    % processed grid power
    Pgrid = PgImp + PgExp;

    % Extract quadratic converter-loss model coefficients for the grid-side interface converter
    k0g = sys.grid.k0;
    k1g = sys.grid.k1;
    k2g = sys.grid.k2;

    % Compute grid-side converter loss using quadratic model:
    grid_conv_loss = k0g + k1g * Pgrid + k2g * (Pgrid.^2);
end

f = base + grid_conv_loss;

end
