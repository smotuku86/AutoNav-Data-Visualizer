function plot_electrical(voltage_data, current_data, power_data)
%PLOT_ELECTRICAL  Plot electrical data (voltage, current, power) vs time.
%
%   plot_electrical(voltage_data, current_data, power_data)
%   Each argument is a struct with a 'time' field and a data field,
%   or [] to skip that subplot.
%
%   Example:
%       data = parse_log('log.csv');
%       plot_electrical(data.electrical_voltage, ...
%                       data.electrical_current, ...
%                       data.electrical_power);

    figure('Name','Electrical Data','Color','w');

    % --- Voltage subplot ---
    subplot(3,1,1);
    if ~isempty(voltage_data) && isstruct(voltage_data) && isfield(voltage_data, 'time')
        plot(voltage_data.time, voltage_data.voltage, 'b-', 'LineWidth', 1.5);
        ylabel('Voltage (V)');
    else
        text(0.5, 0.5, 'No voltage data', 'HorizontalAlignment', 'center');
    end
    title('Voltage');
    xlabel('Time');
    grid on;

    % --- Current subplot ---
    subplot(3,1,2);
    if ~isempty(current_data) && isstruct(current_data) && isfield(current_data, 'time')
        plot(current_data.time, current_data.current, 'r-', 'LineWidth', 1.5);
        ylabel('Current (A)');
    else
        text(0.5, 0.5, 'No current data', 'HorizontalAlignment', 'center');
    end
    title('Current');
    xlabel('Time');
    grid on;

    % --- Power subplot ---
    subplot(3,1,3);
    if ~isempty(power_data) && isstruct(power_data) && isfield(power_data, 'time')
        plot(power_data.time, power_data.power, 'g-', 'LineWidth', 1.5);
        ylabel('Power (W)');
    else
        text(0.5, 0.5, 'No power data', 'HorizontalAlignment', 'center');
    end
    title('Power');
    xlabel('Time');
    grid on;

end
