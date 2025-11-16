%% Parameters
nPoints = 40;
dx = 0.5;                  % step in x (meters)
A = 1.0;                   % amplitude of sine (meters)
f = 0.5;                   % frequency of sine
speed = 0.5;               % linear speed (m/s)
t = (0:nPoints-1)';        % time step index

%% Preallocate path
x_pose = 1532 + dx * t;
y_pose = 1532 + A * sin(f * x_pose);

% Orientation (heading)
z_orientation = atan2(diff([0; y_pose]), diff([0; x_pose]));

% Linear speed along path
linear_x = [0; sqrt(diff(x_pose).^2 + diff(y_pose).^2)];

% Heading rate
z_angular = [0; diff(z_orientation)];

%% GPS Offsets
lat0 = 37.2296;
lon0 = -80.4139;

lat = lat0 + y_pose * 1e-4;
lon = lon0 + x_pose * 1e-4;
alt = 5 + 0.1 * sin(0.5 * t);

%% IMU (simplified)
x_accel = [0; diff(linear_x)];
y_accel = zeros(nPoints,1);
z_accel = 9.81 * ones(nPoints,1);  

x_gyro = zeros(nPoints,1);
y_gyro = zeros(nPoints,1);
z_gyro = z_angular;

x_orientation = zeros(nPoints,1);
y_orientation = zeros(nPoints,1);

%% Encoder parameters
wheel_radius = 0.2;                     % meters
wheel_circumference = 2 * pi * wheel_radius;
ticks_per_rev = 81000;
ticks_per_meter = ticks_per_rev / wheel_circumference;   % ~64516.1 ticks/m

% incremental distance each step
dist_step = [0; sqrt(diff(x_pose).^2 + diff(y_pose).^2)];

% accumulate ticks
encoder_left  = round(cumsum(dist_step * ticks_per_meter));
encoder_right = round(cumsum(dist_step * ticks_per_meter));

%% Timestamps
timestamps = 112520251526406000 + (0:nPoints-1)'*10000;  % 10ms increments

%% Write CSV
filename = 'makefakedata.csv';
fid = fopen(filename, 'w');

fprintf(fid, 'timestamp,topic,fields,values\n');

for i = 1:nPoints

    % GPS
    fprintf(fid, ...
        '%d,"/gps/fix","latitude,longitude,altitude",%.6f,%.6f,%.2f\n', ...
        timestamps(i), lat(i), lon(i), alt(i));

    % Odometry
    fprintf(fid, ...
        '%d,"/odom","pos_x,pos_y,orient_z",%.2f,%.2f,%.3f\n', ...
        timestamps(i), x_pose(i), y_pose(i), z_orientation(i));

    % Cmd Vel
    fprintf(fid, ...
        '%d,"/cmd_vel","linear_x,z_angular",%.2f,%.3f\n', ...
        timestamps(i), linear_x(i), z_angular(i));

    % IMU
    fprintf(fid, ...
        ['%d,"/imu",' ...
        '"x_accel,y_accel,z_accel,x_gyro,y_gyro,z_gyro,' ...
        'x_orientation,y_orientation,z_orientation",' ...
        '%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f\n'], ...
        timestamps(i), ...
        x_accel(i), y_accel(i), z_accel(i), ...
        x_gyro(i), y_gyro(i), z_gyro(i), ...
        x_orientation(i), y_orientation(i), z_orientation(i));

    % Encoders
    fprintf(fid, ...
        '%d,"/encoders","encoder_left,encoder_right",%d,%d\n', ...
        timestamps(i), encoder_left(i), encoder_right(i));

end

fclose(fid);

fprintf('CSV file "%s" successfully created.\n', filename);
