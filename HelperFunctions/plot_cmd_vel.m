function plot_cmd_vel(cmd_vel)
%PLOT_CMD_VEL  Plot linear_x and angular_z over time
%
%   plot_cmd_vel(cmd_vel)
%   where cmd_vel is a struct with fields:
%       cmd_vel.linear_x
%       cmd_vel.angular_z
%       cmd_vel.time
%
%   Example:
%       data = parse_log('ExampleBowserLog.txt');
%       plot_cmd_vel(data.cmd_vel);

    % --- Determine time vector ---
    t = cmd_vel.time(:);
    x = cmd_vel.linear_x(:);
    z = cmd_vel.angular_z(:);

    % --- Create figure with two subplots ---
    figure('Name','Motor Commands','Color','w');

    % Top: linear_x
    subplot(2,1,1);
    plot(t, x, 'b-', 'LineWidth', 1.5);
    ylabel('Linear X [m/s]');
    title('Command Velocities');
    grid on;

    % Bottom: angular_z
    subplot(2,1,2);
    plot(t, z, 'r-', 'LineWidth', 1.5);
    xlabel('Time [s]');
    ylabel('Z Angular [rad/s]');
    grid on;

end
