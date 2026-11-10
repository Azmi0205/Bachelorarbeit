function [logsout, T] = readUserSpeedCSVlog(filename)
%READUSERSPEEDCSVLOG Read a CSV measurement and convert it to a
%logsout-style Simulink.SimulationData.Dataset.
%
%   LOGSOUT = READUSERSPEEDCSVLOG(FILENAME) reads a semicolon-separated
%   CSV file with decimal commas and returns a Simulink dataset compatible
%   with plotLoggedSignal1x2.
%
%   [LOGSOUT, T] = READUSERSPEEDCSVLOG(FILENAME) additionally returns the
%   imported and processed data as a MATLAB table.
%
%   Supported CSV layouts:
%
%       time;USER_CPU_Load;USER_SPEED_AVR;USER_SPEED_MEAS;USER_SPEED_REF;
%
%   or:
%
%       time;USER_CPU_Load;USER_SPEED_MEAS;USER_SPEED_REF;
%
%   The returned dataset contains:
%
%       USER_CPU_Load
%       USER_SPEED_MEAS
%       USER_SPEED_REF
%
%   Processing:
%
%       1. Invalid time samples are removed.
%       2. The time vector is shifted so that the first sample is at t = 0.
%       3. USER_SPEED_MEAS and USER_SPEED_REF are converted from rpm to
%          mechanical angular velocity in rad/s.

    if nargin < 1 || isempty(filename)
        error( ...
            'readUserSpeedCSVlog:missingInput', ...
            'Please provide a filename.');
    end

    if ~isfile(filename)
        error( ...
            'readUserSpeedCSVlog:fileNotFound', ...
            'File not found: %s', filename);
    end

    %% Configure import options

    opts = detectImportOptions( ...
        filename, ...
        'FileType', 'text', ...
        'Delimiter', ';', ...
        'DecimalSeparator', ',', ...
        'VariableNamingRule', 'preserve');

    % Some exports contain a trailing semicolon, which may create an
    % unnamed variable such as "Var5". Ignore such variables.
    validVarIdx = ~cellfun( ...
        @(v) isempty(strtrim(v)) || startsWith(strtrim(v), 'Var'), ...
        opts.VariableNames);

    opts.SelectedVariableNames = opts.VariableNames(validVarIdx);

    %% Read CSV file

    rawTable = readtable(filename, opts);

    % Remove leading and trailing whitespace from column names.
    rawTable.Properties.VariableNames = ...
        strtrim(rawTable.Properties.VariableNames);

    requiredCols = { ...
        'time', ...
        'USER_CPU_Load', ...
        'USER_SPEED_MEAS', ...
        'USER_SPEED_REF'};

    availableCols = rawTable.Properties.VariableNames;
    missingCols = setdiff(requiredCols, availableCols);

    if ~isempty(missingCols)
        error( ...
            'readUserSpeedCSVlog:missingColumns', ...
            'Missing expected column(s): %s', ...
            strjoin(missingCols, ', '));
    end

    % Select and order only the required columns.
    T = rawTable(:, requiredCols);

    %% Ensure that all columns are numeric

    for k = 1:numel(requiredCols)
        columnName = requiredCols{k};

        if ~isnumeric(T.(columnName))
            T.(columnName) = str2double( ...
                strrep(string(T.(columnName)), ',', '.'));
        end
    end

    %% Check imported data

    if isempty(T)
        error( ...
            'readUserSpeedCSVlog:emptyData', ...
            'The file contains no measurement samples: %s', filename);
    end

    % Remove rows containing invalid time values.
    invalidTime = ~isfinite(T.time);

    if any(invalidTime)
        warning( ...
            'readUserSpeedCSVlog:invalidTimeSamples', ...
            ['Removing %d row(s) with non-finite time values from ' ...
             'file "%s".'], ...
            nnz(invalidTime), filename);

        T(invalidTime, :) = [];
    end

    if isempty(T)
        error( ...
            'readUserSpeedCSVlog:noValidSamples', ...
            'No valid measurement samples remain in file: %s', filename);
    end

    %% Ensure column-vector format

    T.time            = T.time(:);
    T.USER_CPU_Load   = T.USER_CPU_Load(:);
    T.USER_SPEED_MEAS = T.USER_SPEED_MEAS(:);
    T.USER_SPEED_REF  = T.USER_SPEED_REF(:);

    %% Shift time so that the first sample is at t = 0

    initialTime = T.time(1);
    T.time = T.time - initialTime;

    % Avoid a very small numerical residual at the first sample.
    T.time(1) = 0;

    %% Validate adjusted time vector

    if any(diff(T.time) < 0)
        error( ...
            'readUserSpeedCSVlog:nonMonotonicTime', ...
            ['The time values in file "%s" are not monotonically ' ...
             'increasing.'], ...
            filename);
    end

    %% Convert motor speeds from rpm to rad/s

    rpm2radps = 2*pi/60;

    T.USER_SPEED_MEAS = T.USER_SPEED_MEAS * rpm2radps;
    T.USER_SPEED_REF  = T.USER_SPEED_REF  * rpm2radps;

    %% Create a Simulink logsout-compatible dataset

    logsout = Simulink.SimulationData.Dataset;

    signalNames = { ...
        'USER_CPU_Load', ...
        'USER_SPEED_MEAS', ...
        'USER_SPEED_REF'};

    for k = 1:numel(signalNames)
        signalName = signalNames{k};

        % Create the time-domain signal using the adjusted time vector.
        ts = timeseries( ...
            T.(signalName), ...
            T.time, ...
            'Name', signalName);

        % Wrap the timeseries in a Simulink signal object.
        signalElement = Simulink.SimulationData.Signal;
        signalElement.Name = signalName;
        signalElement.Values = ts;

        % Add the signal to the dataset.
        logsout = logsout.addElement(signalElement, signalName);
    end
end