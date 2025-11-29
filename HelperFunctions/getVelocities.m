function [odom_vel, imu_vel, enc_vel] = getVelocities(data)
    odom_vel = struct();
    imu_vel = struct();
    enc_vel = struct();

    % --- Compute Odometry Velocity ---
    if isfield(data, 'odom')
        odom_vel = computeOdomVelocity(data.odom);
    else
        warning('No odometry data found.');
    end

    % --- Compute IMU Velocity ---
    if isfield(data, 'zed_zed_node_imu_data')
        imu_vel = computeImuVelocity(data.zed_zed_node_imu_data);
    else
        warning('No IMU data found.');
    end

    % --- Compute Encoder Velocity ---
    if isfield(data, 'encoders')
        enc_vel = computeEncoderVelocity(data.encoders);
    else
        warning('No encoder data found.');
    end
end
