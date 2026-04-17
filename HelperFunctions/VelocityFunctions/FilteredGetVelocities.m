function [odom_vel, imu_vel, enc_vel] = FilteredGetVelocities(data, vehicleParams)
    if nargin < 2, vehicleParams = 'BowserVehicleParams'; end
    odom_vel = struct();
    imu_vel  = struct();
    enc_vel  = struct();

    % --- Compute Odometry Velocity (SG Derivative) ---
    if isfield(data, 'odom')
        odom_vel = computeOdomVelocity_SG(data.odom);
    else
        warning('No odometry data found.');
    end

    % --- Compute IMU Velocity (SG smoothed accel integration) ---
    if isfield(data, 'zed_zed_node_imu_data')
        imu_vel = computeImuVelocity_SG(data.zed_zed_node_imu_data);
    else
        warning('No IMU data found.');
    end

    % --- Compute Encoder Velocity (SG Derivative) ---
    if isfield(data, 'encoders')
        enc_vel = computeEncoderVelocity_SG(data.encoders, vehicleParams);
    else
        warning('No encoder data found.');
    end
end
