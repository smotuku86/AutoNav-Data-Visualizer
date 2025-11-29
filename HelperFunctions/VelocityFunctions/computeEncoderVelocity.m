function enc_vel = computeEncoderVelocity(encoders)
    load('BowserVehicleParams.mat', 'EncoderCount2Rev', 'WheelRadius')

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