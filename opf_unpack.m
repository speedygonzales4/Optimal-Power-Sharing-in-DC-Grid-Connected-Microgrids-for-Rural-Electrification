function sol = opf_unpack(x, sys, idx)
%OPF_UNPACK  Convenience: compute outputs + losses 

sol = struct();
sol.v    = x(idx.v);
sol.PG   = x(idx.PG);
sol.PB   = x(idx.PB);
sol.Pinj = x(idx.Pinj);
sol.SOC_next = x(idx.SOCn);

if isfield(idx, 'PgImp') && ~isempty(idx.PgImp)
    sol.PgImp = x(idx.PgImp);
    sol.PgExp = x(idx.PgExp);

    % Processed grid power magnitude for quadratic PCC converter loss model
    sol.Pgrid = sol.PgImp + sol.PgExp;

    if isfield(sys, 'grid') && isfield(sys.grid, 'enabled') && sys.grid.enabled
        k0g = sys.grid.k0;
        k1g = sys.grid.k1;
        k2g = sys.grid.k2;
        sol.grid_conv_loss = k0g + k1g * sol.Pgrid + k2g * (sol.Pgrid^2);
    else
        sol.grid_conv_loss = 0;
    end
else
    sol.PgImp = 0;
    sol.PgExp = 0;
    sol.Pgrid = 0;
    sol.grid_conv_loss = 0;
end

sol.Pij  = x(idx.Pij);
sol.Pji  = x(idx.Pji);
sol.lij  = x(idx.lij);

sol.Po    = x(idx.Po);
sol.Pconv = x(idx.Pconv);

sol.dist_loss = sum(sys.r(:) .* sol.lij(:));
sol.conv_loss = sum(sol.Pconv(:));
sol.total_loss = sol.dist_loss + sol.conv_loss + sol.grid_conv_loss;

end