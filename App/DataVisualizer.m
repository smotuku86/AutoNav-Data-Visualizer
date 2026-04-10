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

        % Data
        LogData
        FieldList = {}      % cell array of structs: {topic, field, displayName, unit}
        Assignments = {}    % cell array of structs from HTML
        UnitMap
        DisplayNameMap

        % State
        CurrentLayout = [1 1]
        ShowUnits = true
        ShowLabels = true
        PlotFigure = []     % handle to the plot figure window
        WarningBar         % optional warning banner label
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

            app.LoadButton = uibutton(app.ToolbarPanel, 'push', ...
                'Text', 'Load CSV', ...
                'Position', [xPos 10 80 30], ...
                'ButtonPushedFcn', @(~,~) LoadButtonPushed(app));
            xPos = xPos + 90;

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

            % --- HTML Component (fills remaining space) ---
            htmlDir = fullfile(fileparts(mfilename('fullpath')), 'html');
            htmlFile = fullfile(htmlDir, 'dragdrop.html');

            % --- Warning bar (shown if Signal Processing Toolbox is missing) ---
            bannerH = 0;
            if ~license('test', 'Signal_Toolbox')
                bannerH = 26;
                app.WarningBar = uilabel(app.UIFigure, ...
                    'Text', ['  \x26A0 Signal Processing Toolbox not installed — ' ...
                             'filtered velocity will be unavailable.  ' ...
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

            bannerH = 0;
            if ~isempty(app.WarningBar) && isvalid(app.WarningBar)
                bannerH = 26;
                app.WarningBar.Position = [0 figH-50-bannerH figW bannerH];
            end
            app.HTMLComponent.Position = [0 0 figW figH-50-bannerH];
        end

        % ==============================================================
        % Load CSV
        % ==============================================================
        function LoadButtonPushed(app)
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

            % Compute derived velocity fields as synthetic topics
            if isfield(app.LogData, 'odom')
                raw = computeOdomVelocity(app.LogData.odom);
                app.LogData.odom_velocity.time = raw.time;
                app.LogData.odom_velocity.vx   = raw.x;
                app.LogData.odom_velocity.vy   = raw.y;
                app.LogData.odom_velocity.mag  = raw.mag;

                try
                    filt = computeOdomVelocity_SG(app.LogData.odom);
                    app.LogData.odom_velocity_filtered.time = filt.time;
                    app.LogData.odom_velocity_filtered.vx   = filt.x;
                    app.LogData.odom_velocity_filtered.vy   = filt.y;
                    app.LogData.odom_velocity_filtered.mag  = filt.mag;
                catch ME
                    warning('DataVisualizer:FilteredVelocity', ...
                        ['Filtered velocity unavailable: %s\n' ...
                         'Install Signal Processing Toolbox to enable this feature.'], ...
                        ME.message);
                end
            end

            app.FieldList = buildFieldList(app);

            layout = parseLayout(app);
            app.HTMLComponent.Data = struct( ...
                'type', 'fieldsUpdate', ...
                'fields', {app.FieldList}, ...
                'layout', layout);

            % Bring main app window back to front after file dialog
            figure(app.UIFigure);
        end

        % ==============================================================
        % Build field list from LogData struct
        % ==============================================================
        function fields = buildFieldList(app)
            fields = {};
            topics = fieldnames(app.LogData);
            for i = 1:numel(topics)
                topic = topics{i};

                % GPS: emit a special plot tag, then also the individual fields
                if strcmp(topic, 'gps_fix')
                    entry = struct( ...
                        'topic', 'gps_fix', ...
                        'field', '__gps__', ...
                        'displayName', 'GPS Plot Special', ...
                        'unit', '');
                    fields{end+1} = entry; %#ok<AGROW>
                end

                % Electrical: emit a special plot tag (only once, on first electrical topic)
                if startsWith(topic, 'electrical_') && ~any(cellfun(@(f) strcmp(f.field, '__electrical__'), fields))
                    entry = struct( ...
                        'topic', 'electrical', ...
                        'field', '__electrical__', ...
                        'displayName', 'Electrical Plot Special', ...
                        'unit', '');
                    fields{end+1} = entry; %#ok<AGROW>
                end

                % IMU: emit a special plot tag
                if strcmp(topic, 'zed_zed_node_imu_data')
                    entry = struct( ...
                        'topic', 'zed_zed_node_imu_data', ...
                        'field', '__imu__', ...
                        'displayName', 'IMU Plot Special', ...
                        'unit', '');
                    fields{end+1} = entry; %#ok<AGROW>
                end

                % Odom: emit a special plot tag, then also the individual fields
                if strcmp(topic, 'odom')
                    entry = struct( ...
                        'topic', 'odom', ...
                        'field', '__odom__', ...
                        'displayName', 'Odometry Plot Special', ...
                        'unit', '');
                    fields{end+1} = entry; %#ok<AGROW>
                end

                topicData = app.LogData.(topic);
                fnames = fieldnames(topicData);
                for j = 1:numel(fnames)
                    fname = fnames{j};
                    unit = lookupUnit(app, topic, fname);
                    displayName = lookupDisplayName(app, topic, fname);
                    entry = struct( ...
                        'topic', topic, ...
                        'field', fname, ...
                        'displayName', displayName, ...
                        'unit', unit);
                    fields{end+1} = entry; %#ok<AGROW>
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

            % Create or reuse figure (avoid figure() call which steals focus)
            if isempty(app.PlotFigure) || ~isvalid(app.PlotFigure)
                app.PlotFigure = figure('Name', 'Data Visualizer - Plots', ...
                    'NumberTitle', 'off', ...
                    'Position', [150 80 1000 700]);
            else
                clf(app.PlotFigure);
            end

            numSubplots = numel(app.Assignments);
            for k = 1:numSubplots
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

                % Check for special plot tags
                if hasSpecialTag(xTags, yTags, '__gps__')
                    if isfield(app.LogData, 'gps_fix')
                        spLabels = struct('title', '', 'xLabel', '', 'yLabel', '', 'zLabel', '');
                        if isfield(sp, 'title'),  spLabels.title  = sp.title;  end
                        if isfield(sp, 'xLabel'), spLabels.xLabel = sp.xLabel; end
                        if isfield(sp, 'yLabel'), spLabels.yLabel = sp.yLabel; end
                        if isfield(sp, 'zLabel'), spLabels.zLabel = sp.zLabel; end
                        plotGPSInSubplot(app, rows, cols, k, spLabels);
                    end
                    continue;
                end

                if hasSpecialTag(xTags, yTags, '__odom__')
                    if isfield(app.LogData, 'odom')
                        plotOdomInSubplot(app, rows, cols, k);
                    end
                    continue;
                end

                if hasSpecialTag(xTags, yTags, '__electrical__')
                    spLabels = struct('title', '', 'xLabel', '', 'yLabel', '', 'zLabel', '');
                    if isfield(sp, 'title'),  spLabels.title  = sp.title;  end
                    if isfield(sp, 'xLabel'), spLabels.xLabel = sp.xLabel; end
                    if isfield(sp, 'yLabel'), spLabels.yLabel = sp.yLabel; end
                    if isfield(sp, 'zLabel'), spLabels.zLabel = sp.zLabel; end
                    plotElectricalInSubplot(app, rows, cols, k, spLabels);
                    continue;
                end

                if hasSpecialTag(xTags, yTags, '__imu__')
                    if isfield(app.LogData, 'zed_zed_node_imu_data')
                        spLabels = struct('title', '', 'xLabel', '', 'yLabel', '', 'zLabel', '');
                        if isfield(sp, 'title'),  spLabels.title  = sp.title;  end
                        if isfield(sp, 'xLabel'), spLabels.xLabel = sp.xLabel; end
                        if isfield(sp, 'yLabel'), spLabels.yLabel = sp.yLabel; end
                        if isfield(sp, 'zLabel'), spLabels.zLabel = sp.zLabel; end
                        plotIMUInSubplot(app, rows, cols, k, spLabels);
                    end
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

            xTopicData = app.LogData.(xTopic);
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

                yTopicData = app.LogData.(yTopic);
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
        function plotGPSInSubplot(app, rows, cols, idx, spLabels)
            gpsData = app.LogData.gps_fix;
            lat = double(gpsData.latitude(:));
            lon = double(gpsData.longitude(:));
            alt = double(gpsData.altitude(:));

            % Bounding box with buffer
            minLat = min(lat); maxLat = max(lat);
            minLon = min(lon); maxLon = max(lon);
            buf = 0.005;
            latSz = max(maxLat - minLat, 0.0005);
            lonSz = max(maxLon - minLon, 0.0005);
            minLat = minLat - latSz*buf; maxLat = maxLat + latSz*buf;
            minLon = minLon - lonSz*buf; maxLon = maxLon + lonSz*buf;

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
        function plotOdomInSubplot(app, rows, cols, idx)
            odom = app.LogData.odom;
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
        % Plot Electrical data (V, I, P) as 3 mini-subplots in one slot
        % ==============================================================
        function plotElectricalInSubplot(app, rows, cols, idx, spLabels)
            % Grab the subplot position, then replace with a tiled layout
            tempAx = subplot(rows, cols, idx, 'Parent', app.PlotFigure);
            pos = tempAx.Position;
            delete(tempAx);

            % Create an invisible uipanel at that position to hold 3 axes
            pan = uipanel(app.PlotFigure, 'Units', 'normalized', ...
                'Position', pos, 'BorderType', 'none', 'BackgroundColor', 'w');

            % Three vertical sub-axes within the panel
            specs = struct('topic', {}, 'dataField', {}, 'color', {}, 'defaultLabel', {});
            if isfield(app.LogData, 'electrical_voltage')
                specs(end+1) = struct('topic', 'electrical_voltage', ...
                    'dataField', 'voltage_V', 'color', [0 0.447 0.741], ...
                    'defaultLabel', 'Voltage [V]');
            end
            if isfield(app.LogData, 'electrical_current')
                specs(end+1) = struct('topic', 'electrical_current', ...
                    'dataField', 'current_A', 'color', [0.85 0.325 0.098], ...
                    'defaultLabel', 'Current [A]');
            end
            if isfield(app.LogData, 'electrical_power')
                specs(end+1) = struct('topic', 'electrical_power', ...
                    'dataField', 'power_W', 'color', [0.466 0.674 0.188], ...
                    'defaultLabel', 'Power [W]');
            end

            n = numel(specs);
            if n == 0, return; end

            labelFields = {'xLabel', 'yLabel', 'zLabel'};
            gap = 0.08;
            axH = (1 - gap*(n+1)) / n;

            for i = 1:n
                bottom = 1 - i*(axH + gap);
                ax = axes(pan, 'Units', 'normalized', ...
                    'Position', [0.12 bottom 0.82 axH]);

                topicData = app.LogData.(specs(i).topic);
                plot(ax, topicData.time, topicData.(specs(i).dataField), ...
                    '-', 'Color', specs(i).color, 'LineWidth', 1.5);
                grid(ax, 'on');

                if app.ShowLabels
                    % Use custom label if provided, otherwise default
                    if i <= numel(labelFields) && ~isempty(spLabels.(labelFields{i}))
                        ylabel(ax, spLabels.(labelFields{i}), 'Interpreter', 'none');
                    else
                        ylabel(ax, specs(i).defaultLabel, 'Interpreter', 'none');
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
        function plotIMUInSubplot(app, rows, cols, idx, spLabels)
            imu = app.LogData.zed_zed_node_imu_data;
            t = imu.time;

            % Grab the subplot position, then replace with a panel
            tempAx = subplot(rows, cols, idx, 'Parent', app.PlotFigure);
            pos = tempAx.Position;
            delete(tempAx);

            pan = uipanel(app.PlotFigure, 'Units', 'normalized', ...
                'Position', pos, 'BorderType', 'none', 'BackgroundColor', 'w');

            % Three groups: Accel, Gyro, Orient — each with X/Y/Z
            groupFields = { ...
                {'accel_x','accel_y','accel_z'}, ...
                {'gyro_x','gyro_y','gyro_z'}, ...
                {'orient_x','orient_y','orient_z'}};
            defaultLabels = {'Acceleration [m/s^2]', 'Gyroscope [rad/s]', 'Orientation [rad]'};
            n = numel(groupFields);

            labelFields = {'xLabel', 'yLabel', 'zLabel'};
            xyzColors = [0 0.447 0.741; 0.85 0.325 0.098; 0.466 0.674 0.188]; % blue, orange, green

            gap = 0.06;
            axH = (1 - gap*(n+1)) / n;

            for i = 1:n
                bottom = 1 - i*(axH + gap);
                ax = axes(pan, 'Units', 'normalized', ...
                    'Position', [0.12 bottom 0.82 axH]);
                hold(ax, 'on');

                flds = groupFields{i};
                for j = 1:numel(flds)
                    plot(ax, t, imu.(flds{j}), '-', ...
                        'Color', xyzColors(j,:), 'LineWidth', 1.2);
                end
                hold(ax, 'off');
                grid(ax, 'on');
                legend(ax, {'X','Y','Z'}, 'Location', 'best', 'FontSize', 7);

                if app.ShowLabels
                    if i <= numel(labelFields) && ~isempty(spLabels.(labelFields{i}))
                        ylabel(ax, spLabels.(labelFields{i}), 'Interpreter', 'none');
                    else
                        ylabel(ax, defaultLabels{i}, 'Interpreter', 'none');
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
        % Clear button
        % ==============================================================
        function ClearButtonPushed(app)
            app.Assignments = {};
            if ~isempty(app.FieldList)
                layout = parseLayout(app);
                app.HTMLComponent.Data = struct( ...
                    'type', 'fieldsUpdate', ...
                    'fields', {app.FieldList}, ...
                    'layout', layout);
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
