function unitMap = get_unit_map()
%GET_UNIT_MAP Returns a containers.Map mapping 'topic.field' to unit strings.
%   unitMap = get_unit_map() returns a map where keys are 'topic.field'
%   strings (matching the struct field names from parse_log) and values
%   are the corresponding unit strings for axis labels.

    unitMap = containers.Map('KeyType', 'char', 'ValueType', 'char');

    % Time fields (all topics)
    unitMap('*.time') = 's';

    % Odometry
    unitMap('odom.pos_x')    = 'm';
    unitMap('odom.pos_y')    = 'm';
    unitMap('odom.orient_z') = 'rad';

    % Encoders
    unitMap('encoders.encoder_left')  = '-';
    unitMap('encoders.encoder_right') = '-';

    % IMU (zed_zed_node_imu_data)
    unitMap('zed_zed_node_imu_data.accel_x')  = 'm/s^2';
    unitMap('zed_zed_node_imu_data.accel_y')  = 'm/s^2';
    unitMap('zed_zed_node_imu_data.accel_z')  = 'm/s^2';
    unitMap('zed_zed_node_imu_data.gyro_x')   = 'rad/s';
    unitMap('zed_zed_node_imu_data.gyro_y')   = 'rad/s';
    unitMap('zed_zed_node_imu_data.gyro_z')   = 'rad/s';
    unitMap('zed_zed_node_imu_data.orient_x') = 'rad';
    unitMap('zed_zed_node_imu_data.orient_y') = 'rad';
    unitMap('zed_zed_node_imu_data.orient_z') = 'rad';

    % Commanded velocity
    unitMap('cmd_vel.linear_x')  = 'm/s';
    unitMap('cmd_vel.z_angular') = 'rad/s';

    % Motor speed
    unitMap('motor_speed.value_0') = '-';

    % Electrical
    unitMap('electrical_voltage.voltage_V') = 'V';
    unitMap('electrical_current.current_A') = 'A';
    unitMap('electrical_power.power_W')     = 'W';

    % GPS
    unitMap('gps_fix.latitude')  = 'deg';
    unitMap('gps_fix.longitude') = 'deg';
    unitMap('gps_fix.altitude')  = 'm';

    % Odom Velocity (raw)
    unitMap('odom_velocity.vx')  = 'm/s';
    unitMap('odom_velocity.vy')  = 'm/s';
    unitMap('odom_velocity.mag') = 'm/s';

    % Odom Velocity (filtered)
    unitMap('odom_velocity_filtered.vx')  = 'm/s';
    unitMap('odom_velocity_filtered.vy')  = 'm/s';
    unitMap('odom_velocity_filtered.mag') = 'm/s';

end
