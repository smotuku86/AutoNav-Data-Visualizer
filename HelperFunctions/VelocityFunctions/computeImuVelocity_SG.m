function imu_vel = computeImuVelocity_SG(imu)
    required = {'time','accel_x','accel_y'};
    if ~all(isfield(imu, required))
        warning('IMU data missing one or more required fields.');
        imu_vel = struct();
        return;
    end

    t = imu.time(:);
    dt = diff(t);

    ax = imu.accel_x(:);
    ay = imu.accel_y(:);

    % SG smooth the accelerations
    order  = 3;
    window = 21;
    ax_f = sgolayfilt(ax, order, window);
    ay_f = sgolayfilt(ay, order, window);

    % Integrate smoothed accel → velocity
    vx = zeros(size(ax));
    vy = zeros(size(ay));

    for i = 2:length(t)
        vx(i) = vx(i-1) + ax_f(i-1) * dt(i-1);
        vy(i) = vy(i-1) + ay_f(i-1) * dt(i-1);
    end

    imu_vel.x    = vx;
    imu_vel.y    = vy;
    imu_vel.mag  = sqrt(vx.^2 + vy.^2);
    imu_vel.time = t;
end