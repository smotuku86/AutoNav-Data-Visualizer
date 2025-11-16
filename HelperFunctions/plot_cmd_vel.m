function plot_cmd_vel(cmd_vel)
%PLOT_CMD_VEL  Plot linear_x and z_angular over time
%
%   plot_cmd_vel(cmd_vel)
%   where cmd_vel is a struct with fields:
%       cmd_vel.linear_x
%       cmd_vel.z_angular
%       cmd_vel.time
%
%   Example:
%       data = parse_log('ExampleBowserLog.txt');
%       plot_cmd_vel(data.cmd_vel);

    % --- Determine time vector ---
    t = cmd_vel.time(:);
    x = cmd_vel.linear_x(:);
    z = cmd_vel.z_angular(:);

    % --- Create figure with two subplots ---
    figure('Name','Motor Commands','Color','w');

    % Top: linear_x
    subplot(2,1,1);
    plot(t, x, 'b-', 'LineWidth', 1.5);
    ylabel('Linear X (m/s)');
    title('Command Velocities');
    grid on;

    % Bottom: z_angular
    subplot(2,1,2);
    plot(t, z, 'r-', 'LineWidth', 1.5);
    xlabel('Time');
    ylabel('Z Angular (rad/s)');
    grid on;

end
