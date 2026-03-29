function data = read_pv_and_load_csv(pvCsvFile, loadFile, selYear, selMonth, selDay, targetMinute, loadSheetName)
%READ_PV_AND_LOAD_CSV
% Reads:
%   1) Year, Month, Day, Hour, Minute, DNI from PV CSV
%   2) Total 24-hour load from load workbook range J7:J30
% Converts both DNI and load into dimensionless 24-hour profiles.
%
% Inputs:
%   pvCsvFile      - path to PV CSV
%   loadFile       - path to load workbook/file
%   selYear        - selected year
%   selMonth       - selected month
%   selDay         - selected day
%   targetMinute   - preferred minute value to filter (e.g. 0 or 30)
%                    if empty, function keeps one row per hour
%   loadSheetName  - sheet name to read the load profile from
%
% Output fields:
%   data.Year
%   data.Month
%   data.Day
%   data.Hour
%   data.Minute
%   data.DNI_Wm2
%   data.PV_profile
%   data.Load_profile
%   data.Load_kWh_raw
%   data.DateTime

    if nargin == 0
        pvCsvFile     = '1002919_27.05_18.02_tmy-2022.csv';
        loadFile      = '2 - Microgrid_Load_Profile_Explorer.xlsx';
        selYear       = 2022;
        selMonth      = 8;
        selDay        = 1;
        targetMinute  = 30;
        loadSheetName = 'Test Case 1';
    end

    if nargin < 6
        targetMinute = [];
    end

    if nargin < 7 || isempty(loadSheetName)
        loadSheetName = 'Test Case 1';
    end

    if ~isfile(pvCsvFile)
        error('PV file not found: %s', pvCsvFile);
    end

    if nargin >= 2 && endsWith(loadFile, '.csv', 'IgnoreCase', true)
        [p, n] = fileparts(loadFile);
        loadXlsxCandidate = fullfile(p, [n '.xlsx']);
        if isfile(loadXlsxCandidate)
            loadFile = loadXlsxCandidate;
        end
    end

    if ~isfile(loadFile)
        error('Load file not found: %s', loadFile);
    end

    %% -------------------- Read PV CSV --------------------
    opts = detectImportOptions(pvCsvFile);
    opts.VariableNamesLine = 3;       % row 3 has actual headers
    opts.DataLines         = [4 Inf]; % numeric data starts on row 4
    opts.VariableNamingRule = 'preserve';
    T = readtable(pvCsvFile, opts);

    req = {'Year','Month','Day','Hour','Minute','DNI'};
    for k = 1:numel(req)
        if ~ismember(req{k}, T.Properties.VariableNames)
            error('PV CSV is missing required column: %s', req{k});
        end
    end

    T = T(:, req);

    % filter selected date
    mask = (T.Year == selYear) & ...
           (T.Month == selMonth) & ...
           (T.Day == selDay);

    Tday = T(mask, :);

    if isempty(Tday)
        error('No PV data found for %04d-%02d-%02d.', selYear, selMonth, selDay);
    end

    Tday = sortrows(Tday, {'Hour','Minute'});

    % If minute is specified, keep only that minute
    if ~isempty(targetMinute)
        Tday = Tday(Tday.Minute == targetMinute, :);
    end

    % If still multiple rows per hour, keep first one per hour
    [~, ia] = unique(Tday.Hour, 'stable');
    T24 = Tday(ia, :);

    if height(T24) ~= 24
        warning('Selected PV day returned %d rows instead of 24.', height(T24));
    end

    %% -------------------- Read Load Workbook --------------------
    % Total household + commercial load is expected in <loadSheetName>!J7:J30.
    loadRange = 'J7:J30';
    loadSheetCandidates = {loadSheetName};

    fprintf('Reading load data from sheet: %s\n', loadSheetName);

    [load24, loadSheetUsed] = read_load_range_first_valid(loadFile, loadSheetCandidates, loadRange);

    fprintf('Successfully read load data from sheet: %s\n', loadSheetUsed);

    if isempty(load24)
        error(['Could not read numeric load data from range %s in file %s. ' ...
               'Expected sheet: %s.'], loadRange, loadFile, loadSheetName);
    end

    if numel(load24) ~= 24
        error('Load range %s in sheet %s did not return 24 values.', loadRange, loadSheetUsed);
    end

    load24 = load24(:);

    %% -------------------- Build dimensionless profiles --------------------
    dni = T24.DNI;
    dni(dni < 0) = 0;

    if max(dni) == 0
        pv_profile = zeros(size(dni));
    else
        pv_profile = dni ./ max(dni);
    end

    if max(load24) == 0
        load_profile = zeros(size(load24));
    else
        load_profile = load24 ./ max(load24);
    end

    %% -------------------- Build output --------------------
    data.Year         = T24.Year;
    data.Month        = T24.Month;
    data.Day          = T24.Day;
    data.Hour         = T24.Hour;
    data.Minute       = T24.Minute;
    data.DNI_Wm2      = dni;
    data.PV_profile   = pv_profile;
    data.Load_profile = load_profile;
    data.Load_kWh_raw = load24;

    data.DateTime = datetime(T24.Year, T24.Month, T24.Day, ...
                             T24.Hour, T24.Minute, 0);

    %% -------------------- Check lengths --------------------
    if numel(data.PV_profile) ~= numel(data.Load_profile)
        warning('PV profile length (%d) and load profile length (%d) do not match.', ...
                numel(data.PV_profile), numel(data.Load_profile));
    end
end

function [vals, sheetUsed] = read_load_range_first_valid(loadFile, sheetCandidates, loadRange)
    vals = [];
    sheetUsed = '';

    for k = 1:numel(sheetCandidates)
        sheetCandidate = sheetCandidates{k};

        [ok, v] = try_read_load_matrix(loadFile, sheetCandidate, loadRange, false);
        if ~(ok && is_valid_load_vector(v))
            % Retry with Excel engine to evaluate formulas when needed.
            [ok, v] = try_read_load_matrix(loadFile, sheetCandidate, loadRange, true);
        end

        if ok && is_valid_load_vector(v)
            vals = v(:);
            if isnumeric(sheetCandidate)
                sheetUsed = sprintf('#%d', sheetCandidate);
            else
                sheetUsed = char(sheetCandidate);
            end
            return;
        end
    end
end

function [ok, v] = try_read_load_matrix(loadFile, sheetCandidate, loadRange, useExcel)
    ok = false;
    v = [];
    try
        if useExcel
            v = readmatrix(loadFile, 'Sheet', sheetCandidate, 'Range', loadRange, 'UseExcel', true);
        else
            v = readmatrix(loadFile, 'Sheet', sheetCandidate, 'Range', loadRange);
        end
        ok = true;
    catch
        ok = false;
        v = [];
    end
end

function tf = is_valid_load_vector(v)
    tf = isnumeric(v) && numel(v) == 24 && all(isfinite(v(:)));
end