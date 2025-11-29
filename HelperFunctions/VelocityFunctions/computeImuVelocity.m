function imu_vel = computeImuVelocity(imu)
    required = {'time', 'accel_x', 'accel_y'};
    if ~all(isfield(imu, required))
        warning('IMU data missing one or more required fields.');
        imu_vel = struct();
        return;
    end

    t = imu.time;
    dt = diff(t);

    ax = imu.accel_x(:);
    ay = imu.accel_y(:);

    imu_vel.x = zeros(length(ax),1);
    imu_vel.y = zeros(length(ay),1);

    for i = 2:length(t)
        imu_vel.x(i) = imu_vel.x(i-1) + ax(i-1) * dt(i-1);
        imu_vel.y(i) = imu_vel.y(i-1) + ay(i-1) * dt(i-1);
    end

    imu_vel.mag = sqrt(imu_vel.x.^2 + imu_vel.y.^2);
    imu_vel.time = t;
end