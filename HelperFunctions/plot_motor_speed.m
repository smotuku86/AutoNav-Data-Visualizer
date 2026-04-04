function plot_motor_speed(motor_speed)
%PLOT_MOTOR_SPEED  Plot motor command speed over time
%
%   plot_motor_speed(motor_speed)
%   where motor_speed is a struct with fields:
%       motor_speed.value_0
%       motor_speed.time
%
%   Example:
%       data = parse_log('log.csv');
%       plot_motor_speed(data.motor_speed);

    % --- Validate input structure ---
    if ~isfield(motor_speed, 'value_0') || ~isfield(motor_speed, 'time')
        error('Input struct must contain fields: time and value_0.');
    end

    % --- Extract data ---
    t = motor_speed.time(:);
    speed = motor_speed.value_0(:);

    % --- Plot ---
    figure('Name','Motor Command Speed','Color','w');
    plot(t, speed, 'b-', 'LineWidth', 1.5);
    xlabel('Time (seconds)');
    ylabel('Motor Command Speed');
    title('Motor Command Speed');
    grid on;

end
