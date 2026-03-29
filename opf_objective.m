function f = opf_objective(x, sys, data_t, idx)

l = x(idx.lij);
dist = sum(sys.r(:) .* l(:));

Pconv = x(idx.Pconv);
base = dist + sum(Pconv);


grid_conv_loss = 0;
if isfield(idx,'PgImp') && ~isempty(idx.PgImp) && ...
   isfield(sys,'grid') && isfield(sys.grid,'enabled') && sys.grid.enabled

    PgImp = x(idx.PgImp);
    PgExp = x(idx.PgExp);

    % processed grid power
    Pgrid = PgImp + PgExp;

    k0g = sys.grid.k0;
    k1g = sys.grid.k1;
    k2g = sys.grid.k2;

    grid_conv_loss = k0g + k1g * Pgrid + k2g * (Pgrid.^2);
end

f = base + grid_conv_loss;

end