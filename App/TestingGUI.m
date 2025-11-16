classdef TestingGUI < handle
    properties
        UIFigure
        LoadLogButton
        PlotGraphsButton
        TopicsPanel
        AdditionalGraphsPanel
        LogData
        TopicCheckboxes = struct()
        AdditionalCheckboxes = struct()
    end

    methods
        function app = TestingGUI
            createComponents(app);
        end

        function createComponents(app)
            % --- Main window ---
            app.UIFigure = uifigure('Name', 'Log Plotter', 'Position', [100 100 800 400]);

            % --- Load Log Button ---
            app.LoadLogButton = uibutton(app.UIFigure, 'push', ...
                'Text', 'Load Log', ...
                'Position', [20 350 100 30], ...
                'ButtonPushedFcn', @(~,~)LoadLogButtonPushed(app));

            % --- Plot Graphs Button ---
            app.PlotGraphsButton = uibutton(app.UIFigure, 'push', ...
                'Text', 'Plot Graphs', ...
                'Position', [140 350 100 30], ...
                'ButtonPushedFcn', @(~,~)PlotGraphsButtonPushed(app));

            % --- Topics Panel ---
            app.TopicsPanel = uipanel(app.UIFigure, ...
                'Title', 'Topics', ...
                'Position', [20 20 350 320], ...
                'Scrollable', 'on');

            % --- Additional Graphs Panel ---
            app.AdditionalGraphsPanel = uipanel(app.UIFigure, ...
                'Title', 'Additional Graphs', ...
                'Position', [400 20 350 320], ...
                'Scrollable', 'on');
        end

        % ==========================================================
        % Load Log Button
        % ==========================================================
        function LoadLogButtonPushed(app)
            [file, path] = uigetfile('*.csv;*.txt;*.log', 'Select Log File');
            if isequal(file,0), return; end
            fullpath = fullfile(path, file);

            try
                app.LogData = parse_log(fullpath); 
                app.LogData = clean_log(app.LogData);
            catch ME
                uialert(app.UIFigure, sprintf("Error parsing log:\n%s", ME.message), 'Parse Error');
                return;
            end

            % --- Clear previous checkboxes ---
            delete(app.TopicsPanel.Children);
            delete(app.AdditionalGraphsPanel.Children);
            app.TopicCheckboxes = struct();
            app.AdditionalCheckboxes = struct();

            % --- Populate Topics Panel ---
            topics = fieldnames(app.LogData);
            panelY = app.TopicsPanel.Position(4) - 30;
            for i = 1:numel(topics)
                topic = topics{i};
                cb = uicheckbox(app.TopicsPanel, ...
                    'Text', topic, ...
                    'Position', [10 panelY 200 22]);
                app.TopicCheckboxes.(topic) = cb;
                panelY = panelY - 30;
            end

            % --- Populate Additional Graphs Panel dynamically ---
            eligibleExtras = {};
            if isfield(app.LogData, 'encoders') ...
            || isfield(app.LogData, 'odom') ...
            || isfield(app.LogData, 'imu')
                eligibleExtras{end+1} = 'Derived_Velocities';
            end

            panelY = app.AdditionalGraphsPanel.Position(4) - 30;
            for i = 1:numel(eligibleExtras)
                name = eligibleExtras{i};
                cb = uicheckbox(app.AdditionalGraphsPanel, ...
                    'Text', name, ...
                    'Position', [10 panelY 200 22]);
                app.AdditionalCheckboxes.(name) = cb;
                panelY = panelY - 30;
            end
        end

        % ==========================================================
        % Plot Graphs Button
        % ==========================================================
        function PlotGraphsButtonPushed(app)
            if isempty(app.LogData)
                uialert(app.UIFigure, 'Load a log file first.', 'No Data');
                return;
            end

            % --- Plot selected topics ---
            topics = fieldnames(app.TopicCheckboxes);
            for i = 1:numel(topics)
                topic = topics{i};
                cb = app.TopicCheckboxes.(topic);
                if cb.Value
                    data = app.LogData.(topic);
                    switch topic
                        case 'gps_fix', plotGPS(data);
                        case 'odom', plot_odom(data);
                        case 'imu', plot_imu(data);
                        case 'cmd_vel', plot_cmd_vel(data);
                        case 'encoders', plot_encoder_count(data);
                        otherwise
                            fprintf('No plot function for topic: %s\n', topic);
                    end
                end
            end

            % --- Plot selected additional graphs ---
            extras = fieldnames(app.AdditionalCheckboxes);
            for i = 1:numel(extras)
                name = extras{i};
                cb = app.AdditionalCheckboxes.(name);
                if cb.Value
                    % Call the function for this extra graph
                    switch name
                        case 'Derived_Velocities'
                             [odom_vel, imu_vel, enc_vel] = getVelocities(app.LogData);
                             plotVelocities(odom_vel, imu_vel, enc_vel);
                        otherwise
                            fprintf('No function for extra graph: %s\n', name);
                    end
                end
            end
        end
    end
end
