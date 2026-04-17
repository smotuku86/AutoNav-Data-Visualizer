function [odom_vel, imu_vel, enc_vel] = getVelocities(data, vehicleParams)
    if nargin < 2, vehicleParams = 'BowserVehicleParams'; end
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
        enc_vel = computeEncoderVelocity(data.encoders, vehicleParams);
    else
        warning('No encoder data found.');
    end
end

%% ================================================================
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

%% ================================================================
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

%% ================================================================
function enc_vel = computeEncoderVelocity(encoders, vehicleParams)
    load([vehicleParams '.mat'], 'EncoderCount2Rev', 'WheelRadius')

    if ~isfield(encoders, 'time') || ...
       ~isfield(encoders, 'encoder_left') || ...
       ~isfield(encoders, 'encoder_right')
        warning('Encoder data missing required fields.');
        enc_vel = struct();
        return;
    end

    t = encoders.time;
    dt = diff(t);
    ConversionFactor = (EncoderCount2Rev)^(-1) * WheelRadius; 
    %    ^ from encoder count/s to m/s

    enc_vel.left  = diff(encoders.encoder_left) ./ dt * ConversionFactor;
    enc_vel.right = diff(encoders.encoder_right) ./ dt * ConversionFactor;
    enc_vel.time  = t(2:end);
end