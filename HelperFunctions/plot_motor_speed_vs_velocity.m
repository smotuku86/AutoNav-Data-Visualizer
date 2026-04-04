function plot_motor_speed_vs_velocity(motor_speed_data, odom_data)
%PLOT_MOTOR_SPEED_VS_VELOCITY  Scatter plot of motor command speed vs odom velocity
%
%   plot_motor_speed_vs_velocity(motor_speed_data, odom_data)
%
%   Inputs:
%       motor_speed_data - struct with .time, .value_0
%       odom_data        - struct with .time, .pos_x, .pos_y

    % --- Compute odometry velocity magnitude ---
    odom_vel = computeOdomVelocity(odom_data);

    % --- Interpolate motor_speed onto odom velocity time vector ---
    motor_speed_aligned = interp1(motor_speed_data.time, motor_speed_data.value_0, ...
                                  odom_vel.time, 'nearest');

    % --- Remove NaNs from interpolation edges ---
    valid = ~isnan(motor_speed_aligned) & ~isnan(odom_vel.mag);
    x = motor_speed_aligned(valid);
    y = odom_vel.mag(valid);

    % --- Linear fit ---
    p = polyfit(x, y, 1);
    y_fit = polyval(p, x);
    SS_res = sum((y - y_fit).^2);
    SS_tot = sum((y - mean(y)).^2);
    R2 = 1 - SS_res / SS_tot;

    % --- Scatter plot ---
    figure('Name', 'Motor Speed vs Velocity', 'Color', 'w');
    scatter(x, y, 20, 'filled', 'MarkerFaceAlpha', 0.5);
    hold on;

    % --- Plot best fit line ---
    x_line = linspace(min(x), max(x), 200);
    plot(x_line, polyval(p, x_line), 'r-', 'LineWidth', 2);
    hold off;

    xlabel('Motor Command Speed [-]');
    ylabel('Odometry Velocity Magnitude [m/s]');
    title('Motor Command Speed vs Odometry Velocity');
    legend('Data', sprintf('y = %.4f x + %.4f  (R^2 = %.4f)', p(1), p(2), R2), ...
           'Location', 'best');
    grid on;

end
