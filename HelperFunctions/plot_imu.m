function plot_imu(imu_data)
%PLOT_IMU  Plots IMU data with interactive toggle for each series
%
% imu struct must have:
%   imu.accel_x, imu.accel_y, imu.accel_z
%   imu.gyro_x, imu.gyro_y, imu.gyro_z
%   imu.orient_x, imu.orient_y, imu.orient_z
%   imu.time (or imu.timestamp/time_s)
%
% Example:
%   data = parse_log('ExampleBowserLog.txt');
%   plot_imu_interactive(data.imu);

    t = imu_data.time;

    figure('Name','IMU','Color','w');

    % --- Accelerometer subplot ---
    ax1 = subplot(3,1,1); hold on;
    h.ax = plot(t, imu_data.accel_x, 'r', 'DisplayName','X Accel');
    h.ay = plot(t, imu_data.accel_y, 'g', 'DisplayName','Y Accel');
    h.az = plot(t, imu_data.accel_z, 'b', 'DisplayName','Z Accel');
    ylabel('Accel (m/s^2)');
    title('Accelerometer');
    grid on;
    legend('show');

    % --- Gyroscope subplot ---
    ax2 = subplot(3,1,2); hold on;
    h.gx = plot(t, imu_data.gyro_x, 'r', 'DisplayName','X Gyro');
    h.gy = plot(t, imu_data.gyro_y, 'g', 'DisplayName','Y Gyro');
    h.gz = plot(t, imu_data.gyro_z, 'b', 'DisplayName','Z Gyro');
    ylabel('Gyro (rad/s)');
    title('Gyroscope');
    grid on;
    legend('show');

    % --- Orientation subplot ---
    ax3 = subplot(3,1,3); hold on;
    h.ox = plot(t, imu_data.orient_x, 'r', 'DisplayName','X Orientation');
    h.oy = plot(t, imu_data.orient_y, 'g', 'DisplayName','Y Orientation');
    h.oz = plot(t, imu_data.orient_z, 'b', 'DisplayName','Z Orientation');
    ylabel('Orientation (rad)');
    xlabel('Time');
    title('Orientation');
    grid on;
    legend('show');

    % --- Create a uipanel for checkboxes on the right ---
    cbPanel = uipanel('Title','Toggle Lines','FontSize',10, ...
                      'Position',[0.91 0.05 0.08 0.9]);

    fields = fieldnames(h);
    n = numel(fields);
    for k = 1:n
        uicontrol('Parent',cbPanel, 'Style','checkbox', ...
                  'String', strrep(fields{k}, '_',' '), ...
                  'Value',1, ...
                  'Units','normalized', ...
                  'Position',[0.05 1-(k*0.05) 0.9 0.04], ...
                  'Callback', @(src,~) toggleLine(h.(fields{k}), src.Value));
    end

    % --- Nested function to toggle visibility ---
    function toggleLine(lineObj, val)
        if val
            lineObj.Visible = 'on';
        else
            lineObj.Visible = 'off';
        end
    end
end