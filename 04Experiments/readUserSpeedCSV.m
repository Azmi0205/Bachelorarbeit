
function T = readUserSpeedCSV(filename)
%READUSERSPEEDCSV Read semicolon-separated CSV with decimal commas and
%   return only time, USER_CPU_Load, USER_SPEED_MEAS, USER_SPEED_REF.
%
%   T = READUSERSPEEDCSV(FILENAME) reads the CSV file FILENAME, which may
%   contain either of these column layouts (semicolon-delimited, using
%   commas as decimal separators, with an optional trailing delimiter):
%
%       time;USER_CPU_Load;USER_SPEED_AVR;USER_SPEED_MEAS;USER_SPEED_REF;
%       time;USER_CPU_Load;USER_SPEED_MEAS;USER_SPEED_REF;
%
%   The function auto-detects which layout is present (based on the
%   header row) and returns a table T with exactly these columns:
%
%       time, USER_CPU_Load, USER_SPEED_MEAS, USER_SPEED_REF
%
%   USER_SPEED_AVR, if present, is discarded.
%
%   USER_SPEED_MEAS and USER_SPEED_REF are assumed to be logged in rpm
%   and are converted to mechanical angular velocity in rad/s using
%   omega = n * (2*pi/60).
%
%   Example:
%       T = readUserSpeedCSV('log1.csv');
%       plot(T.time, T.USER_SPEED_MEAS, T.time, T.USER_SPEED_REF);
    if nargin < 1 || isempty(filename)
        error('readUserSpeedCSV:missingInput', 'Please provide a filename.');
    end
    if ~isfile(filename)
        error('readUserSpeedCSV:fileNotFound', 'File not found: %s', filename);
    end
    opts = detectImportOptions(filename, 'FileType', 'text', ...
        'Delimiter', ';', 'DecimalSeparator', ',', ...
        'VariableNamingRule', 'preserve');
    % Some exports leave a trailing ';' which creates an extra empty
    % column at the end. Drop any variables that are unnamed/empty.
    validVarIdx = ~cellfun(@(v) isempty(strtrim(v)) || startsWith(v, 'Var'), ...
        opts.VariableNames);
    opts.SelectedVariableNames = opts.VariableNames(validVarIdx);
    rawTable = readtable(filename, opts);
    % Normalize variable names (strip whitespace) for robust matching.
    varNames = strtrim(rawTable.Properties.VariableNames);
    rawTable.Properties.VariableNames = varNames;
    requiredCols = {'time', 'USER_CPU_Load', 'USER_SPEED_MEAS', 'USER_SPEED_REF'};
    missingCols = setdiff(requiredCols, varNames);
    if ~isempty(missingCols)
        error('readUserSpeedCSV:missingColumns', ...
            'Missing expected column(s): %s', strjoin(missingCols, ', '));
    end
    % Select and order only the required columns (USER_SPEED_AVR, if
    % present, is simply not selected here).
    T = rawTable(:, requiredCols);
    % Ensure numeric types (in case DecimalSeparator detection missed
    % anything and values were imported as text/cell).
    for k = 1:numel(requiredCols)
        col = requiredCols{k};
        if ~isnumeric(T.(col))
            T.(col) = str2double(strrep(string(T.(col)), ',', '.'));
        end
    end
    % Convert mechanical speeds from rpm to rad/s.
    rpm2radps = 2*pi/60;
    T.USER_SPEED_MEAS = T.USER_SPEED_MEAS * rpm2radps;
    T.USER_SPEED_REF  = T.USER_SPEED_REF  * rpm2radps;
end

