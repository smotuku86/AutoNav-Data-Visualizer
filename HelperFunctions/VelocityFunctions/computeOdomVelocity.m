function odom_vel = computeOdomVelocity(odom)
    t = odom.time;
    if ~isnumeric(t)
        error('odom.time must be numeric seconds');
    end

    dx = diff(odom.pos_x);
    dy = diff(odom.pos_y);
    dt = diff(t);

    odom_vel.x = dx ./ dt;
    odom_vel.y = dy ./ dt;
    odom_vel.mag = sqrt(odom_vel.x.^2 + odom_vel.y.^2);
    odom_vel.time = t(2:end);
end