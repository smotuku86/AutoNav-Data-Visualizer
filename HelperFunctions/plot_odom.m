function plot_odom(odom)
%PLOT_ODOM  Plot XY position with heading arrows from odometry data.
%
%   plot_odom(odom)
%   where odom is a struct with fields:
%       odom.pos_x
%       odom.pos_y
%       odom.orient_z   (yaw in radians, converted by clean_log)
%
%   Example:
%       data = parse_log('ExampleBrowserLog.txt');
%       plot_odom(data.odom);

    % --- Basic validation ---
    if ~isfield(odom, 'pos_x') || ~isfield(odom, 'pos_y') || ~isfield(odom, 'orient_z')
        error('Input struct must contain pos_x, pos_y, and orient_z fields.');
    end

    x = odom.pos_x(:);
    y = odom.pos_y(:);
    theta = odom.orient_z(:);

    % --- Plot path ---
    figure('Name','Odometry Path','Color','w');
    plot(x, y, 'b-', 'LineWidth', 1.5); hold on;
    xlabel('X Position [m]');
    ylabel('Y Position [m]');
    title('Robot Path from Odometry');
    grid on;
    axis equal;

    % --- Arrow parameters ---
    step = max(1, floor(numel(x) / 20)); % draw ~20 arrows max
    arrow_scale = 0.1;                   % arrow length (in meters)

    % --- Draw arrows for orientation ---
    for i = 1:step:numel(x)
        dx = arrow_scale * cos(theta(i));
        dy = arrow_scale * sin(theta(i));
        quiver(x(i), y(i), dx, dy, 0, 'r', 'LineWidth', 2, 'MaxHeadSize', 2);
    end

    legend({'Path', 'Orientation'});

end
