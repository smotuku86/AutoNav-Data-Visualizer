classdef DataVisualizer < handle
    properties
        UIFigure
        ToolbarPanel
        HTMLComponent

        % Toolbar controls
        LoadButton
        PlotButton
        ClearButton
        UnitsToggle
        LabelsToggle
        ExportButton
        HelpButton

        % Data
        LogData
        LogData2            % second CSV data source (dual-CSV mode)
        FieldList = {}      % cell array of structs: {topic, field, displayName, unit, csvIndex}
        Assignments = {}    % cell array of structs from HTML
        UnitMap
        DisplayNameMap
        CsvNames = {}       % cell array of loaded CSV filenames

        % State
        CurrentLayout = [1 1]
        ShowUnits = true
        ShowLabels = true
        PlotFigure = []     % handle to the plot figure window
        WarningBar         % optional warning banner label
        TransformOutputs = struct()  % keyed by subplot index: stores computed FFT/filter results
        RotInfo = []                % rotation info from transform_imu (pitch/roll angles)
    end

    methods
        % ==============================================================
        % Constructor
        % ==============================================================
        function app = DataVisualizer()
            projRoot = fileparts(fileparts(mfilename('fullpath')));
            addpath(projRoot);
            addpath(genpath(fullfile(projRoot, 'HelperFunctions')));

            app.UnitMap = get_unit_map();
            app.DisplayNameMap = buildDisplayNameMap();
            createComponents(app);
        end

        % ==============================================================
        % Create UI Components
        % ==============================================================
        function createComponents(app)
            app.UIFigure = uifigure('Name', 'Data Visualizer', ...
                'Position', [50 50 1100 700], ...
                'AutoResizeChildren', 'off', ...
                'SizeChangedFcn', @(~,~) onResize(app));

            figW = app.UIFigure.Position(3);
            figH = app.UIFigure.Position(4);

            % --- Toolbar panel (top 50px) ---
            app.ToolbarPanel = uipanel(app.UIFigure, ...
                'BorderType', 'line', ...
                'Position', [0 figH-50 figW 50]);

            xPos = 10;

            app.LoadButton = uidropdown(app.ToolbarPanel, ...
                'Items', {'Load', 'Load 1 CSV', 'Load 2 CSV'}, ...
                'Value', 'Load', ...
                'Position', [xPos 10 100 30], ...
                'ValueChangedFcn', @(src,~) LoadDropdownChanged(app, src));
            xPos = xPos + 110;

            app.PlotButton = uibutton(app.ToolbarPanel, 'push', ...
                'Text', 'Plot', ...
                'Position', [xPos 10 60 30], ...
                'ButtonPushedFcn', @(~,~) PlotButtonPushed(app));
            xPos = xPos + 70;

            app.ClearButton = uibutton(app.ToolbarPanel, 'push', ...
                'Text', 'Clear', ...
                'Position', [xPos 10 60 30], ...
                'ButtonPushedFcn', @(~,~) ClearButtonPushed(app));
            xPos = xPos + 70;

            app.UnitsToggle = uicheckbox(app.ToolbarPanel, ...
                'Text', 'Units', ...
                'Value', true, ...
                'Position', [xPos 14 60 22], ...
                'ValueChangedFcn', @(src,~) UnitsToggled(app, src));
            xPos = xPos + 65;

            app.LabelsToggle = uicheckbox(app.ToolbarPanel, ...
                'Text', 'Labels', ...
                'Value', true, ...
                'Position', [xPos 14 65 22], ...
                'ValueChangedFcn', @(src,~) LabelsToggled(app, src));
            xPos = xPos + 70;

            app.ExportButton = uibutton(app.ToolbarPanel, 'push', ...
                'Text', 'Export Fig', ...
                'Position', [xPos 10 80 30], ...
                'ButtonPushedFcn', @(~,~) ExportButtonPushed(app));

            % Help button pinned to right side of toolbar
            app.HelpButton = uibutton(app.ToolbarPanel, 'push', ...
                'Text', '? Help', ...
                'Position', [figW-80 10 70 30], ...
                'ButtonPushedFcn', @(~,~) HelpButtonPushed(app));

            % --- HTML Component (fills remaining space) ---
            htmlDir = fullfile(fileparts(mfilename('fullpath')), 'html');
            htmlFile = fullfile(htmlDir, 'dragdrop.html');

            % --- Warning bar (shown if Signal Processing Toolbox is missing) ---
            bannerH = 0;
            if ~license('test', 'Signal_Toolbox')
                bannerH = 26;
                app.WarningBar = uilabel(app.UIFigure, ...
                    'Text', ['  \x26A0 Signal Processing Toolbox not installed — ' ...
                             'filtered velocity unavailable, Butterworth filters ' ...
                             'replaced by FFT-based fallback.  ' ...
                             'Install via Home > Add-Ons > Get Add-Ons.'], ...
                    'Position', [0 figH-50-bannerH figW bannerH], ...
                    'BackgroundColor', [1 0.93 0.6], ...
                    'FontSize', 12, ...
                    'FontColor', [0.4 0.3 0]);
            end

            app.HTMLComponent = uihtml(app.UIFigure, ...
                'HTMLSource', htmlFile, ...
                'Position', [0 0 figW figH-50-bannerH], ...
                'DataChangedFcn', @(~,~) onHTMLDataChanged(app));
        end

        % ==============================================================
        % Resize handler
        % ==============================================================
        function onResize(app)
            if isempty(app.UIFigure) || ~isvalid(app.UIFigure), return; end
            figW = app.UIFigure.Position(3);
            figH = app.UIFigure.Position(4);
            app.ToolbarPanel.Position = [0 figH-50 figW 50];
            app.HelpButton.Position = [figW-80 10 70 30];

            bannerH = 0;
            if ~isempty(app.WarningBar) && isvalid(app.WarningBar)
                bannerH = 26;
                app.WarningBar.Position = [0 figH-50-bannerH figW bannerH];
            end
            app.HTMLComponent.Position = [0 0 figW figH-50-bannerH];
        end

        % ==============================================================
        % Load dropdown handler
        % ==============================================================
        function LoadDropdownChanged(app, src)
            val = src.Value;
            src.Value = 'Load';  % Reset dropdown immediately
            if strcmp(val, 'Load 1 CSV')
                LoadOneCsv(app);
            elseif strcmp(val, 'Load 2 CSV')
                LoadTwoCsv(app);
            end
        end

        % ==============================================================
        % Load single CSV
        % ==============================================================
        function LoadOneCsv(app)
            projRoot = fileparts(fileparts(mfilename('fullpath')));
            startDir = fullfile(projRoot, 'TestingData');

            % Temporarily hide uifigure so the classic file dialog is not behind it
            app.UIFigure.Visible = 'off';
            [file, path] = uigetfile( ...
                fullfile(startDir, '*.csv;*.txt;*.log'), 'Select Log File');
            app.UIFigure.Visible = 'on';

            if isequal(file, 0), return; end
            fullpath = fullfile(path, file);

            try
                app.LogData = parse_log(fullpath);
                app.LogData = clean_log(app.LogData);
            catch ME
                uialert(app.UIFigure, ...
                    sprintf('Error parsing log:\n%s', ME.message), 'Parse Error');
                return;
            end

            % Clear second CSV
            app.LogData2 = [];
            app.CsvNames = {file};

            app.UIFigure.Name = ['Data Visualizer - ' file];

            computeDerivedFields(app, app.LogData, 1);

            app.FieldList = buildFieldList(app);

            layout = parseLayout(app);
            app.HTMLComponent.Data = struct( ...
                'type', 'fieldsUpdate', ...
                'fields', {app.FieldList}, ...
                'layout', layout, ...
                'csvNames', {app.CsvNames});

            % Bring main app window back to front after file dialog
            figure(app.UIFigure);
        end

        % ==============================================================
        % Load two CSVs
        % ==============================================================
        function LoadTwoCsv(app)
            projRoot = fileparts(fileparts(mfilename('fullpath')));
            startDir = fullfile(projRoot, 'TestingData');

            % Temporarily hide uifigure so the classic file dialog is not behind it
            app.UIFigure.Visible = 'off';
            [files, path] = uigetfile( ...
                fullfile(startDir, '*.csv;*.txt;*.log'), 'Select Two Log Files', ...
                'MultiSelect', 'on');
            app.UIFigure.Visible = 'on';

            if isequal(files, 0), return; end

            % Handle single file selection
            if ischar(files)
                uialert(app.UIFigure, ...
                    'Please select exactly two files.', 'Selection Error');
                return;
            end
            if numel(files) ~= 2
                uialert(app.UIFigure, ...
                    'Please select exactly two files.', 'Selection Error');
                return;
            end

            % Parse first CSV
            try
                app.LogData = parse_log(fullfile(path, files{1}));
                app.LogData = clean_log(app.LogData);
            catch ME
                uialert(app.UIFigure, ...
                    sprintf('Error parsing CSV 1:\n%s', ME.message), 'Parse Error');
                return;
            end

            % Parse second CSV
            try
                app.LogData2 = parse_log(fullfile(path, files{2}));
                app.LogData2 = clean_log(app.LogData2);
            catch ME
                uialert(app.UIFigure, ...
                    sprintf('Error parsing CSV 2:\n%s', ME.message), 'Parse Error');
                return;
            end

            app.CsvNames = {files{1}, files{2}};

            app.UIFigure.Name = ['Data Visualizer - ' files{1} ' + ' files{2}];

            computeDerivedFields(app, app.LogData, 1);
            computeDerivedFields(app, app.LogData2, 2);

            app.FieldList = buildFieldList(app);

            layout = parseLayout(app);
            app.HTMLComponent.Data = struct( ...
                'type', 'fieldsUpdate', ...
                'fields', {app.FieldList}, ...
                'layout', layout, ...
                'csvNames', {app.CsvNames});

            % Bring main app window back to front after file dialog
            figure(app.UIFigure);
        end

        % ==============================================================
        % Compute derived fields (velocity, IMU) for a data source
        % ==============================================================
        function computeDerivedFields(app, logData, csvIdx)
            if isfield(logData, 'odom')
                raw = computeOdomVelocity(logData.odom);
                logData.odom_velocity.time = raw.time;
                logData.odom_velocity.vx   = raw.x;
                logData.odom_velocity.vy   = raw.y;
                logData.odom_velocity.mag  = raw.mag;

                try
                    filt = computeOdomVelocity_SG(logData.odom);
                    logData.odom_velocity_filtered.time = filt.time;
                    logData.odom_velocity_filtered.vx   = filt.x;
                    logData.odom_velocity_filtered.vy   = filt.y;
                    logData.odom_velocity_filtered.mag  = filt.mag;
                catch ME
                    warning('DataVisualizer:FilteredVelocity', ...
                        ['Filtered velocity unavailable: %s\n' ...
                         'Install Signal Processing Toolbox to enable this feature.'], ...
                        ME.message);
                end
            end

            if isfield(logData, 'zed_zed_node_imu_data')
                [corrected, rotInfo] = transform_imu(logData.zed_zed_node_imu_data);
                logData.imu_corrected = corrected;
                if csvIdx == 1
                    app.RotInfo = rotInfo;
                end

                imuData = logData.zed_zed_node_imu_data;
                if isfield(imuData,'accel_x') && isfield(imuData,'accel_y') && isfield(imuData,'accel_z')
                    logData.zed_zed_node_imu_data.accel_mag = sqrt( ...
                        imuData.accel_x.^2 + imuData.accel_y.^2 + imuData.accel_z.^2);
                end
                if isfield(imuData,'gyro_x') && isfield(imuData,'gyro_y') && isfield(imuData,'gyro_z')
                    logData.zed_zed_node_imu_data.gyro_mag = sqrt( ...
                        imuData.gyro_x.^2 + imuData.gyro_y.^2 + imuData.gyro_z.^2);
                end
            end

            % Write back to the correct property (structs are value types)
            if csvIdx == 1
                app.LogData = logData;
            else
                app.LogData2 = logData;
            end
        end

        % ==============================================================
        % Build field list from LogData struct
        % ==============================================================
        function fields = buildFieldList(app)
            % Build fields for CSV 1 (with special tags)
            fields = buildFieldsForSource(app, app.LogData, 1, true);

            % Build fields for CSV 2 if loaded (no special tags)
            if ~isempty(app.LogData2)
                fields2 = buildFieldsForSource(app, app.LogData2, 2, true);
                fields = [fields, fields2];
            end

            % Append transform entries (shared, not CSV-specific)
            fields{end+1} = struct( ...
                'topic', '__transform__', 'field', '__fft__', ...
                'displayName', 'FFT', 'unit', '', 'csvIndex', 0);
            fields{end+1} = struct( ...
                'topic', '__transform__', 'field', '__filter__', ...
                'displayName', 'Filter', 'unit', '', 'csvIndex', 0);
            fields{end+1} = struct( ...
                'topic', '__transform__', 'field', '__bode_single__', ...
                'displayName', 'Bode Plot', 'unit', '', 'csvIndex', 0);
            fields{end+1} = struct( ...
                'topic', '__transform__', 'field', '__bode__', ...
                'displayName', 'Estimate TF', 'unit', '', 'csvIndex', 0);
            fields{end+1} = struct( ...
                'topic', '__transform__', 'field', '__average__', ...
                'displayName', 'Average', 'unit', '', 'csvIndex', 0);
        end

        % ==============================================================
        % Build field entries for a single data source
        % ==============================================================
        function fields = buildFieldsForSource(app, logData, csvIdx, includeSpecials)
            fields = {};
            topics = fieldnames(logData);
            for i = 1:numel(topics)
                topic = topics{i};

                if includeSpecials
                    % GPS: emit a special plot tag
                    if strcmp(topic, 'gps_fix')
                        fields{end+1} = struct('topic', 'gps_fix', 'field', '__gps__', ...
                            'displayName', 'GPS Plot Special', 'unit', '', 'csvIndex', csvIdx); %#ok<AGROW>
                    end

                    % Electrical: emit a special plot tag (only once)
                    if startsWith(topic, 'electrical_') && ~any(cellfun(@(f) strcmp(f.field, '__electrical__'), fields))
                        fields{end+1} = struct('topic', 'electrical', 'field', '__electrical__', ...
                            'displayName', 'Electrical Plot Special', 'unit', '', 'csvIndex', csvIdx); %#ok<AGROW>
                    end

                    % IMU: emit special plot tags
                    if strcmp(topic, 'zed_zed_node_imu_data')
                        fields{end+1} = struct('topic', 'zed_zed_node_imu_data', 'field', '__imu__', ...
                            'displayName', 'IMU Plot Special', 'unit', '', 'csvIndex', csvIdx); %#ok<AGROW>
                        fields{end+1} = struct('topic', 'imu_corrected', 'field', '__imu_orient_correct__', ...
                            'displayName', 'IMU Orient Correct Plot Special', 'unit', '', 'csvIndex', csvIdx); %#ok<AGROW>
                    end

                    % CMD VEL: emit a special plot tag
                    if strcmp(topic, 'cmd_vel')
                        fields{end+1} = struct('topic', 'cmd_vel', 'field', '__cmd_vel__', ...
                            'displayName', 'CMD VEL Plot Special', 'unit', '', 'csvIndex', csvIdx); %#ok<AGROW>
                    end

                    % Odom: emit special plot tags
                    if strcmp(topic, 'odom')
                        if isfield(logData, 'gps_fix')
                            fields{end+1} = struct('topic', 'odom', 'field', '__odom_gps__', ...
                                'displayName', 'Odom GPS Aligned Special', 'unit', '', 'csvIndex', csvIdx); %#ok<AGROW>
                        end
                        fields{end+1} = struct('topic', 'odom', 'field', '__odom__', ...
                            'displayName', 'Odometry Plot Special', 'unit', '', 'csvIndex', csvIdx); %#ok<AGROW>
                    end
                end

                topicData = logData.(topic);
                fnames = fieldnames(topicData);
                for j = 1:numel(fnames)
                    fname = fnames{j};
                    unit = lookupUnit(app, topic, fname);
                    displayName = lookupDisplayName(app, topic, fname);
                    fields{end+1} = struct( ...
                        'topic', topic, 'field', fname, ...
                        'displayName', displayName, 'unit', unit, ...
                        'csvIndex', csvIdx); %#ok<AGROW>
                end
            end
        end

        % ==============================================================
        % Display name lookup
        % ==============================================================
        function name = lookupDisplayName(app, topic, field)
            key = [topic '.' field];
            if app.DisplayNameMap.isKey(key)
                name = app.DisplayNameMap(key);
            elseif strcmp(field, 'time')
                name = 'Time';
            else
                name = prettyFieldName(field);
            end
        end

        % ==============================================================
        % Unit lookup — defaults to '-' so every field has a unit
        % ==============================================================
        function unit = lookupUnit(app, topic, field)
            key = [topic '.' field];
            if app.UnitMap.isKey(key)
                unit = app.UnitMap(key);
            elseif strcmp(field, 'time')
                unit = 's';
            else
                unit = '-';
            end
        end

        % ==============================================================
        % Parse layout — returns stored [rows, cols]
        % ==============================================================
        function layout = parseLayout(app)
            layout = app.CurrentLayout;
        end

        % ==============================================================
        % Receive assignments from HTML
        % ==============================================================
        function onHTMLDataChanged(app)
            data = app.HTMLComponent.Data;
            if isempty(data), return; end
            if ~isstruct(data) || ~isfield(data, 'type'), return; end

            if strcmp(data.type, 'assignmentsUpdate')
                app.Assignments = data.subplots;
            elseif strcmp(data.type, 'layoutChange')
                app.CurrentLayout = [data.layout(1), data.layout(2)];
            end
        end

        % ==============================================================
        % Plot button
        % ==============================================================
        function PlotButtonPushed(app)
            if isempty(app.LogData)
                uialert(app.UIFigure, 'Load a log file first.', 'No Data');
                return;
            end
            if isempty(app.Assignments)
                uialert(app.UIFigure, ...
                    'Drag fields into subplot zones first.', 'No Assignments');
                return;
            end

            generatePlots(app);
        end

        % ==============================================================
        % Generate plots in a separate figure
        % ==============================================================
        function generatePlots(app)
            layout = parseLayout(app);
            rows = layout(1);
            cols = layout(2);

            % Create or reuse figure — size to 80% of screen
            if isempty(app.PlotFigure) || ~isvalid(app.PlotFigure)
                screenSz = get(0, 'ScreenSize');
                figW = round(screenSz(3) * 0.8);
                figH = round(screenSz(4) * 0.8);
                figX = round((screenSz(3) - figW) / 2);
                figY = round((screenSz(4) - figH) / 2);
                app.PlotFigure = figure('Name', 'Data Visualizer - Plots', ...
                    'NumberTitle', 'off', ...
                    'Position', [figX figY figW figH]);
            else
                clf(app.PlotFigure);
            end

            % Clear previous transform outputs
            app.TransformOutputs = struct();

            numSubplots = numel(app.Assignments);

            % --- Dependency resolution: topological sort ---
            % Build adjacency: subplot j depends on subplot i if j uses output from i
            deps = cell(1, numSubplots);  % deps{j} = list of indices j depends on
            for j = 1:numSubplots
                deps{j} = [];
                spj = app.Assignments(j);
                if iscell(spj), spj = spj{1}; end
                allTags = {};
                if isfield(spj, 'xTags'), allTags = [allTags, tagList(spj.xTags)]; end
                if isfield(spj, 'yTags'), allTags = [allTags, tagList(spj.yTags)]; end
                if isfield(spj, 'inputTags'), allTags = [allTags, tagList(spj.inputTags)]; end
                for ti = 1:numel(allTags)
                    tg = allTags{ti};
                    if isfield(tg, 'sourceSubplot') && ~isempty(tg.sourceSubplot)
                        srcIdx = double(tg.sourceSubplot);
                        if srcIdx >= 1 && srcIdx <= numSubplots && srcIdx ~= j
                            deps{j}(end+1) = srcIdx;
                        end
                    end
                end
                deps{j} = unique(deps{j});
            end

            % Kahn's algorithm for topological sort
            inDeg = zeros(1, numSubplots);
            for j = 1:numSubplots
                inDeg(j) = numel(deps{j});
            end
            queue = find(inDeg == 0);
            order = [];
            while ~isempty(queue)
                k = queue(1);
                queue(1) = [];
                order(end+1) = k; %#ok<AGROW>
                for j = 1:numSubplots
                    if any(deps{j} == k)
                        deps{j}(deps{j} == k) = [];
                        inDeg(j) = inDeg(j) - 1;
                        if inDeg(j) == 0
                            queue(end+1) = j; %#ok<AGROW>
                        end
                    end
                end
            end
            % Append any remaining (cycle or disconnected)
            for j = 1:numSubplots
                if ~any(order == j)
                    order(end+1) = j; %#ok<AGROW>
                end
            end

            % --- Process subplots in dependency order ---
            for oi = 1:numel(order)
                k = order(oi);
                sp = app.Assignments(k);
                if iscell(sp)
                    sp = sp{1};
                end

                xTags = sp.xTags;
                yTags = sp.yTags;

                % Skip empty subplots
                if isempty(yTags) && isempty(xTags)
                    continue;
                end

                % Check for special plot tags — resolve csvIndex for data source
                spTag = findSpecialTag(xTags, yTags, '__gps__');
                if ~isempty(spTag)
                    spData = getLogDataForCsv(app, spTag);
                    if isfield(spData, 'gps_fix')
                        spLabels = struct('title', '', 'xLabel', '', 'yLabel', '', 'zLabel', '');
                        if isfield(sp, 'title'),  spLabels.title  = sp.title;  end
                        if isfield(sp, 'xLabel'), spLabels.xLabel = sp.xLabel; end
                        if isfield(sp, 'yLabel'), spLabels.yLabel = sp.yLabel; end
                        if isfield(sp, 'zLabel'), spLabels.zLabel = sp.zLabel; end
                        plotGPSInSubplot(app, spData, rows, cols, k, spLabels);
                    end
                    continue;
                end

                spTag = findSpecialTag(xTags, yTags, '__odom__');
                if ~isempty(spTag)
                    spData = getLogDataForCsv(app, spTag);
                    if isfield(spData, 'odom')
                        plotOdomInSubplot(app, spData, rows, cols, k);
                    end
                    continue;
                end

                spTag = findSpecialTag(xTags, yTags, '__odom_gps__');
                if ~isempty(spTag)
                    spData = getLogDataForCsv(app, spTag);
                    if isfield(spData, 'odom') && isfield(spData, 'gps_fix')
                        spLabels = struct('title', '', 'xLabel', '', 'yLabel', '');
                        if isfield(sp, 'title'),  spLabels.title  = sp.title;  end
                        if isfield(sp, 'xLabel'), spLabels.xLabel = sp.xLabel; end
                        if isfield(sp, 'yLabel'), spLabels.yLabel = sp.yLabel; end
                        plotOdomGPSInSubplot(app, spData, rows, cols, k, spLabels);
                    end
                    continue;
                end

                spTag = findSpecialTag(xTags, yTags, '__electrical__');
                if ~isempty(spTag)
                    spData = getLogDataForCsv(app, spTag);
                    spLabels = struct('title', '', 'xLabel', '', 'yLabel', '', 'zLabel', '');
                    if isfield(sp, 'title'),  spLabels.title  = sp.title;  end
                    if isfield(sp, 'xLabel'), spLabels.xLabel = sp.xLabel; end
                    if isfield(sp, 'yLabel'), spLabels.yLabel = sp.yLabel; end
                    if isfield(sp, 'zLabel'), spLabels.zLabel = sp.zLabel; end
                    plotElectricalInSubplot(app, spData, rows, cols, k, spLabels);
                    continue;
                end

                spTag = findSpecialTag(xTags, yTags, '__imu__');
                if ~isempty(spTag)
                    spData = getLogDataForCsv(app, spTag);
                    if isfield(spData, 'zed_zed_node_imu_data')
                        spLabels = struct('title', '', 'xLabel', '', 'yLabel', '', 'zLabel', '');
                        if isfield(sp, 'title'),  spLabels.title  = sp.title;  end
                        if isfield(sp, 'xLabel'), spLabels.xLabel = sp.xLabel; end
                        if isfield(sp, 'yLabel'), spLabels.yLabel = sp.yLabel; end
                        if isfield(sp, 'zLabel'), spLabels.zLabel = sp.zLabel; end
                        showGroups = [true true true];
                        if isfield(sp,'showAccel')  && ~isempty(sp.showAccel),  showGroups(1) = logical(sp.showAccel);  end
                        if isfield(sp,'showGyro')   && ~isempty(sp.showGyro),   showGroups(2) = logical(sp.showGyro);   end
                        if isfield(sp,'showOrient') && ~isempty(sp.showOrient),  showGroups(3) = logical(sp.showOrient); end
                        plotIMUInSubplot(app, spData, rows, cols, k, spLabels, showGroups);
                    end
                    continue;
                end

                spTag = findSpecialTag(xTags, yTags, '__imu_orient_correct__');
                if ~isempty(spTag)
                    spData = getLogDataForCsv(app, spTag);
                    if isfield(spData, 'imu_corrected')
                        spLabels = struct('title', '', 'xLabel', '', 'yLabel', '', 'zLabel', '');
                        if isfield(sp, 'title'),  spLabels.title  = sp.title;  end
                        if isfield(sp, 'xLabel'), spLabels.xLabel = sp.xLabel; end
                        if isfield(sp, 'yLabel'), spLabels.yLabel = sp.yLabel; end
                        if isfield(sp, 'zLabel'), spLabels.zLabel = sp.zLabel; end
                        showGroups = [true true true];
                        if isfield(sp,'showAccel')  && ~isempty(sp.showAccel),  showGroups(1) = logical(sp.showAccel);  end
                        if isfield(sp,'showGyro')   && ~isempty(sp.showGyro),   showGroups(2) = logical(sp.showGyro);   end
                        if isfield(sp,'showOrient') && ~isempty(sp.showOrient),  showGroups(3) = logical(sp.showOrient); end
                        plotIMUTransformInSubplot(app, spData, rows, cols, k, spLabels, showGroups);
                    end
                    continue;
                end

                spTag = findSpecialTag(xTags, yTags, '__cmd_vel__');
                if ~isempty(spTag)
                    spData = getLogDataForCsv(app, spTag);
                    if isfield(spData, 'cmd_vel')
                        spLabels = struct('title', '', 'xLabel', '', 'yLabel', '');
                        if isfield(sp, 'title'),  spLabels.title  = sp.title;  end
                        if isfield(sp, 'xLabel'), spLabels.xLabel = sp.xLabel; end
                        if isfield(sp, 'yLabel'), spLabels.yLabel = sp.yLabel; end
                        plotCmdVelInSubplot(app, spData, rows, cols, k, spLabels);
                    end
                    continue;
                end

                % --- Bode Plot (single signal) ---
                if hasSpecialTag(xTags, yTags, '__bode_single__')
                    spLabels = struct('title', '', 'xLabel', '', 'yLabel', '');
                    if isfield(sp, 'title'),  spLabels.title  = sp.title;  end
                    if isfield(sp, 'xLabel'), spLabels.xLabel = sp.xLabel; end
                    if isfield(sp, 'yLabel'), spLabels.yLabel = sp.yLabel; end
                    ax = subplot(rows, cols, k, 'Parent', app.PlotFigure);
                    plotBodeSingleInSubplot(app, ax, xTags, spLabels, k);
                    continue;
                end

                % --- Estimate Transfer Function (two inputs) ---
                if hasSpecialTag(xTags, yTags, '__bode__')
                    spLabels = struct('title', '', 'xLabel', '', 'yLabel', '');
                    if isfield(sp, 'title'),  spLabels.title  = sp.title;  end
                    if isfield(sp, 'xLabel'), spLabels.xLabel = sp.xLabel; end
                    if isfield(sp, 'yLabel'), spLabels.yLabel = sp.yLabel; end
                    inputTags = {};
                    if isfield(sp, 'inputTags')
                        inputTags = sp.inputTags;
                    end
                    ax = subplot(rows, cols, k, 'Parent', app.PlotFigure);
                    plotBodeInSubplot(app, ax, xTags, inputTags, spLabels);
                    continue;
                end

                % --- FFT transform ---
                if hasSpecialTag(xTags, yTags, '__fft__')
                    spLabels = struct('title', '', 'xLabel', '', 'yLabel', '');
                    if isfield(sp, 'title'),  spLabels.title  = sp.title;  end
                    if isfield(sp, 'xLabel'), spLabels.xLabel = sp.xLabel; end
                    if isfield(sp, 'yLabel'), spLabels.yLabel = sp.yLabel; end
                    ax = subplot(rows, cols, k, 'Parent', app.PlotFigure);
                    plotFFTInSubplot(app, ax, xTags, spLabels, k);
                    continue;
                end

                % --- Filter transform ---
                if hasSpecialTag(xTags, yTags, '__filter__')
                    spLabels = struct('title', '', 'xLabel', '', 'yLabel', '');
                    if isfield(sp, 'title'),  spLabels.title  = sp.title;  end
                    if isfield(sp, 'xLabel'), spLabels.xLabel = sp.xLabel; end
                    if isfield(sp, 'yLabel'), spLabels.yLabel = sp.yLabel; end
                    filterType = 'lowpass';
                    cutoffFreq = 5;
                    cutoffFreqHigh = 50;
                    showOriginal = true;
                    if isfield(sp, 'filterType') && ~isempty(sp.filterType)
                        filterType = sp.filterType;
                    end
                    if isfield(sp, 'cutoffFreq') && ~isempty(sp.cutoffFreq)
                        cutoffFreq = double(sp.cutoffFreq);
                    end
                    if isfield(sp, 'cutoffFreqHigh') && ~isempty(sp.cutoffFreqHigh)
                        cutoffFreqHigh = double(sp.cutoffFreqHigh);
                    end
                    if isfield(sp, 'showOriginal') && ~isempty(sp.showOriginal)
                        showOriginal = logical(sp.showOriginal);
                    end
                    ax = subplot(rows, cols, k, 'Parent', app.PlotFigure);
                    plotFilterInSubplot(app, ax, xTags, spLabels, ...
                        filterType, cutoffFreq, cutoffFreqHigh, showOriginal, k);
                    continue;
                end

                % --- Average transform ---
                if hasSpecialTag(xTags, yTags, '__average__')
                    spLabels = struct('title', '', 'xLabel', '', 'yLabel', '');
                    if isfield(sp, 'title'),  spLabels.title  = sp.title;  end
                    if isfield(sp, 'xLabel'), spLabels.xLabel = sp.xLabel; end
                    if isfield(sp, 'yLabel'), spLabels.yLabel = sp.yLabel; end
                    speedUnit = 'off';
                    if isfield(sp, 'speedUnit') && ~isempty(sp.speedUnit)
                        speedUnit = sp.speedUnit;
                    end
                    ax = subplot(rows, cols, k, 'Parent', app.PlotFigure);
                    plotAverageInSubplot(app, ax, xTags, spLabels, speedUnit);
                    continue;
                end

                % If only Y tags with no X, default X to first Y's time
                if isempty(xTags) && ~isempty(yTags)
                    firstYTag = getTagStruct(yTags, 1);
                    xTags = {struct('topic', firstYTag.topic, 'field', 'time')};
                end

                % Extract label strings from assignment
                spLabels = struct('title', '', 'xLabel', '', 'yLabel', '');
                if isfield(sp, 'title'),  spLabels.title  = sp.title;  end
                if isfield(sp, 'xLabel'), spLabels.xLabel = sp.xLabel; end
                if isfield(sp, 'yLabel'), spLabels.yLabel = sp.yLabel; end

                % Read scatter / fit settings (backwards compat)
                useScatter = false;
                fitDeg = 0;
                if isfield(sp, 'scatter') && ~isempty(sp.scatter)
                    useScatter = logical(sp.scatter);
                end
                if isfield(sp, 'fitDegree') && ~isempty(sp.fitDegree)
                    fitDeg = double(sp.fitDegree);
                end
                fitColor = [0 0 0];
                if isfield(sp, 'fitColor') && ~isempty(sp.fitColor)
                    fitColor = hex2rgb(sp.fitColor);
                end
                speedUnit = 'off';
                if isfield(sp, 'speedUnit') && ~isempty(sp.speedUnit)
                    speedUnit = sp.speedUnit;
                end

                ax = subplot(rows, cols, k, 'Parent', app.PlotFigure);
                plotSubplot(app, ax, xTags, yTags, spLabels, useScatter, fitDeg, fitColor, speedUnit);
            end

            % Bring main app window back to front
            figure(app.UIFigure);
        end

        % ==============================================================
        % Plot a single subplot
        % ==============================================================
        function plotSubplot(app, ax, xTags, yTags, spLabels, useScatter, fitDeg, fitColor, speedUnit)
            grid(ax, 'on');

            xTag = getTagStruct(xTags, 1);
            xTopic = xTag.topic;
            xField = xTag.field;

            xLogData = getLogDataForCsv(app, xTag);
            xTopicData = xLogData.(xTopic);
            xData = xTopicData.(xField);
            xTime = xTopicData.time;

            numY = getTagCount(yTags);

            % Collect units for each Y series to detect disagreements
            yUnits = cell(1, numY);
            for i = 1:numY
                yt = getTagStruct(yTags, i);
                yUnits{i} = lookupUnit(app, yt.topic, yt.field);
            end

            % Determine if we need dual Y-axes (yyaxis)
            uniqueUnits = unique(yUnits);
            useDualAxis = numel(uniqueUnits) == 2 && numY >= 2;

            if useDualAxis
                leftUnit = uniqueUnits{1};
                rightUnit = uniqueUnits{2};
                % Assign each series to left or right
                sides = cell(1, numY);
                for i = 1:numY
                    if strcmp(yUnits{i}, leftUnit)
                        sides{i} = 'left';
                    else
                        sides{i} = 'right';
                    end
                end
            end

            colors = lines(max(numY, 1));
            legendEntries = {};
            plotHandles = [];

            for i = 1:numY
                yTag = getTagStruct(yTags, i);
                yTopic = yTag.topic;
                yField = yTag.field;

                yLogData = getLogDataForCsv(app, yTag);
                yTopicData = yLogData.(yTopic);
                yData = yTopicData.(yField);
                yTime = yTopicData.time;

                % Align if cross-topic
                if strcmp(xTopic, yTopic)
                    xPlot = xData;
                    yPlot = yData;
                else
                    [xPlot, yPlot] = align_fields(xData, xTime, yData, yTime, 'linear');
                end

                % Switch yyaxis side if dual-axis mode
                if useDualAxis
                    yyaxis(ax, sides{i});
                end
                hold(ax, 'on');

                if useScatter
                    h = scatter(ax, xPlot, yPlot, 15, colors(i,:), 'filled');
                else
                    h = plot(ax, xPlot, yPlot, '-', 'Color', colors(i,:), 'LineWidth', 1.2);
                end
                plotHandles(end+1) = h; %#ok<AGROW>

                % Legend entry
                entry = lookupDisplayName(app, yTopic, yField);
                if app.ShowUnits
                    entry = [entry ' [' yUnits{i} ']']; %#ok<AGROW>
                end

                % Polynomial best-fit overlay
                hFit = [];
                if fitDeg >= 1 && numel(xPlot) > fitDeg
                    [xSorted, sortIdx] = sort(xPlot);
                    [p, ~, mu] = polyfit(xPlot, yPlot, fitDeg);
                    yFit = polyval(p, xSorted, [], mu);
                    SS_res = sum((yPlot(sortIdx) - yFit).^2);
                    SS_tot = sum((yPlot - mean(yPlot)).^2);
                    if SS_tot > 0
                        R2 = 1 - SS_res / SS_tot;
                    else
                        R2 = NaN;
                    end
                    hFit = plot(ax, xSorted, yFit, '--', 'Color', fitColor, ...
                        'LineWidth', 1.5);
                    % Build legend label: polynomial equation + R²
                    pRaw = polyfit(xPlot, yPlot, fitDeg);
                    polyStr = formatPoly(pRaw);
                    fitEntry = sprintf('%s  (R²=%.3f)', polyStr, R2);
                end

                if ~isempty(hFit)
                    % Only show the fit line in the legend, not the data points
                    plotHandles(end) = hFit;
                    legendEntries{end+1} = fitEntry; %#ok<AGROW>
                else
                    legendEntries{end+1} = entry; %#ok<AGROW>
                end
            end

            % Axis labels
            if app.ShowLabels
                if isfield(spLabels, 'title') && ~isempty(spLabels.title)
                    title(ax, spLabels.title, 'Interpreter', 'none');
                end
                if isfield(spLabels, 'xLabel') && ~isempty(spLabels.xLabel)
                    if app.ShowUnits
                        xlabel(ax, spLabels.xLabel, 'Interpreter', 'none');
                    else
                        xlabel(ax, stripUnit(spLabels.xLabel), 'Interpreter', 'none');
                    end
                end

                if useDualAxis
                    % Label each Y axis with its unit group
                    leftNames = {};
                    rightNames = {};
                    for i = 1:numY
                        yt = getTagStruct(yTags, i);
                        dn = lookupDisplayName(app, yt.topic, yt.field);
                        if strcmp(sides{i}, 'left')
                            leftNames{end+1} = dn; %#ok<AGROW>
                        else
                            rightNames{end+1} = dn; %#ok<AGROW>
                        end
                    end
                    yyaxis(ax, 'left');
                    if app.ShowUnits
                        ylabel(ax, [strjoin(leftNames, ', ') ' [' leftUnit ']'], 'Interpreter', 'none');
                    else
                        ylabel(ax, strjoin(leftNames, ', '), 'Interpreter', 'none');
                    end
                    yyaxis(ax, 'right');
                    if app.ShowUnits
                        ylabel(ax, [strjoin(rightNames, ', ') ' [' rightUnit ']'], 'Interpreter', 'none');
                    else
                        ylabel(ax, strjoin(rightNames, ', '), 'Interpreter', 'none');
                    end
                else
                    if isfield(spLabels, 'yLabel') && ~isempty(spLabels.yLabel)
                        if app.ShowUnits
                            ylabel(ax, spLabels.yLabel, 'Interpreter', 'none');
                        else
                            ylabel(ax, stripUnit(spLabels.yLabel), 'Interpreter', 'none');
                        end
                    end
                end
            end

            if numel(legendEntries) >= 1
                legend(ax, plotHandles, legendEntries, ...
                    'Interpreter', 'none', 'Location', 'best');
            end

            % Add speed conversion right axis when Y data is in m/s
            hasMPS = any(strcmp(yUnits, 'm/s'));
            if hasMPS && ~useDualAxis && ~strcmp(speedUnit, 'off')
                % Conversion factors from m/s
                convMap = struct( ...
                    'mph',   struct('factor', 2.23694,   'label', '[mph]'), ...
                    'kph',   struct('factor', 3.6,       'label', '[kph]'), ...
                    'knots', struct('factor', 1.94384,   'label', '[knots]'), ...
                    'mach',  struct('factor', 1/343,     'label', '[Mach]'), ...
                    'ft_s',  struct('factor', 3.28084,   'label', '[ft/s]'), ...
                    'cm_s',  struct('factor', 100,       'label', '[cm/s]'));

                key = strrep(speedUnit, '/', '_');
                if isfield(convMap, key)
                    conv = convMap.(key);
                    leftLims = ylim(ax);
                    yyaxis(ax, 'right');
                    ylim(ax, leftLims * conv.factor);
                    ylabel(ax, conv.label, 'Interpreter', 'none');
                    set(ax, 'YColor', [0.4 0.4 0.4]);
                    yyaxis(ax, 'left');
                end
            end

            hold(ax, 'off');
        end

        % ==============================================================
        % Plot GPS inside a subplot position
        % ==============================================================
        function plotGPSInSubplot(app, logData, rows, cols, idx, spLabels)
            gpsData = logData.gps_fix;
            lat = double(gpsData.latitude(:));
            lon = double(gpsData.longitude(:));
            alt = double(gpsData.altitude(:));

            % Bounding box with fixed 50 m buffer per side
            minLat = min(lat); maxLat = max(lat);
            minLon = min(lon); maxLon = max(lon);
            latBuf = 50 / 111320;  % 50 m in degrees latitude
            meanLat = (minLat + maxLat) / 2;
            lonBuf = 50 / (111320 * cosd(meanLat));  % 50 m in degrees longitude
            minLat = minLat - latBuf; maxLat = maxLat + latBuf;
            minLon = minLon - lonBuf; maxLon = maxLon + lonBuf;

            % Clean altitudes
            if any(isnan(alt)), alt = fillmissing(alt, 'linear'); end
            cmin = min(alt); cmax = max(alt);
            if cmin == cmax, cmin = cmin-1; cmax = cmax+1; end

            % Create a temporary axes to grab the subplot position
            tempAx = subplot(rows, cols, idx, 'Parent', app.PlotFigure);
            pos = tempAx.Position;
            delete(tempAx);

            % Create geoaxes at that position
            gx = geoaxes(app.PlotFigure, 'Position', pos);
            geobasemap(gx, 'satellite');
            geolimits(gx, [minLat maxLat], [minLon maxLon]);
            hold(gx, 'on');
            geoscatter(gx, lat, lon, 25, alt, 'filled');
            colormap(gx, parula(256));
            caxis(gx, [cmin cmax]);

            if app.ShowLabels
                if ~isempty(spLabels.title)
                    title(gx, spLabels.title, 'Interpreter', 'none');
                end
                if ~isempty(spLabels.xLabel)
                    gx.LongitudeLabel.String = spLabels.xLabel;
                end
                if ~isempty(spLabels.yLabel)
                    gx.LatitudeLabel.String = spLabels.yLabel;
                end
                cb = colorbar(gx);
                if ~isempty(spLabels.zLabel)
                    ylabel(cb, spLabels.zLabel, 'Interpreter', 'none');
                end
            else
                colorbar(gx);
            end

            hold(gx, 'off');
        end

        % ==============================================================
        % Plot Odometry inside a subplot
        % ==============================================================
        function plotOdomInSubplot(app, logData, rows, cols, idx)
            odom = logData.odom;
            x = odom.pos_x(:);
            y = odom.pos_y(:);
            theta = odom.orient_z(:);

            ax = subplot(rows, cols, idx, 'Parent', app.PlotFigure);
            plot(ax, x, y, 'b-', 'LineWidth', 1.5);
            hold(ax, 'on');
            xlabel(ax, 'X Position [m]', 'Interpreter', 'none');
            ylabel(ax, 'Y Position [m]', 'Interpreter', 'none');
            title(ax, 'Robot Path from Odometry');
            grid(ax, 'on');
            axis(ax, 'equal');

            % Draw ~20 heading arrows
            step = max(1, floor(numel(x) / 20));
            arrowScale = 0.1;
            for i = 1:step:numel(x)
                dx = arrowScale * cos(theta(i));
                dy = arrowScale * sin(theta(i));
                quiver(ax, x(i), y(i), dx, dy, 0, 'r', ...
                    'LineWidth', 2, 'MaxHeadSize', 2);
            end

            legend(ax, {'Path', 'Orientation'}, 'Location', 'best');
            hold(ax, 'off');
        end

        % ==============================================================
        % Plot Odometry rotated to align with GPS North
        % ==============================================================
        function plotOdomGPSInSubplot(app, logData, rows, cols, idx, spLabels)
            odom = logData.odom;
            gps  = logData.gps_fix;

            x     = odom.pos_x(:);
            y     = odom.pos_y(:);
            theta = odom.orient_z(:);

            % --- Compute heading offset between odom and GPS ---
            % Odom direction: atan2 from first pair with >0.3 m displacement
            odomDir = 0;
            foundOdom = false;
            for i = 2:numel(x)
                dd = sqrt((x(i) - x(1))^2 + (y(i) - y(1))^2);
                if dd > 0.3
                    odomDir = atan2(y(i) - y(1), x(i) - x(1));
                    foundOdom = true;
                    break;
                end
            end

            % GPS bearing: great-circle from first pair with >3 m displacement
            lat = gps.latitude(:);
            lon = gps.longitude(:);
            gpsDir = 0;
            foundGPS = false;
            if numel(lat) >= 2
                lat1r = deg2rad(lat(1));
                lon1r = deg2rad(lon(1));
                for i = 2:numel(lat)
                    lat2r = deg2rad(lat(i));
                    lon2r = deg2rad(lon(i));
                    % Haversine distance
                    dlat = lat2r - lat1r;
                    dlon = lon2r - lon1r;
                    a = sin(dlat/2)^2 + cos(lat1r)*cos(lat2r)*sin(dlon/2)^2;
                    dist = 2 * 6371000 * asin(sqrt(a));
                    if dist > 3
                        % Great-circle bearing (compass: 0=N, CW)
                        bearing = atan2(sin(lon2r - lon1r)*cos(lat2r), ...
                            cos(lat1r)*sin(lat2r) - sin(lat1r)*cos(lat2r)*cos(lon2r - lon1r));
                        % Convert compass bearing to math convention
                        gpsDir = pi/2 - bearing;
                        foundGPS = true;
                        break;
                    end
                end
            end

            % Rotation angle
            if foundOdom && foundGPS
                rotAngle = gpsDir - odomDir;
            else
                rotAngle = 0;
            end

            % Apply 2D rotation
            xRot = x * cos(rotAngle) - y * sin(rotAngle);
            yRot = x * sin(rotAngle) + y * cos(rotAngle);
            thetaRot = theta + rotAngle;

            % --- Plot ---
            ax = subplot(rows, cols, idx, 'Parent', app.PlotFigure);
            plot(ax, xRot, yRot, 'b-', 'LineWidth', 1.5);
            hold(ax, 'on');
            grid(ax, 'on');
            axis(ax, 'equal');

            if app.ShowLabels
                if ~isempty(spLabels.xLabel)
                    xlabel(ax, spLabels.xLabel, 'Interpreter', 'none');
                else
                    xlabel(ax, 'East [m]', 'Interpreter', 'none');
                end
                if ~isempty(spLabels.yLabel)
                    ylabel(ax, spLabels.yLabel, 'Interpreter', 'none');
                else
                    ylabel(ax, 'North [m]', 'Interpreter', 'none');
                end
                if ~isempty(spLabels.title)
                    title(ax, spLabels.title, 'Interpreter', 'none');
                else
                    title(ax, 'Odometry Path (GPS North Aligned)', 'Interpreter', 'none');
                end
            end

            % Draw ~20 heading arrows
            step = max(1, floor(numel(xRot) / 20));
            arrowScale = 0.1;
            for i = 1:step:numel(xRot)
                dx = arrowScale * cos(thetaRot(i));
                dy = arrowScale * sin(thetaRot(i));
                quiver(ax, xRot(i), yRot(i), dx, dy, 0, 'r', ...
                    'LineWidth', 2, 'MaxHeadSize', 2);
            end

            legend(ax, {'Path', 'Orientation'}, 'Location', 'best');
            hold(ax, 'off');
        end

        % ==============================================================
        % Plot Electrical data (V, I, P) as 3 mini-subplots in one slot
        % ==============================================================
        function plotCmdVelInSubplot(app, logData, rows, cols, idx, spLabels)
            cv = logData.cmd_vel;
            t = cv.time;

            ax = subplot(rows, cols, idx, 'Parent', app.PlotFigure);

            yyaxis(ax, 'left');
            plot(ax, t, cv.linear_x, '-', 'Color', [0 0.447 0.741], 'LineWidth', 1.2);
            if app.ShowLabels
                if ~isempty(spLabels.xLabel)
                    ylabel(ax, spLabels.xLabel, 'Interpreter', 'none');
                else
                    ylabel(ax, 'Forward Speed [m/s]', 'Interpreter', 'none');
                end
            end

            yyaxis(ax, 'right');
            plot(ax, t, cv.angular_z, '-', 'Color', [0.85 0.325 0.098], 'LineWidth', 1.2);
            if app.ShowLabels
                if ~isempty(spLabels.yLabel)
                    ylabel(ax, spLabels.yLabel, 'Interpreter', 'none');
                else
                    ylabel(ax, 'Turn Rate [rad/s]', 'Interpreter', 'none');
                end
            end

            grid(ax, 'on');
            legend(ax, {'Forward Speed', 'Turn Rate'}, 'Location', 'best');

            if app.ShowLabels
                xlabel(ax, 'Time [s]', 'Interpreter', 'none');
                if ~isempty(spLabels.title)
                    title(ax, spLabels.title, 'Interpreter', 'none');
                else
                    title(ax, 'Drive Commands (cmd\_vel)', 'Interpreter', 'none');
                end
            end
        end

        function plotElectricalInSubplot(app, logData, rows, cols, idx, spLabels)
            % Grab the subplot position, then replace with a tiled layout
            tempAx = subplot(rows, cols, idx, 'Parent', app.PlotFigure);
            pos = tempAx.Position;
            delete(tempAx);

            % Create a uipanel at that position to hold stacked axes
            pan = uipanel(app.PlotFigure, 'Units', 'normalized', ...
                'Position', pos, 'BorderType', 'none', ...
                'BackgroundColor', app.PlotFigure.Color);

            % Three vertical sub-axes within the panel
            specs = struct('topic', {}, 'dataField', {}, 'color', {}, 'defaultLabel', {});
            if isfield(logData, 'electrical_voltage')
                specs(end+1) = struct('topic', 'electrical_voltage', ...
                    'dataField', 'voltage_V', 'color', [0 0.447 0.741], ...
                    'defaultLabel', 'Voltage [V]');
            end
            if isfield(logData, 'electrical_current')
                specs(end+1) = struct('topic', 'electrical_current', ...
                    'dataField', 'current_A', 'color', [0.85 0.325 0.098], ...
                    'defaultLabel', 'Current [A]');
            end
            if isfield(logData, 'electrical_power')
                specs(end+1) = struct('topic', 'electrical_power', ...
                    'dataField', 'power_W', 'color', [0.466 0.674 0.188], ...
                    'defaultLabel', 'Power [W]');
            end

            n = numel(specs);
            if n == 0, return; end

            labelFields = {'xLabel', 'yLabel', 'zLabel'};
            gap = 0.06;
            topMargin = 0.06;
            bottomMargin = 0.12;
            axH = (1 - topMargin - bottomMargin - gap*(n-1)) / n;

            for i = 1:n
                bottom = 1 - topMargin - i*axH - (i-1)*gap;
                ax = axes(pan, 'Units', 'normalized', ...
                    'Position', [0.18 bottom 0.78 axH]);

                topicData = logData.(specs(i).topic);
                yData = topicData.(specs(i).dataField);
                plot(ax, topicData.time, yData, ...
                    '-', 'Color', specs(i).color, 'LineWidth', 1.5);
                grid(ax, 'on');
                padYAxis(ax, yData, 0.10);

                if app.ShowLabels
                    % Use custom label if provided, otherwise default
                    if i <= numel(labelFields) && ~isempty(spLabels.(labelFields{i}))
                        ylabel(ax, wrapYLabel(spLabels.(labelFields{i})), 'Interpreter', 'none');
                    else
                        ylabel(ax, wrapYLabel(specs(i).defaultLabel), 'Interpreter', 'none');
                    end
                    if i == n
                        xlabel(ax, 'Time [s]', 'Interpreter', 'none');
                    end
                end

                % Only show x tick labels on the bottom sub-axis
                if i < n
                    set(ax, 'XTickLabel', []);
                end
            end

            % Title on top
            if app.ShowLabels && ~isempty(spLabels.title)
                title(pan.Children(end), spLabels.title, 'Interpreter', 'none');
            elseif app.ShowLabels
                title(pan.Children(end), 'Electrical Data', 'Interpreter', 'none');
            end
        end

        % ==============================================================
        % Plot IMU data (Accel, Gyro, Orient) as 3 stacked axes
        % ==============================================================
        function plotIMUInSubplot(app, logData, rows, cols, idx, spLabels, showGroups)
            imu = logData.zed_zed_node_imu_data;
            t = imu.time;

            % Grab the subplot position, then replace with a panel
            tempAx = subplot(rows, cols, idx, 'Parent', app.PlotFigure);
            pos = tempAx.Position;
            delete(tempAx);

            % Filter groups by showGroups toggle
            allGroupFields = { ...
                {'accel_x','accel_y','accel_z'}, ...
                {'gyro_x','gyro_y','gyro_z'}, ...
                {'orient_x','orient_y','orient_z'}};
            allDefaultLabels = {'Accel [m/s^2]', 'Gyro [rad/s]', 'Orientation [rad]'};
            allLabelFields = {'xLabel', 'yLabel', 'zLabel'};

            visIdx = find(showGroups);
            groupFields = allGroupFields(visIdx);
            defaultLabels = allDefaultLabels(visIdx);
            labelFields = allLabelFields(visIdx);
            n = numel(groupFields);

            if n == 0, return; end

            pan = uipanel(app.PlotFigure, 'Units', 'normalized', ...
                'Position', pos, 'BorderType', 'none', ...
                'BackgroundColor', app.PlotFigure.Color);

            xyzColors = [0 0.447 0.741; 0.85 0.325 0.098; 0.466 0.674 0.188]; % blue, orange, green

            gap = 0.06;
            topMargin = 0.06;
            bottomMargin = 0.12;
            axH = (1 - topMargin - bottomMargin - gap*(n-1)) / n;

            for i = 1:n
                bottom = 1 - topMargin - i*axH - (i-1)*gap;
                ax = axes(pan, 'Units', 'normalized', ...
                    'Position', [0.18 bottom 0.78 axH]);
                hold(ax, 'on');

                flds = groupFields{i};
                allY = [];
                for j = 1:numel(flds)
                    plot(ax, t, imu.(flds{j}), '-', ...
                        'Color', xyzColors(j,:), 'LineWidth', 1.2);
                    allY = [allY; imu.(flds{j})(:)]; %#ok<AGROW>
                end
                hold(ax, 'off');
                grid(ax, 'on');
                padYAxis(ax, allY, 0.10);
                legend(ax, {'X','Y','Z'}, 'Location', 'best', 'FontSize', 7);

                if app.ShowLabels
                    if i <= numel(labelFields) && ~isempty(spLabels.(labelFields{i}))
                        ylabel(ax, wrapYLabel(spLabels.(labelFields{i})), 'Interpreter', 'none');
                    else
                        ylabel(ax, wrapYLabel(defaultLabels{i}), 'Interpreter', 'none');
                    end
                    if i == n
                        xlabel(ax, 'Time [s]', 'Interpreter', 'none');
                    end
                end

                if i < n
                    set(ax, 'XTickLabel', []);
                end
            end

            % Title on top
            if app.ShowLabels && ~isempty(spLabels.title)
                title(pan.Children(end), spLabels.title, 'Interpreter', 'none');
            elseif app.ShowLabels
                title(pan.Children(end), 'IMU Data', 'Interpreter', 'none');
            end
        end

        % ==============================================================
        % Plot corrected IMU data (Accel, Gyro, Orient) as 3 stacked axes
        % ==============================================================
        function plotIMUTransformInSubplot(app, logData, rows, cols, idx, spLabels, showGroups)
            imu = logData.imu_corrected;
            t = imu.time;

            % Retrieve rotation info for title annotation
            if ~isempty(app.RotInfo)
                rotInfo = app.RotInfo;
            else
                rotInfo = struct('pitch_deg', 0, 'roll_deg', 0);
            end

            % Grab the subplot position, then replace with a panel
            tempAx = subplot(rows, cols, idx, 'Parent', app.PlotFigure);
            pos = tempAx.Position;
            delete(tempAx);

            % Filter groups by showGroups toggle
            allGroupFields = { ...
                {'accel_x','accel_y','accel_z'}, ...
                {'gyro_x','gyro_y','gyro_z'}, ...
                {'orient_x','orient_y','orient_z'}};
            allDefaultLabels = {'OC Accel [m/s^2]', 'OC Gyro [rad/s]', 'Orientation [rad]'};
            allLabelFields = {'xLabel', 'yLabel', 'zLabel'};

            visIdx = find(showGroups);
            groupFields = allGroupFields(visIdx);
            defaultLabels = allDefaultLabels(visIdx);
            labelFields = allLabelFields(visIdx);
            n = numel(groupFields);

            if n == 0, return; end

            pan = uipanel(app.PlotFigure, 'Units', 'normalized', ...
                'Position', pos, 'BorderType', 'none', ...
                'BackgroundColor', app.PlotFigure.Color);

            xyzColors = [0 0.447 0.741; 0.85 0.325 0.098; 0.466 0.674 0.188];

            gap = 0.06;
            topMargin = 0.06;
            bottomMargin = 0.12;
            axH = (1 - topMargin - bottomMargin - gap*(n-1)) / n;

            for i = 1:n
                bottom = 1 - topMargin - i*axH - (i-1)*gap;
                ax = axes(pan, 'Units', 'normalized', ...
                    'Position', [0.18 bottom 0.78 axH]);
                hold(ax, 'on');

                flds = groupFields{i};
                allY = [];
                for j = 1:numel(flds)
                    plot(ax, t, imu.(flds{j}), '-', ...
                        'Color', xyzColors(j,:), 'LineWidth', 1.2);
                    allY = [allY; imu.(flds{j})(:)]; %#ok<AGROW>
                end
                hold(ax, 'off');
                grid(ax, 'on');
                padYAxis(ax, allY, 0.10);
                legend(ax, {'X','Y','Z'}, 'Location', 'best', 'FontSize', 7);

                if app.ShowLabels
                    if i <= numel(labelFields) && ~isempty(spLabels.(labelFields{i}))
                        ylabel(ax, wrapYLabel(spLabels.(labelFields{i})), 'Interpreter', 'none');
                    else
                        ylabel(ax, wrapYLabel(defaultLabels{i}), 'Interpreter', 'none');
                    end
                    if i == n
                        xlabel(ax, 'Time [s]', 'Interpreter', 'none');
                    end
                end

                if i < n
                    set(ax, 'XTickLabel', []);
                end
            end

            % Title on top showing detected angles
            if app.ShowLabels && ~isempty(spLabels.title)
                title(pan.Children(end), spLabels.title, 'Interpreter', 'none');
            elseif app.ShowLabels
                titleStr = sprintf('IMU Corrected (pitch=%.1f%s, roll=%.1f%s)', ...
                    rotInfo.pitch_deg, char(176), rotInfo.roll_deg, char(176));
                title(pan.Children(end), titleStr, 'Interpreter', 'none');
            end
        end

        % ==============================================================
        % Plot FFT in a subplot
        % ==============================================================
        function plotFFTInSubplot(app, ax, xTags, spLabels, k)
            if isempty(xTags), return; end
            sigTag = getTagStruct(xTags, 1);

            % Resolve signal: output field or normal LogData
            [signal, t, sigName] = resolveSignal(app, sigTag);
            if isempty(signal), return; end

            N = numel(signal);
            if N < 4, return; end

            % Resample to uniform time grid (ROS2 timestamps are non-uniform)
            fs = 1 / mean(diff(t));
            tUniform = linspace(t(1), t(end), N)';
            signal = interp1(t, signal, tUniform, 'linear');

            signal = detrend(signal); % Remove DC + linear trend

            % Full-length FFT for maximum frequency resolution
            Y = fft(signal);
            P2 = abs(Y / N);
            P1 = P2(1:floor(N/2)+1);
            P1(2:end-1) = 2 * P1(2:end-1);
            f = fs * (0:floor(N/2)) / N;

            % Store output for downstream use
            key = sprintf('s%d', k);
            app.TransformOutputs.(key) = struct( ...
                'type', 'fft', ...
                'freq', f(:), ...
                'magnitude', P1(:), ...
                'phase', angle(Y(1:floor(N/2)+1)), ...
                'complexFFT', Y(1:floor(N/2)+1));

            % Exclude bins below 1 Hz so the DC/near-DC region
            % doesn't dominate the y-axis scale
            fMin = 1;  % Hz
            plotIdx = f >= fMin;
            plot(ax, f(plotIdx), P1(plotIdx), '-', 'Color', [0.85 0.325 0.098], 'LineWidth', 1.2);
            grid(ax, 'on');

            if app.ShowLabels
                if ~isempty(spLabels.title)
                    title(ax, spLabels.title, 'Interpreter', 'none');
                end
                if ~isempty(spLabels.xLabel)
                    xlabel(ax, spLabels.xLabel, 'Interpreter', 'none');
                end
                if ~isempty(spLabels.yLabel)
                    ylabel(ax, spLabels.yLabel, 'Interpreter', 'none');
                end
            end

            legend(ax, {['FFT of ' sigName]}, 'Interpreter', 'none', 'Location', 'best');
        end

        % ==============================================================
        % Plot filtered signal in a subplot
        % ==============================================================
        function plotFilterInSubplot(app, ax, xTags, spLabels, filterType, cutoffFreq, cutoffFreqHigh, showOriginal, k)
            if isempty(xTags), return; end
            sigTag = getTagStruct(xTags, 1);

            % Resolve signal: output field or normal LogData
            [signal, t, sigName] = resolveSignal(app, sigTag);
            if isempty(signal), return; end

            N = numel(signal);
            if N < 4, return; end

            % Resample to uniform time grid (ROS2 timestamps are non-uniform)
            fs = 1 / mean(diff(t));
            tUniform = linspace(t(1), t(end), N)';
            signal = interp1(t, signal, tUniform, 'linear');

            nyq = fs / 2;

            % Clamp cutoff frequencies
            Wn = min(max(cutoffFreq, 0.1), nyq - 0.1);
            WnHigh = min(max(cutoffFreqHigh, 0.1), nyq - 0.1);

            filtered = applyFilter(signal, filterType, Wn, WnHigh, fs);

            % Store output for downstream use
            key = sprintf('s%d', k);
            outStruct = struct( ...
                'type', 'filter', ...
                'time', tUniform(:), ...
                'data', filtered(:), ...
                'fs', fs);

            % Compute and store a complex FFT of the filtered output so
            % downstream Estimate TF can use it directly
            Nfilt = numel(filtered);
            Yfilt = fft(filtered);
            halfN = floor(Nfilt/2) + 1;
            outStruct.complexFFT = Yfilt(1:halfN);
            outStruct.freq = fs * (0:halfN-1)' / Nfilt;

            app.TransformOutputs.(key) = outStruct;

            hold(ax, 'on');
            plotHandles = [];
            legendEntries = {};

            if showOriginal
                h1 = plot(ax, tUniform, signal, '-', 'Color', [0.7 0.7 0.7], 'LineWidth', 0.8);
                plotHandles(end+1) = h1;
                legendEntries{end+1} = 'Original';
            end

            h2 = plot(ax, tUniform, filtered, '-', 'Color', [0.85 0.325 0.098], 'LineWidth', 1.5);
            plotHandles(end+1) = h2;

            % Build filter description for legend
            if strcmp(filterType, 'bandpass')
                desc = sprintf('Band Pass (%.1f–%.1f Hz)', cutoffFreq, cutoffFreqHigh);
            elseif strcmp(filterType, 'highpass')
                desc = sprintf('High Pass (fc=%.1f Hz)', cutoffFreq);
            else
                desc = sprintf('Low Pass (fc=%.1f Hz)', cutoffFreq);
            end
            legendEntries{end+1} = desc;

            grid(ax, 'on');
            hold(ax, 'off');

            if app.ShowLabels
                if ~isempty(spLabels.title)
                    title(ax, spLabels.title, 'Interpreter', 'none');
                end
                if ~isempty(spLabels.xLabel)
                    xlabel(ax, spLabels.xLabel, 'Interpreter', 'none');
                end
                if ~isempty(spLabels.yLabel)
                    ylabel(ax, spLabels.yLabel, 'Interpreter', 'none');
                end
            end

            legend(ax, plotHandles, legendEntries, 'Interpreter', 'none', 'Location', 'best');
        end

        % ==============================================================
        % Plot signal with horizontal average line
        % ==============================================================
        function plotAverageInSubplot(app, ax, xTags, spLabels, speedUnit)
            if isempty(xTags), return; end
            sigTag = getTagStruct(xTags, 1);

            [signal, t, sigName] = resolveSignal(app, sigTag);
            if isempty(signal), return; end

            avg = mean(signal, 'omitnan');

            hold(ax, 'on');
            h1 = plot(ax, t, signal, '-', 'LineWidth', 1);
            h2 = yline(ax, avg, '--', 'Color', [0.85 0.325 0.098], 'LineWidth', 1.5);
            grid(ax, 'on');
            hold(ax, 'off');

            % Build legend with unit if available
            sigUnit = '';
            if isfield(sigTag, 'topic') && isfield(sigTag, 'field')
                sigUnit = lookupUnit(app, sigTag.topic, sigTag.field);
            end
            if ~isempty(sigUnit) && ~strcmp(sigUnit, '-') && app.ShowUnits
                avgLabel = sprintf('Average = %.4g %s', avg, sigUnit);
            else
                avgLabel = sprintf('Average = %.4g', avg);
            end

            legend(ax, [h1, h2], ...
                {sigName, avgLabel}, ...
                'Interpreter', 'none', 'Location', 'best');

            if app.ShowLabels
                if ~isempty(spLabels.title)
                    title(ax, spLabels.title, 'Interpreter', 'none');
                end
                if ~isempty(spLabels.xLabel)
                    if app.ShowUnits
                        xlabel(ax, spLabels.xLabel, 'Interpreter', 'none');
                    else
                        xlabel(ax, stripUnit(spLabels.xLabel), 'Interpreter', 'none');
                    end
                end
                if ~isempty(spLabels.yLabel)
                    if app.ShowUnits
                        ylabel(ax, spLabels.yLabel, 'Interpreter', 'none');
                    else
                        ylabel(ax, stripUnit(spLabels.yLabel), 'Interpreter', 'none');
                    end
                end
            end

            % Add speed conversion right axis when Y data is in m/s
            if strcmp(sigUnit, 'm/s') && ~strcmp(speedUnit, 'off')
                convMap = struct( ...
                    'mph',   struct('factor', 2.23694,   'label', '[mph]'), ...
                    'kph',   struct('factor', 3.6,       'label', '[kph]'), ...
                    'knots', struct('factor', 1.94384,   'label', '[knots]'), ...
                    'mach',  struct('factor', 1/343,     'label', '[Mach]'), ...
                    'ft_s',  struct('factor', 3.28084,   'label', '[ft/s]'), ...
                    'cm_s',  struct('factor', 100,       'label', '[cm/s]'));
                key = strrep(speedUnit, '/', '_');
                if isfield(convMap, key)
                    conv = convMap.(key);
                    leftLims = ylim(ax);
                    yyaxis(ax, 'right');
                    ylim(ax, leftLims * conv.factor);
                    ylabel(ax, conv.label, 'Interpreter', 'none');
                    set(ax, 'YColor', [0.4 0.4 0.4]);
                    yyaxis(ax, 'left');
                end
            end
        end

        % ==============================================================
        % Resolve signal from tag (normal field or transform output)
        % ==============================================================
        function [signal, t, sigName] = resolveSignal(app, sigTag)
            signal = [];
            t = [];
            sigName = '';

            field = sigTag.field;
            if strcmp(field, '__fft_output__') || strcmp(field, '__filter_output__')
                % Resolve from TransformOutputs
                if ~isfield(sigTag, 'sourceSubplot') || isempty(sigTag.sourceSubplot)
                    return;
                end
                srcIdx = double(sigTag.sourceSubplot);
                key = sprintf('s%d', srcIdx);
                if ~isfield(app.TransformOutputs, key)
                    return;
                end
                out = app.TransformOutputs.(key);
                if strcmp(field, '__fft_output__')
                    signal = out.magnitude;
                    t = out.freq;
                    sigName = sigTag.displayName;
                elseif strcmp(field, '__filter_output__')
                    signal = out.data;
                    t = out.time;
                    sigName = sigTag.displayName;
                end
            else
                % Normal LogData field
                ld = getLogDataForCsv(app, sigTag);
                if ~isfield(ld, sigTag.topic), return; end
                topicData = ld.(sigTag.topic);
                if ~isfield(topicData, sigTag.field), return; end
                signal = topicData.(sigTag.field);
                t = topicData.time;
                sigName = lookupDisplayName(app, sigTag.topic, sigTag.field);
            end
        end

        % ==============================================================
        % Plot Estimated Transfer Function (two-input) in a subplot
        % Uses H1 estimator (Welch's method) for time-domain inputs,
        % falls back to spectral division for frequency-domain inputs.
        % ==============================================================
        function plotBodeInSubplot(app, ax, xTags, inputTags, spLabels)
            % xTags = response/output data (Output zone)
            % inputTags = reference/input data (Input zone)
            if isempty(xTags) || isempty(inputTags), return; end

            respTag = getTagStruct(xTags, 1);
            refTag = getTagStruct(inputTags, 1);

            % Try time-domain resolution for H1 estimator
            [refSig, refTime] = resolveTimeDomain(app, refTag);
            [respSig, respTime] = resolveTimeDomain(app, respTag);

            if ~isempty(refSig) && ~isempty(respSig)
                % ---- H1 Estimator (Welch's method) ----

                % Resample both to uniform time grids
                Nref = numel(refSig);
                fsRef = 1 / mean(diff(refTime));
                tRef = linspace(refTime(1), refTime(end), Nref)';
                refSig = interp1(refTime, refSig, tRef, 'linear');

                Nresp = numel(respSig);
                fsResp = 1 / mean(diff(respTime));
                tResp = linspace(respTime(1), respTime(end), Nresp)';
                respSig = interp1(respTime, respSig, tResp, 'linear');

                % Align to common time grid
                tStart = max(tRef(1), tResp(1));
                tEnd = min(tRef(end), tResp(end));
                if tEnd <= tStart, return; end

                fs = max(fsRef, fsResp);
                tCommon = (tStart : 1/fs : tEnd)';
                N = numel(tCommon);
                if N < 16, return; end

                x = interp1(tRef, refSig, tCommon, 'linear', 0);
                y = interp1(tResp, respSig, tCommon, 'linear', 0);

                % Remove DC
                x = x - mean(x);
                y = y - mean(y);

                % Welch's method parameters
                nSegment = max(256, 2^nextpow2(round(N / 8)));
                nSegment = min(nSegment, N);
                nOverlap = round(nSegment / 2);  % 50% overlap
                step = nSegment - nOverlap;
                nSegs = floor((N - nSegment) / step) + 1;

                if nSegs < 1
                    nSegs = 1; nSegment = N; nOverlap = 0; step = N;
                end

                % Hann window (no toolbox required)
                win = 0.5 * (1 - cos(2*pi*(0:nSegment-1)'/(nSegment-1)));

                halfN = floor(nSegment/2) + 1;
                f = fs * (0:halfN-1)' / nSegment;

                Gxx = zeros(halfN, 1);
                Gyy = zeros(halfN, 1);
                Gxy = complex(zeros(halfN, 1));

                for seg = 1:nSegs
                    idx = (seg-1)*step + (1:nSegment);
                    xSeg = x(idx) .* win;
                    ySeg = y(idx) .* win;

                    X = fft(xSeg, nSegment);
                    Y = fft(ySeg, nSegment);
                    X = X(1:halfN);
                    Y = Y(1:halfN);

                    Gxx = Gxx + abs(X).^2;
                    Gyy = Gyy + abs(Y).^2;
                    Gxy = Gxy + conj(X) .* Y;
                end

                Gxx = Gxx / nSegs;
                Gyy = Gyy / nSegs;
                Gxy = Gxy / nSegs;

                % H1 estimator: H(f) = Gxy / Gxx
                H = Gxy ./ (Gxx + eps);

                % Coherence: gamma^2 = |Gxy|^2 / (Gxx * Gyy)
                Coh = abs(Gxy).^2 ./ (Gxx .* Gyy + eps);
                Coh = min(max(Coh, 0), 1);

                magDB = 20 * log10(abs(H) + eps);
                phaseDeg = angle(H) * 180 / pi;

                % Mask unreliable bins (coherence < 0.5)
                cohThresh = 0.5;
                reliable = Coh > cohThresh;
                magDB(~reliable) = NaN;
                phaseDeg(~reliable) = NaN;

                % Exclude DC
                fIdx = f > 0;
                fPlot = f(fIdx);
                magPlot = magDB(fIdx);
                phasePlot = phaseDeg(fIdx);

                if isempty(fPlot), return; end

                % Plot magnitude on left axis
                yyaxis(ax, 'left');
                semilogx(ax, fPlot, magPlot, '-', 'Color', [0 0.447 0.741], 'LineWidth', 1.5);
                if app.ShowLabels
                    ylabel(ax, 'Magnitude [dB]', 'Interpreter', 'none');
                end
                grid(ax, 'on');

                % Plot phase on right axis
                yyaxis(ax, 'right');
                hold(ax, 'on');
                semilogx(ax, fPlot, phasePlot, '-', 'Color', [0.85 0.325 0.098], 'LineWidth', 1.2);
                hold(ax, 'off');

                if app.ShowLabels
                    ylabel(ax, 'Phase [deg]', 'Interpreter', 'none');
                end

                if app.ShowLabels
                    if ~isempty(spLabels.title)
                        title(ax, spLabels.title, 'Interpreter', 'none');
                    else
                        titleStr = sprintf('H1 Estimate (%d segs, \\gamma^2 > %.1f mask)', ...
                            nSegs, cohThresh);
                        title(ax, titleStr, 'Interpreter', 'tex');
                    end
                    if ~isempty(spLabels.xLabel)
                        xlabel(ax, spLabels.xLabel, 'Interpreter', 'none');
                    end
                end

                legend(ax, {'Magnitude', 'Phase'}, ...
                    'Interpreter', 'none', 'Location', 'best');

            else
                % ---- Fallback: spectral division (for [s]-domain inputs) ----
                [fResp, cResp] = resolveBodeInput(app, respTag);
                [fRef, cRef] = resolveBodeInput(app, refTag);
                if isempty(fResp) || isempty(fRef), return; end

                % Align frequency vectors
                if numel(fResp) ~= numel(fRef) || max(abs(fResp - fRef)) > 1e-10
                    fCommon = fRef;
                    if numel(fResp) < numel(fRef)
                        fCommon = fResp;
                        cRef = interp1(fRef, cRef, fCommon, 'linear', 0);
                    else
                        cResp = interp1(fResp, cResp, fCommon, 'linear', 0);
                    end
                else
                    fCommon = fRef;
                end

                refMag = abs(cRef);
                threshold = max(refMag) * 0.01;
                reliable = refMag > threshold;

                H = cResp ./ cRef;
                H(~isfinite(H)) = 0;
                H(~reliable) = NaN;

                magDB = 20 * log10(abs(H) + eps);
                phaseDeg = angle(H) * 180 / pi;

                fIdx = fCommon > 0 & reliable;
                fPlot = fCommon(fIdx);
                magPlot = magDB(fIdx);
                phasePlot = phaseDeg(fIdx);

                if isempty(fPlot), return; end

                yyaxis(ax, 'left');
                semilogx(ax, fPlot, magPlot, '-', 'Color', [0 0.447 0.741], 'LineWidth', 1.5);
                if app.ShowLabels
                    ylabel(ax, 'Magnitude [dB]', 'Interpreter', 'none');
                end
                grid(ax, 'on');

                yyaxis(ax, 'right');
                hold(ax, 'on');
                semilogx(ax, fPlot, phasePlot, '-', 'Color', [0.85 0.325 0.098], 'LineWidth', 1.2);
                hold(ax, 'off');
                if app.ShowLabels
                    ylabel(ax, 'Phase [deg]', 'Interpreter', 'none');
                end

                if app.ShowLabels
                    if ~isempty(spLabels.title)
                        title(ax, spLabels.title, 'Interpreter', 'none');
                    end
                    if ~isempty(spLabels.xLabel)
                        xlabel(ax, spLabels.xLabel, 'Interpreter', 'none');
                    end
                end

                legend(ax, {'Magnitude', 'Phase'}, ...
                    'Interpreter', 'none', 'Location', 'best');
            end
        end

        % ==============================================================
        % Plot Bode (single signal) — magnitude + phase of one signal
        % ==============================================================
        function plotBodeSingleInSubplot(app, ax, xTags, spLabels, k)
            if isempty(xTags), return; end
            sigTag = getTagStruct(xTags, 1);

            % Resolve signal: output field or normal LogData
            [signal, t, sigName] = resolveSignal(app, sigTag);
            if isempty(signal), return; end

            N = numel(signal);
            if N < 4, return; end

            % Resample to uniform time grid
            fs = 1 / mean(diff(t));
            tUniform = linspace(t(1), t(end), N)';
            signal = interp1(t, signal, tUniform, 'linear');
            signal = signal - mean(signal); % Remove DC

            % FFT
            Y = fft(signal);
            halfN = floor(N/2) + 1;
            Yhalf = Y(1:halfN);
            f = fs * (0:halfN-1)' / N;

            % Store output for downstream (same as FFT output)
            key = sprintf('s%d', k);
            P2 = abs(Y / N);
            P1 = P2(1:halfN);
            P1(2:end-1) = 2 * P1(2:end-1);
            app.TransformOutputs.(key) = struct( ...
                'type', 'fft', ...
                'freq', f, ...
                'magnitude', P1, ...
                'phase', angle(Yhalf), ...
                'complexFFT', Yhalf);

            % Magnitude in dB and phase in degrees
            magDB = 20 * log10(abs(Yhalf) + eps);
            phaseDeg = angle(Yhalf) * 180 / pi;

            % Exclude DC (f=0)
            idx = f > 0;
            fPlot = f(idx);
            magPlot = magDB(idx);
            phasePlot = phaseDeg(idx);

            % Plot magnitude on left axis (semilog x)
            yyaxis(ax, 'left');
            semilogx(ax, fPlot, magPlot, '-', 'Color', [0 0.447 0.741], 'LineWidth', 1.5);
            if app.ShowLabels
                ylabel(ax, 'Magnitude [dB]', 'Interpreter', 'none');
            end
            grid(ax, 'on');

            % Plot phase on right axis
            yyaxis(ax, 'right');
            hold(ax, 'on');
            semilogx(ax, fPlot, phasePlot, '-', 'Color', [0.85 0.325 0.098], 'LineWidth', 1.2);
            hold(ax, 'off');
            if app.ShowLabels
                ylabel(ax, 'Phase [deg]', 'Interpreter', 'none');
            end

            if app.ShowLabels
                if ~isempty(spLabels.title)
                    title(ax, spLabels.title, 'Interpreter', 'none');
                end
                if ~isempty(spLabels.xLabel)
                    xlabel(ax, spLabels.xLabel, 'Interpreter', 'none');
                end
            end

            legend(ax, {[sigName ' Mag'], [sigName ' Phase']}, ...
                'Interpreter', 'none', 'Location', 'best');
        end

        % ==============================================================
        % Clear button
        % ==============================================================
        function ClearButtonPushed(app)
            app.Assignments = {};
            if ~isempty(app.FieldList)
                layout = parseLayout(app);
                app.HTMLComponent.Data = struct( ...
                    'type', 'fieldsUpdate', ...
                    'fields', {app.FieldList}, ...
                    'layout', layout, ...
                    'csvNames', {app.CsvNames});
            end
        end

        % ==============================================================
        % Units toggle
        % ==============================================================
        function UnitsToggled(app, src)
            app.ShowUnits = src.Value;
        end

        % ==============================================================
        % Labels toggle
        % ==============================================================
        function LabelsToggled(app, src)
            app.ShowLabels = src.Value;
        end

        % ==============================================================
        % Export figure
        % ==============================================================
        function ExportButtonPushed(app)
            if isempty(app.PlotFigure) || ~isvalid(app.PlotFigure)
                uialert(app.UIFigure, 'No plot to export. Click Plot first.', 'No Plot');
                return;
            end

            [file, path] = uiputfile( ...
                {'*.png','PNG Image'; '*.fig','MATLAB Figure'; '*.pdf','PDF Document'}, ...
                'Export Figure');
            if isequal(file, 0), return; end

            saveas(app.PlotFigure, fullfile(path, file));
        end

        % ==============================================================
        % Help button
        % ==============================================================
        function HelpButtonPushed(~)
            helpFig = uifigure('Name', 'Data Visualizer - Help', ...
                'Position', [200 100 620 600], ...
                'Resize', 'on');

            helpHTML = [ ...
                '<!DOCTYPE html><html><head><style>' ...
                'body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;' ...
                'font-size:13px;color:#222;padding:20px 28px;line-height:1.5;background:#fff;}' ...
                'h1{font-size:20px;margin:0 0 16px;color:#111;border-bottom:2px solid #333;padding-bottom:8px;}' ...
                'h2{font-size:15px;margin:18px 0 8px;color:#1a5276;border-bottom:1px solid #ddd;padding-bottom:4px;}' ...
                'ol,ul{margin:4px 0 10px 20px;}' ...
                'li{margin-bottom:4px;}' ...
                'code{background:#f0f0f0;padding:1px 5px;border-radius:3px;font-size:12px;}' ...
                '.tag{display:inline-block;padding:1px 7px;border-radius:10px;font-size:11px;font-weight:600;vertical-align:middle;}' ...
                '.gray{background:#e8e8e8;color:#444;border:1px solid #ccc;}' ...
                '.green{background:#d4edda;color:#155724;border:1px solid #82c991;}' ...
                '.orange{background:#ffe0b2;color:#e65100;border:1px solid #ffb74d;}' ...
                '.purple{background:#e1d5f0;color:#4a148c;border:1px solid #b39ddb;}' ...
                'table{border-collapse:collapse;margin:6px 0 12px;}' ...
                'td{padding:3px 10px;border:1px solid #ddd;font-size:12px;}' ...
                'td:first-child{font-weight:600;white-space:nowrap;}' ...
                '</style></head><body>' ...
                '<h1>Data Visualizer &mdash; Quick Guide</h1>' ...
                ...
                '<h2>Getting Started</h2>' ...
                '<ol>' ...
                '<li>Use the <code>Load</code> dropdown to import data:<ul>' ...
                '<li><b>Load 1 CSV</b> &mdash; single ROS2 log file.</li>' ...
                '<li><b>Load 2 CSV</b> &mdash; two log files for side-by-side comparison.</li>' ...
                '</ul></li>' ...
                '<li>Use the grid picker (top-left) to set subplot layout (e.g.&nbsp;2&times;2).</li>' ...
                '<li>Drag field tags from the right panel into subplot drop zones.</li>' ...
                '<li>Click <code>Plot</code> to generate the figure.</li>' ...
                '</ol>' ...
                ...
                '<h2>Field Panel (Right Side)</h2>' ...
                '<table>' ...
                '<tr><td><span class="tag gray">Field [t]</span></td><td>Normal data fields &mdash; drag to X or Y zones</td></tr>' ...
                '<tr><td><span class="tag green">Special</span></td><td>Special plot presets (GPS, Odom, IMU, Electrical)</td></tr>' ...
                '<tr><td><span class="tag orange">Transform</span></td><td>Transforms (FFT, Filter, Bode, Estimate TF, Average)</td></tr>' ...
                '<tr><td><span class="tag purple">Output</span></td><td>Transform outputs &mdash; chain into other subplots</td></tr>' ...
                '</table>' ...
                '<ul>' ...
                '<li>Click a dropped tag to toggle between X and Y role.</li>' ...
                '<li>Click the &times; button on a tag to remove it.</li>' ...
                '<li><b>Dual CSV mode:</b> two columns appear (one per file) with a shared transforms bar.</li>' ...
                '</ul>' ...
                ...
                '<h2>Special Plots</h2>' ...
                '<ul>' ...
                '<li><b>GPS Plot</b> &mdash; satellite map colored by altitude.</li>' ...
                '<li><b>Odometry Plot</b> &mdash; 2D robot path with heading arrows.</li>' ...
                '<li><b>Odom + GPS</b> &mdash; odometry path rotated to align with GPS heading.</li>' ...
                '<li><b>Cmd Vel</b> &mdash; drive commands (forward speed &amp; turn rate) with dual Y-axes.</li>' ...
                '<li><b>IMU Plot</b> &mdash; 3 stacked axes (Accel, Gyro, Orient).</li>' ...
                '<li><b>IMU Orient Correct</b> &mdash; auto-detects mounting angle from gravity, ' ...
                'rotates accel/gyro/orient to robot frame (Z up). Shows detected pitch &amp; roll.</li>' ...
                '<li><b>Electrical Plot</b> &mdash; voltage, current, power stacked.</li>' ...
                '</ul>' ...
                ...
                '<h2>Transforms</h2>' ...
                '<ul>' ...
                '<li><b>FFT</b> &mdash; drop to Transform zone, drag a signal to Signal zone. ' ...
                'Shows single-sided amplitude spectrum.</li>' ...
                '<li><b>Filter</b> &mdash; Low Pass / High Pass / Band Pass. Set cutoff frequency. ' ...
                'Toggle &ldquo;Show original&rdquo; to overlay the unfiltered signal.</li>' ...
                '<li><b>Bode Plot</b> &mdash; FFTs one signal, plots magnitude [dB] + phase [deg] ' ...
                'on a log-frequency axis.</li>' ...
                '<li><b>Estimate TF</b> &mdash; H1 estimator between Input (reference) and Output (response). ' ...
                'Uses Welch&rsquo;s method with coherence masking (&gamma;&sup2;&nbsp;&gt;&nbsp;0.5). ' ...
                'Best with broadband excitation (chirp, noise, step).</li>' ...
                '<li><b>Average</b> &mdash; plots the signal with a dashed horizontal line at the mean value.</li>' ...
                '</ul>' ...
                ...
                '<h2>Chaining Transforms</h2>' ...
                '<ul>' ...
                '<li><span class="tag purple">Output</span> bubbles appear when a transform + signal are assigned.</li>' ...
                '<li>Drag an output bubble into another subplot&rsquo;s Signal zone ' ...
                'to chain (e.g.&nbsp;Filter &rarr; FFT the filtered result).</li>' ...
                '<li>Red dashed lines show connections between linked subplots.</li>' ...
                '</ul>' ...
                ...
                '<h2>Controls</h2>' ...
                '<ul>' ...
                '<li><b>Scatter</b> &mdash; toggle scatter plot mode on normal subplots.</li>' ...
                '<li><b>Fit</b> &mdash; overlay polynomial best-fit (1st&ndash;5th degree) with R&sup2;.</li>' ...
                '<li><b>Speed</b> &mdash; add secondary Y-axis in mph/kph/knots when plotting m/s data.</li>' ...
                '<li><b>Units / Labels</b> &mdash; toggle axis units and labels globally.</li>' ...
                '<li><b>Export Fig</b> &mdash; save the plot figure as PNG, PDF, or .fig.</li>' ...
                '</ul>' ...
                ...
                '<h2>Tips</h2>' ...
                '<ul>' ...
                '<li>Drag the &#9776; handle to reorder subplots.</li>' ...
                '<li>Label inputs auto-fill but can be edited manually.</li>' ...
                '<li>Cross-topic Y fields are auto-aligned via interpolation.</li>' ...
                '<li>Two Y fields with different units automatically get dual Y-axes.</li>' ...
                '</ul>' ...
                '</body></html>' ...
            ];

            uihtml(helpFig, 'HTMLSource', ['data:text/html,' helpHTML], ...
                'Position', [0 0 620 600]);
        end
    end
end

% ==================================================================
% Helper functions (outside class)
% ==================================================================
function tag = getTagStruct(tags, idx)
    if iscell(tags)
        tag = tags{idx};
    else
        tag = tags(idx);
    end
end

function n = getTagCount(tags)
    if iscell(tags)
        n = numel(tags);
    elseif isstruct(tags)
        n = numel(tags);
    else
        n = 0;
    end
end

function out = tagList(tags)
%TAGLIST Convert tags (cell array or struct array) to cell array of structs.
    out = {};
    if isempty(tags), return; end
    n = getTagCount(tags);
    for i = 1:n
        out{end+1} = getTagStruct(tags, i); %#ok<AGROW>
    end
end

function tf = hasSpecialTag(xTags, yTags, fieldName)
%HASSPECIALTAG Check if any tag in xTags or yTags has the given special field name.
    tf = false;
    for i = 1:getTagCount(xTags)
        t = getTagStruct(xTags, i);
        if strcmp(t.field, fieldName), tf = true; return; end
    end
    for i = 1:getTagCount(yTags)
        t = getTagStruct(yTags, i);
        if strcmp(t.field, fieldName), tf = true; return; end
    end
end

function tag = findSpecialTag(xTags, yTags, fieldName)
%FINDSPECIALTAG Return the tag struct matching fieldName, or [] if not found.
    tag = [];
    for i = 1:getTagCount(xTags)
        t = getTagStruct(xTags, i);
        if strcmp(t.field, fieldName), tag = t; return; end
    end
    for i = 1:getTagCount(yTags)
        t = getTagStruct(yTags, i);
        if strcmp(t.field, fieldName), tag = t; return; end
    end
end

function name = prettyFieldName(field)
    parts = strsplit(field, '_');
    for i = 1:numel(parts)
        p = parts{i};
        if ~isempty(p)
            parts{i} = [upper(p(1)) p(2:end)];
        end
    end
    name = strjoin(parts, ' ');
end

function s = stripUnit(label)
    idx = strfind(label, ' [');
    if ~isempty(idx)
        s = label(1:idx(end)-1);
    else
        s = label;
    end
end

function [f, cFFT] = resolveBodeInput(app, tag)
%RESOLVEBODEINPUT Resolve a Bode input tag to frequency + complex FFT.
%   Handles: (1) FFT/filter transform outputs via extractSpectralData,
%   (2) normal [t]-domain LogData fields via auto-FFT.
    f = [];
    cFFT = [];
    field = tag.field;

    if strcmp(field, '__fft_output__') || strcmp(field, '__filter_output__')
        % Output field — resolve from TransformOutputs
        if ~isfield(tag, 'sourceSubplot') || isempty(tag.sourceSubplot)
            return;
        end
        key = sprintf('s%d', double(tag.sourceSubplot));
        if ~isfield(app.TransformOutputs, key), return; end
        [f, cFFT] = extractSpectralData(app.TransformOutputs.(key));
    else
        % Normal [t]-domain field — auto-FFT it
        ld = getLogDataForCsv(app, tag);
        if ~isfield(ld, tag.topic), return; end
        topicData = ld.(tag.topic);
        if ~isfield(topicData, tag.field), return; end
        signal = topicData.(tag.field);
        t = topicData.time;
        N = numel(signal);
        if N < 4, return; end
        fs = 1 / mean(diff(t));
        tUniform = linspace(t(1), t(end), N)';
        signal = interp1(t, signal, tUniform, 'linear');
        signal = signal - mean(signal);
        Y = fft(signal);
        f = fs * (0:floor(N/2))' / N;
        cFFT = Y(1:floor(N/2)+1);
    end
end

function [f, cFFT] = extractSpectralData(out)
%EXTRACTSPECTRALDATA Get frequency vector and complex FFT from a transform output.
%   FFT outputs have complexFFT directly. Filter outputs with an FFT source
%   also carry complexFFT (gain-adjusted). Otherwise falls back to FFT of data.
    f = [];
    cFFT = [];
    if isfield(out, 'complexFFT') && isfield(out, 'freq') ...
            && ~isempty(out.complexFFT) && ~isempty(out.freq)
        % Prefer stored complex spectral data (available for FFT and chained filters)
        f = out.freq(:);
        cFFT = out.complexFFT(:);
    elseif strcmp(out.type, 'filter')
        % Fallback: FFT the filter's time/data output
        tVec = out.time(:);
        mag = out.data(:);
        N = numel(mag);
        if N < 4, return; end
        fs = 1 / mean(diff(tVec));
        mag = mag - mean(mag);
        Y = fft(mag);
        f = fs * (0:floor(N/2))' / N;
        cFFT = Y(1:floor(N/2)+1);
    end
end

function [signal, t] = resolveTimeDomain(app, tag)
%RESOLVETIMEDOMAIN Resolve a tag to time-domain signal + time vector.
%   Returns empty if the tag cannot be resolved to time-domain data.
%   Handles: normal LogData fields and filter transform outputs.
%   FFT outputs are frequency-domain and cannot be resolved here.
    signal = [];
    t = [];
    field = tag.field;

    if strcmp(field, '__filter_output__')
        % Filter output: time-domain data
        if ~isfield(tag, 'sourceSubplot') || isempty(tag.sourceSubplot)
            return;
        end
        key = sprintf('s%d', double(tag.sourceSubplot));
        if ~isfield(app.TransformOutputs, key), return; end
        out = app.TransformOutputs.(key);
        if ~strcmp(out.type, 'filter'), return; end
        signal = out.data(:);
        t = out.time(:);
    elseif strcmp(field, '__fft_output__')
        % FFT output is frequency-domain — cannot resolve to time-domain
        return;
    else
        % Normal LogData field
        ld = getLogDataForCsv(app, tag);
        if ~isfield(ld, tag.topic), return; end
        topicData = ld.(tag.topic);
        if ~isfield(topicData, tag.field), return; end
        signal = topicData.(tag.field)(:);
        t = topicData.time(:);
    end
end

function ld = getLogDataForCsv(app, tag)
%GETLOGDATAFORCSV Return the correct LogData struct based on tag csvIndex.
    if isfield(tag, 'csvIndex') && ~isempty(tag.csvIndex) && tag.csvIndex == 2 && ~isempty(app.LogData2)
        ld = app.LogData2;
    else
        ld = app.LogData;
    end
end

function m = buildDisplayNameMap()
%BUILDDISPLAYNAMEMAP Returns a containers.Map of 'topic.field' -> display name.
    m = containers.Map('KeyType', 'char', 'ValueType', 'char');

    % Odometry
    m('odom.pos_x')    = 'Odometry Position X';
    m('odom.pos_y')    = 'Odometry Position Y';
    m('odom.orient_z') = 'Odometry Heading';

    % Encoders
    m('encoders.encoder_left')  = 'Left Encoder Ticks';
    m('encoders.encoder_right') = 'Right Encoder Ticks';

    % CMD Vel
    m('cmd_vel.linear_x')  = 'CMD Linear X';
    m('cmd_vel.z_angular')  = 'CMD Angular Z';

    % Motor Speed
    m('motor_speed.value_0') = 'Motor Command Speed';

    % Electrical
    m('electrical_voltage.voltage_V') = 'Real Time Voltage';
    m('electrical_current.current_A') = 'Real Time Current';
    m('electrical_power.power_W')     = 'Real Time Power';

    % IMU
    m('zed_zed_node_imu_data.accel_x')  = 'IMU Accel X';
    m('zed_zed_node_imu_data.accel_y')  = 'IMU Accel Y';
    m('zed_zed_node_imu_data.accel_z')  = 'IMU Accel Z';
    m('zed_zed_node_imu_data.gyro_x')   = 'IMU Gyro X';
    m('zed_zed_node_imu_data.gyro_y')   = 'IMU Gyro Y';
    m('zed_zed_node_imu_data.gyro_z')   = 'IMU Gyro Z';
    m('zed_zed_node_imu_data.orient_x') = 'IMU Orient X';
    m('zed_zed_node_imu_data.orient_y') = 'IMU Orient Y';
    m('zed_zed_node_imu_data.orient_z') = 'IMU Orient Z';
    m('zed_zed_node_imu_data.accel_mag') = 'IMU Accel Magnitude';
    m('zed_zed_node_imu_data.gyro_mag') = 'IMU Gyro Magnitude';

    % IMU Corrected (Orient Correct)
    m('imu_corrected.accel_x')   = 'IMU Orient Accel X';
    m('imu_corrected.accel_y')   = 'IMU Orient Accel Y';
    m('imu_corrected.accel_z')   = 'IMU Orient Accel Z';
    m('imu_corrected.gyro_x')    = 'IMU Orient Gyro X';
    m('imu_corrected.gyro_y')    = 'IMU Orient Gyro Y';
    m('imu_corrected.gyro_z')    = 'IMU Orient Gyro Z';
    m('imu_corrected.orient_x')  = 'IMU Orient Orient X';
    m('imu_corrected.orient_y')  = 'IMU Orient Orient Y';
    m('imu_corrected.orient_z')  = 'IMU Orient Orient Z';
    m('imu_corrected.accel_mag') = 'IMU Orient Accel Magnitude';
    m('imu_corrected.gyro_mag')  = 'IMU Orient Gyro Magnitude';

    % GPS (individual fields, in case needed elsewhere)
    m('gps_fix.latitude')  = 'GPS Latitude';
    m('gps_fix.longitude') = 'GPS Longitude';
    m('gps_fix.altitude')  = 'GPS Altitude';

    % Odom Velocity (raw)
    m('odom_velocity.vx')  = 'Odom Velocity X';
    m('odom_velocity.vy')  = 'Odom Velocity Y';
    m('odom_velocity.mag') = 'Odom Velocity Mag';

    % Odom Velocity (filtered)
    m('odom_velocity_filtered.vx')  = 'Odom Velocity X Filtered';
    m('odom_velocity_filtered.vy')  = 'Odom Velocity Y Filtered';
    m('odom_velocity_filtered.mag') = 'Odom Velocity Mag Filtered';
end

function s = formatPoly(p)
%FORMATPOLY Format polynomial coefficients [high→low] as readable string.
%   e.g. [2.5 -1.3 0.8] → "2.5x² - 1.3x + 0.8"
    n = numel(p);  % degree = n-1
    parts = {};
    superscripts = {'', '', char(178), char(179), char(8308), char(8309)};  % x, x², x³, x⁴, x⁵
    for k = 1:n
        c = p(k);
        deg = n - k;  % degree of this term
        if abs(c) < 1e-12, continue; end
        % Format coefficient
        cStr = sprintf('%.3g', abs(c));
        % Build term
        if deg == 0
            term = cStr;
        elseif deg == 1
            if strcmp(cStr, '1')
                term = 'x';
            else
                term = [cStr 'x'];
            end
        else
            sup = superscripts{deg + 1};
            if strcmp(cStr, '1')
                term = ['x' sup];
            else
                term = [cStr 'x' sup];
            end
        end
        % Sign
        if isempty(parts)
            if c < 0, term = ['-' term]; end
        else
            if c < 0
                term = [' - ' term];
            else
                term = [' + ' term];
            end
        end
        parts{end+1} = term; %#ok<AGROW>
    end
    if isempty(parts)
        s = '0';
    else
        s = ['y = ' strjoin(parts, '')];
    end
end

function rgb = hex2rgb(hexStr)
%HEX2RGB Convert '#RRGGBB' hex string to [r g b] in 0-1 range.
    hexStr = strrep(hexStr, '#', '');
    rgb = [hex2dec(hexStr(1:2)), hex2dec(hexStr(3:4)), hex2dec(hexStr(5:6))] / 255;
end

function filtered = applyFilter(signal, filterType, Wn, WnHigh, fs)
%APPLYFILTER Apply a digital filter to a signal.
%   Uses Signal Processing Toolbox (butter + filtfilt) if available,
%   otherwise falls back to an FFT-based frequency-domain filter with
%   Gaussian-tapered edges for zero-phase filtering without ringing.
    nyq = fs / 2;

    if license('test', 'Signal_Toolbox')
        % --- Toolbox path: 4th-order Butterworth + zero-phase filtfilt ---
        WnNorm = Wn / nyq;
        WnHighNorm = WnHigh / nyq;
        % Clamp to valid range (0, 1)
        WnNorm = min(max(WnNorm, 0.001), 0.999);
        WnHighNorm = min(max(WnHighNorm, 0.001), 0.999);

        if strcmp(filterType, 'bandpass')
            if WnNorm >= WnHighNorm
                WnHighNorm = min(WnNorm + 0.01, 0.999);
            end
            [b, a] = butter(4, [WnNorm WnHighNorm], 'bandpass');
        elseif strcmp(filterType, 'highpass')
            [b, a] = butter(4, WnNorm, 'high');
        else
            [b, a] = butter(4, WnNorm, 'low');
        end
        filtered = filtfilt(b, a, signal);
    else
        % --- Fallback: FFT-based frequency-domain filter ---
        N = numel(signal);
        F = fft(signal);
        freqs = (0:N-1)' * fs / N;

        % Build a frequency-domain mask with Gaussian-tapered edges
        % to reduce Gibbs ringing.  Transition bandwidth = 10% of cutoff.
        sigma = max(Wn * 0.1, 0.5);  % transition width in Hz

        if strcmp(filterType, 'lowpass')
            mask = exp(-0.5 * max(0, freqs - Wn).^2 / sigma^2);
        elseif strcmp(filterType, 'highpass')
            mask = 1 - exp(-0.5 * max(0, Wn - freqs).^2 / sigma^2);
        else % bandpass
            sigmaLo = max(Wn * 0.1, 0.5);
            sigmaHi = max(WnHigh * 0.1, 0.5);
            maskLo = 1 - exp(-0.5 * max(0, Wn - freqs).^2 / sigmaLo^2);
            maskHi = exp(-0.5 * max(0, freqs - WnHigh).^2 / sigmaHi^2);
            mask = maskLo .* maskHi;
        end

        % Mirror mask for negative frequencies (make it symmetric)
        if N > 1
            mask(end:-1:ceil(N/2)+1) = mask(2:floor(N/2)+1);
        end

        F = F .* mask;
        filtered = real(ifft(F));
    end
end

function lbl = wrapYLabel(str, maxChars)
%WRAPYLABEL Split a long label string into a cell array for multi-line ylabel.
    if nargin < 2, maxChars = 16; end
    if numel(str) <= maxChars
        lbl = str;
        return;
    end
    words = strsplit(str);
    lines = {''};
    for k = 1:numel(words)
        if isempty(lines{end})
            candidate = words{k};
        else
            candidate = [lines{end} ' ' words{k}];
        end
        if numel(candidate) <= maxChars || isempty(lines{end})
            lines{end} = candidate;
        else
            lines{end+1} = words{k}; %#ok<AGROW>
        end
    end
    if numel(lines) == 1
        lbl = lines{1};
    else
        lbl = lines;
    end
end

function padYAxis(ax, yData, fraction)
%PADYAXIS Add symmetric padding around data range on the Y axis.
%   fraction is the fraction of the range to add (e.g. 0.10 = 10%).
    yMin = min(yData, [], 'omitnan');
    yMax = max(yData, [], 'omitnan');
    if isempty(yMin) || isempty(yMax) || yMin == yMax
        return;
    end
    pad = (yMax - yMin) * fraction;
    ylim(ax, [yMin - pad, yMax + pad]);
end
