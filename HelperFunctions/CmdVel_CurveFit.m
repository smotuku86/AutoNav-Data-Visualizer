function [m, b, fig] = CmdVel_CurveFit(cmd_vel, odom)
%CmdVel_CurveFit Correlate commanded velocity to SG-smoothed odom speed
%   Returns slope (m), intercept (b), and figure handle
%   The resulting linear equation output is clamped to ±5 mph (≈2.235 m/s)

% --- Ensure column vectors ---
t_cmd = cmd_vel.time(:);
v_cmd = cmd_vel.linear_x(:);

% --- Compute SG-smoothed odometry velocity ---
odom_vel = computeOdomVelocity_SG(odom);
odom_speed = odom_vel.mag;

% --- Interpolate cmd_vel to odometry timestamps ---
v_cmd_interp = interp1(t_cmd, v_cmd, odom_vel.time, 'linear', 'extrap');

% --- Linear fit y = m*x + b ---
p = polyfit(v_cmd_interp, odom_speed, 1);
m = p(1);
b = p(2);

% --- Predicted odometry speed (for plotting) ---
pred_speed = m*v_cmd_interp + b;

% --- Clamp predicted speed to ±5 mph ---
mph_limit = 5;
v_limit = mph2mps(mph_limit); % 5 mph in m/s
pred_speed(pred_speed >  v_limit) =  v_limit;
pred_speed(pred_speed < -v_limit) = -v_limit;

% --- Plot ---
fig = figure;
scatter(v_cmd_interp, odom_speed, 25, 'filled');
hold on;
plot(v_cmd_interp, pred_speed, 'r', 'LineWidth', 2);
xlabel('Commanded Velocity (arb. units)');
ylabel('Observed Odometry Speed (m/s)');
title(sprintf('Cmd Vel vs SG-Smoothed Odometry Speed (Clamped ±%d mph)', mph_limit));
grid on;
legend('Data', sprintf('Clamped Fit: y = %.2fx + %.2f', m, b));

end

function mps = mph2mps(mph)
% Convert miles per hour to meters per second
mps = mph * 0.44704;
end