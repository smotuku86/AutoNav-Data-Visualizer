function [corrected, rotInfo] = transform_imu(imuRaw)
%TRANSFORM_IMU Rotate IMU data to robot frame (Z up, X forward, Y lateral).
%   [corrected, rotInfo] = transform_imu(imuRaw)
%
%   Auto-detects the camera mounting angle from the mean gravity vector
%   (first 200 samples assumed stationary) and applies Rodrigues' rotation
%   to align measured gravity with [0, 0, |g|].
%
%   Inputs:
%       imuRaw - struct with fields: time, accel_x, accel_y, accel_z,
%                gyro_x, gyro_y, gyro_z, orient_x, orient_y, orient_z
%                (orient fields are quaternion x,y,z components; w is
%                reconstructed as sqrt(1 - x^2 - y^2 - z^2))
%
%   Outputs:
%       corrected - struct with rotated accel/gyro/orient and recomputed
%                   accel_mag
%       rotInfo   - struct with R (3x3), pitch_deg, roll_deg, g_measured,
%                   calibSamples

    % Number of calibration samples (robot assumed stationary at start)
    N = numel(imuRaw.accel_x);
    nCalib = min(200, N);

    % Mean gravity vector from first nCalib samples
    g_meas = [ ...
        mean(imuRaw.accel_x(1:nCalib)), ...
        mean(imuRaw.accel_y(1:nCalib)), ...
        mean(imuRaw.accel_z(1:nCalib))];

    % Rodrigues' rotation: align g_meas direction with [0, 0, 1]
    a = g_meas(:) / norm(g_meas);
    b = [0; 0; 1];

    v = cross(a, b);
    s = norm(v);
    c = dot(a, b);

    if s < 1e-10
        % Already aligned (or anti-aligned)
        if c < 0
            R = -eye(3);
        else
            R = eye(3);
        end
    else
        % Skew-symmetric cross-product matrix of v
        K = [  0   -v(3)  v(2);
             v(3)   0   -v(1);
            -v(2)  v(1)   0  ];
        R = eye(3) + K + K*K * ((1 - c) / (s^2));
    end

    % Apply rotation to accel and gyro (vectorized: R * [3 x N])
    accel_raw = [imuRaw.accel_x(:)'; imuRaw.accel_y(:)'; imuRaw.accel_z(:)'];
    gyro_raw  = [imuRaw.gyro_x(:)';  imuRaw.gyro_y(:)';  imuRaw.gyro_z(:)'];

    accel_rot = R * accel_raw;  % 3 x N
    gyro_rot  = R * gyro_raw;

    % Build corrected struct
    corrected.time    = imuRaw.time(:);
    corrected.accel_x = accel_rot(1, :)';
    corrected.accel_y = accel_rot(2, :)';
    corrected.accel_z = accel_rot(3, :)';
    corrected.gyro_x  = gyro_rot(1, :)';
    corrected.gyro_y  = gyro_rot(2, :)';
    corrected.gyro_z  = gyro_rot(3, :)';

    % Correct orientation quaternions via quaternion composition
    % orient_x/y/z are quaternion components; reconstruct w
    qx = imuRaw.orient_x(:)';
    qy = imuRaw.orient_y(:)';
    qz = imuRaw.orient_z(:)';
    qw = sqrt(max(0, 1 - qx.^2 - qy.^2 - qz.^2));

    % Convert rotation matrix R to quaternion q_R = [w, x, y, z]
    q_R = rotm2quat_local(R);

    % Compose: q_corrected = q_R * q_measured (for each sample)
    % q_R is 1x4, q_meas is 4xN
    rw = q_R(1); rx = q_R(2); ry = q_R(3); rz = q_R(4);

    cw = rw.*qw - rx.*qx - ry.*qy - rz.*qz;
    cx = rw.*qx + rx.*qw + ry.*qz - rz.*qy;
    cy = rw.*qy - rx.*qz + ry.*qw + rz.*qx;
    cz = rw.*qz + rx.*qy - ry.*qx + rz.*qw;

    % Normalize to unit quaternion
    qnorm = sqrt(cw.^2 + cx.^2 + cy.^2 + cz.^2);
    qnorm(qnorm < 1e-12) = 1;
    cx = cx ./ qnorm;
    cy = cy ./ qnorm;
    cz = cz ./ qnorm;

    corrected.orient_x = cx';
    corrected.orient_y = cy';
    corrected.orient_z = cz';

    % Recompute acceleration and gyro magnitudes from corrected components
    corrected.accel_mag = sqrt( ...
        corrected.accel_x.^2 + corrected.accel_y.^2 + corrected.accel_z.^2);
    corrected.gyro_mag = sqrt( ...
        corrected.gyro_x.^2 + corrected.gyro_y.^2 + corrected.gyro_z.^2);

    % Rotation info
    rotInfo.R            = R;
    rotInfo.pitch_deg    = atan2d(-g_meas(1), g_meas(3));
    rotInfo.roll_deg     = atan2d(g_meas(2), g_meas(3));
    rotInfo.g_measured   = g_meas;
    rotInfo.calibSamples = nCalib;
end

function q = rotm2quat_local(R)
%ROTM2QUAT_LOCAL Convert 3x3 rotation matrix to quaternion [w, x, y, z].
%   Uses Shepperd's method for numerical stability.
    tr = trace(R);
    if tr > 0
        s = 0.5 / sqrt(tr + 1);
        w = 0.25 / s;
        x = (R(3,2) - R(2,3)) * s;
        y = (R(1,3) - R(3,1)) * s;
        z = (R(2,1) - R(1,2)) * s;
    elseif R(1,1) > R(2,2) && R(1,1) > R(3,3)
        s = 2 * sqrt(1 + R(1,1) - R(2,2) - R(3,3));
        w = (R(3,2) - R(2,3)) / s;
        x = 0.25 * s;
        y = (R(1,2) + R(2,1)) / s;
        z = (R(1,3) + R(3,1)) / s;
    elseif R(2,2) > R(3,3)
        s = 2 * sqrt(1 + R(2,2) - R(1,1) - R(3,3));
        w = (R(1,3) - R(3,1)) / s;
        x = (R(1,2) + R(2,1)) / s;
        y = 0.25 * s;
        z = (R(2,3) + R(3,2)) / s;
    else
        s = 2 * sqrt(1 + R(3,3) - R(1,1) - R(2,2));
        w = (R(2,1) - R(1,2)) / s;
        x = (R(1,3) + R(3,1)) / s;
        y = (R(2,3) + R(3,2)) / s;
        z = 0.25 * s;
    end
    q = [w, x, y, z];
    q = q / norm(q);  % ensure unit quaternion
end
