function data = clean_log(data)
%Function meant to data easier to read

%Offset odometery 
%it starts at a random number and increases/decreases
%here it is set to zero based on initial position

% Offset odometry data to start from zero
data.odom.pos_x = data.odom.pos_x(:) - data.odom.pos_x(1);
data.odom.pos_y = data.odom.pos_y(:) - data.odom.pos_y(1);
data.odom.orient_z =data.odom.orient_z(:) - data.odom.orient_z(1);

% Offset Encoder data to start from zero
data.encoders.encoder_left = data.encoders.encoder_left(:) - data.encoders.encoder_left(1);
data.encoders.encoder_right = data.encoders.encoder_right(:) - data.encoders.encoder_right(1);

end