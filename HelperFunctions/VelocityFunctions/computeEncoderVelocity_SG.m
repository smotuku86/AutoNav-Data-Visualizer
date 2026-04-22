function enc_vel = computeEncoderVelocity_SG(encoders, vehicleParams)
    if nargin < 2, vehicleParams = 'BowserVehicleParams'; end
    load([vehicleParams '.mat'], 'EncoderCount2Rev', 'WheelRadius')

    if ~isfield(encoders, 'time') || ...
       ~isfield(encoders, 'encoder_left') || ...
       ~isfield(encoders, 'encoder_right')
        warning('Encoder data missing required fields.');
        enc_vel = struct();
        return;
    end

    t = encoders.time(:);
    dt = mean(diff(t));

    ConversionFactor = (EncoderCount2Rev)^(-1) * 2 * pi * WheelRadius;

    order  = 3;
    window = 11;
    [~, g] = sgolay(order, window);

    % Encoder counts → SG derivative → velocity
    % conv() flips the kernel, so negate g(:,2) to get correct sign
    left_vel  = conv(encoders.encoder_left,  -g(:,2), 'same')  / dt * ConversionFactor;
    right_vel = conv(encoders.encoder_right, -g(:,2), 'same')  / dt * ConversionFactor;

    enc_vel.left  = left_vel;
    enc_vel.right = right_vel;
    enc_vel.time  = t;

    % Detect dead encoder (never changes) and assume both wheels equal
    leftDead  = all(diff(encoders.encoder_left)  == 0);
    rightDead = all(diff(encoders.encoder_right) == 0);
    enc_vel.assumedEqual = false;
    if leftDead && ~rightDead
        enc_vel.left = enc_vel.right;
        enc_vel.assumedEqual = true;
        enc_vel.deadSide = 'left';
        warning('Left encoder dead — assuming both wheels equal to right.');
    elseif rightDead && ~leftDead
        enc_vel.right = enc_vel.left;
        enc_vel.assumedEqual = true;
        enc_vel.deadSide = 'right';
        warning('Right encoder dead — assuming both wheels equal to left.');
    end
end