function idx = opf_index(N, E, use_grid)
%OPF_INDEX  Creates a consistent packing layout for decision vector x (OPF-2 only)

if nargin < 3
    use_grid = false;
end

k = 0;

idx.v    = (k+1):(k+N); k = k+N;
idx.PG   = (k+1):(k+N); k = k+N;
idx.PB   = (k+1):(k+N); k = k+N;
idx.Pinj = (k+1):(k+N); k = k+N;
idx.SOCn = (k+1):(k+N); k = k+N;

if use_grid
    idx.PgImp = k+1; k = k+1;
    idx.PgExp = k+1; k = k+1;
else
    idx.PgImp = [];
    idx.PgExp = [];
end

idx.Pij  = (k+1):(k+E); k = k+E;
idx.Pji  = (k+1):(k+E); k = k+E;
idx.lij  = (k+1):(k+E); k = k+E;

idx.Po    = (k+1):(k+N); k = k+N;
idx.Pconv = (k+1):(k+N); k = k+N;

idx.nx = k;
end
