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

    ConversionFactor = (EncoderCount2Rev)^(-1) * WheelRadius;

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
end