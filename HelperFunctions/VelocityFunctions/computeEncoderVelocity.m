function enc_vel = computeEncoderVelocity(encoders, vehicleParams)
    if nargin < 2, vehicleParams = 'BowserVehicleParams'; end
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
    ConversionFactor = (EncoderCount2Rev)^(-1) * 2 * pi * WheelRadius;
    %    ^ from encoder count/s to m/s

    enc_vel.left  = diff(encoders.encoder_left) ./ dt * ConversionFactor;
    enc_vel.right = diff(encoders.encoder_right) ./ dt * ConversionFactor;
    enc_vel.time  = t(2:end);

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