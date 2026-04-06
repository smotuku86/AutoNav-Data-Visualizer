function plot_motor_speed_vs_power(motor_speed_data, power_data)
%PLOT_MOTOR_SPEED_VS_POWER  Scatter plot of power vs motor command speed with linear fit
%
%   plot_motor_speed_vs_power(motor_speed_data, power_data)
%
%   Inputs:
%       motor_speed_data - struct with .time, .value_0
%       power_data       - struct with .time, .power_W
%
%   Plots Power [W] on the X-axis and Motor Command Speed [-] on the Y-axis
%   with a linear best-fit line and R^2 value.

    % --- Validate inputs ---
    if ~isfield(motor_speed_data, 'value_0') || ~isfield(motor_speed_data, 'time')
        error('motor_speed_data must contain fields: time and value_0.');
    end
    if ~isfield(power_data, 'power_W') || ~isfield(power_data, 'time')
        error('power_data must contain fields: time and power_W.');
    end

    % --- Interpolate motor_speed onto power time vector ---
    motor_speed_aligned = interp1(motor_speed_data.time, motor_speed_data.value_0, ...
                                  power_data.time, 'nearest');

    % --- Remove NaNs from interpolation edges ---
    valid = ~isnan(motor_speed_aligned) & ~isnan(power_data.power_W);
    x = power_data.power_W(valid);
    y = motor_speed_aligned(valid);

    if numel(x) < 2
        error('Not enough overlapping data points to plot.');
    end

    % --- Linear fit ---
    p = polyfit(x, y, 1);
    y_fit = polyval(p, x);
    SS_res = sum((y - y_fit).^2);
    SS_tot = sum((y - mean(y)).^2);
    R2 = 1 - SS_res / SS_tot;

    % --- Scatter plot ---
    figure('Name', 'Motor Speed vs Power', 'Color', 'w');
    scatter(x, y, 20, 'filled', 'MarkerFaceAlpha', 0.5);
    hold on;

    % --- Plot best fit line ---
    x_line = linspace(min(x), max(x), 200);
    plot(x_line, polyval(p, x_line), 'r-', 'LineWidth', 2);
    hold off;

    xlabel('Power [W]');
    ylabel('Motor Command Speed [-]');
    title('Motor Command Speed vs Power');
    legend('Data', sprintf('y = %.4f x + %.4f  (R^2 = %.4f)', p(1), p(2), R2), ...
           'Location', 'best');
    grid on;

end
