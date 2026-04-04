
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
            % Add HelperFunctions to the path so parse_log, plot_*, etc. are found
            projRoot = fileparts(fileparts(mfilename('fullpath')));
            addpath(projRoot);
            addpath(genpath(fullfile(projRoot, 'HelperFunctions')));
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
            projRoot = fileparts(fileparts(mfilename('fullpath')));
            startDir = fullfile(projRoot, 'TestingData');
            [file, path] = uigetfile(fullfile(startDir, '*.csv;*.txt;*.log'), 'Select Log File');
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
            if ( isfield(app.LogData, 'encoders') ...
            || isfield(app.LogData, 'odom') ...
            || isfield(app.LogData, 'imu') )
                eligibleExtras{end+1} = 'Raw_Derived_Velocities';
                eligibleExtras{end+1} = 'Filtered_Derived_Velocities';
            end

            if isfield(app.LogData, 'motor_speed') ...
            && isfield(app.LogData, 'odom')
                eligibleExtras{end+1} = 'Motor_Speed_vs_Velocity';
            end

            if isfield(app.LogData, 'electrical_voltage') ...
            || isfield(app.LogData, 'electrical_current') ...
            || isfield(app.LogData, 'electrical_power')
                eligibleExtras{end+1} = 'Electrical_Data';
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
                        case 'zed_zed_node_imu_data', plot_imu(data);
                        case 'cmd_vel', plot_cmd_vel(data);
                        case 'encoders', plot_encoder_count(data);
                        case 'motor_speed', plot_motor_speed(data);
                        case {'electrical_voltage', 'electrical_current', 'electrical_power'}
                            % Handled below as a group
                        otherwise
                            fprintf('No plot function for topic: %s\n', topic);
                    end
                end
            end

            % --- Plot electrical topics as one combined figure ---
            elecTopics = {'electrical_voltage','electrical_current','electrical_power'};
            anyElecChecked = false;
            for i = 1:numel(elecTopics)
                if isfield(app.TopicCheckboxes, elecTopics{i}) ...
                && app.TopicCheckboxes.(elecTopics{i}).Value
                    anyElecChecked = true;
                    break;
                end
            end
            if anyElecChecked
                v = []; c = []; p = [];
                if isfield(app.LogData, 'electrical_voltage') ...
                && isfield(app.TopicCheckboxes, 'electrical_voltage') ...
                && app.TopicCheckboxes.electrical_voltage.Value
                    v = app.LogData.electrical_voltage;
                end
                if isfield(app.LogData, 'electrical_current') ...
                && isfield(app.TopicCheckboxes, 'electrical_current') ...
                && app.TopicCheckboxes.electrical_current.Value
                    c = app.LogData.electrical_current;
                end
                if isfield(app.LogData, 'electrical_power') ...
                && isfield(app.TopicCheckboxes, 'electrical_power') ...
                && app.TopicCheckboxes.electrical_power.Value
                    p = app.LogData.electrical_power;
                end
                plot_electrical(v, c, p);
            end

            % --- Plot selected additional graphs ---
            extras = fieldnames(app.AdditionalCheckboxes);
            for i = 1:numel(extras)
                name = extras{i};
                cb = app.AdditionalCheckboxes.(name);
                if cb.Value
                    % Call the function for this extra graph
                    switch name
                        case 'Raw_Derived_Velocities'
                             [odom_vel, imu_vel, enc_vel] = getVelocities(app.LogData);
                             plotVelocities(odom_vel, imu_vel, enc_vel);
                        case 'Filtered_Derived_Velocities'
                             % Get raw velocities to capture axis limits
                             [raw_odom, raw_imu, raw_enc] = getVelocities(app.LogData);
                             plotVelocities(raw_odom, raw_imu, raw_enc);
                             rawFig = gcf;
                             rawAx1 = subplot(2,1,1); xl1 = xlim(rawAx1); yl1 = ylim(rawAx1);
                             rawAx2 = subplot(2,1,2); xl2 = xlim(rawAx2); yl2 = ylim(rawAx2);
                             close(rawFig);

                             % Plot filtered velocities with same axis limits
                             [odom_vel, imu_vel, enc_vel] = FilteredGetVelocities(app.LogData);
                             plotVelocities(odom_vel, imu_vel, enc_vel);
                             set(gcf, 'Name', 'Filtered Velocities');
                             subplot(2,1,1); title('Velocity Components Filtered'); xlim(xl1); ylim(yl1);
                             subplot(2,1,2); title('Velocity Filtered'); xlim(xl2); ylim(yl2);
                        case 'Motor_Speed_vs_Velocity'
                             plot_motor_speed_vs_velocity(app.LogData.motor_speed, app.LogData.odom);
                        case 'Electrical_Data'
                             v = []; c = []; p = [];
                             if isfield(app.LogData, 'electrical_voltage')
                                 v = app.LogData.electrical_voltage;
                             end
                             if isfield(app.LogData, 'electrical_current')
                                 c = app.LogData.electrical_current;
                             end
                             if isfield(app.LogData, 'electrical_power')
                                 p = app.LogData.electrical_power;
                             end
                             plot_electrical(v, c, p);
                        otherwise
                            fprintf('No function for extra graph: %s\n', name);
                    end
                end
            end
        end
    end
end
