function data = clean_log(data)
%Function meant to data easier to read

%Offset odometery 
%it starts at a random number and increases/decreases
%here it is set to zero based on initial position

% Remove duplicate consecutive odom rows (logger captures same reading twice)
if isfield(data, 'odom')
    keep = [true; diff(data.odom.pos_x(:)) ~= 0 ...
                | diff(data.odom.pos_y(:)) ~= 0 ...
                | diff(data.odom.orient_z(:)) ~= 0];
    fields = fieldnames(data.odom);
    for k = 1:numel(fields)
        data.odom.(fields{k}) = data.odom.(fields{k})(keep);
    end

    % Convert orient_z from quaternion z component to yaw angle (radians)
    % Assumes planar motion (q.x = q.y = 0), so yaw = 2*asin(q.z)
    qz = max(-1, min(1, data.odom.orient_z(:)));
    data.odom.orient_z = 2 * asin(qz);

    % Offset position to start from zero (heading is kept absolute)
    data.odom.pos_x = data.odom.pos_x(:) - data.odom.pos_x(1);
    data.odom.pos_y = data.odom.pos_y(:) - data.odom.pos_y(1);
end

% Offset Encoder data to start from zero
if isfield(data, 'encoders')
    data.encoders.encoder_left = data.encoders.encoder_left(:) - data.encoders.encoder_left(1);
    data.encoders.encoder_right = data.encoders.encoder_right(:) - data.encoders.encoder_right(1);
end

end