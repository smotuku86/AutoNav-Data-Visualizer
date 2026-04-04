function plot_encoder_count(encoders)
%PLOT_ENCODER Plot left and right wheel encoder counts over time.
%
%   plot_Encoder(encoder)
%   Plots the encoder counts for the left and right wheels as a function of time.
%
%   Input:
%       encoder - A struct with the following required fields:
%           encoders.time           : Time vector (in seconds)
%           encoders.encoder_left    : Left encoder counts
%           encoders.encoder_right   : Right encoder counts
%
%   Example:
%       data = parse_log('ExampleLog.txt');
%       plot_Encoder(data.encoder);

    % --- Validate input structure ---
    if ~isfield(encoders, 'encoder_left') || ~isfield(encoders, 'encoder_right') || ~isfield(encoders, 'time')
        error('Input struct must contain fields: time, encoder_left, and encoder_right.');
    end
    
    % --- Extract data ---
    time = encoders.time;
    left_encoder_reading = encoders.encoder_left;
    right_encoder_reading = encoders.encoder_right;

    % --- Plot encoder data ---
    figure('Name','Encoder Data','Color','w');
    hold on;
    plot(time, left_encoder_reading, 'b-', 'LineWidth', 1.5); 
    plot(time, right_encoder_reading, 'r-', 'LineWidth', 1.5);
    
    % --- Format plot ---
    xlabel('Time [s]');
    ylabel('Encoder Count [-]');
    title('Encoder Counts Over Time');
    legend({'Left Encoder', 'Right Encoder'});
    grid on;
    hold off;
end
