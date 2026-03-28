function plotVelocities(odom_vel, imu_vel, enc_vel)
    figure('Name','Velocities','Color','w');

    % Store line handles
    h = struct();

    % ===============================
    % === Top subplot: X/Y/etc. ===
    % ===============================
    ax1 = subplot(2,1,1);
    hold(ax1,'on');

    if isfield(odom_vel,'x')
        h.odomX = plot(ax1, odom_vel.time, odom_vel.x, 'b', 'DisplayName','Odom X');
        h.odomY = plot(ax1, odom_vel.time, odom_vel.y, 'r', 'DisplayName','Odom Y');
    end
    if isfield(imu_vel,'x')
        h.imuX = plot(ax1, imu_vel.time, imu_vel.x, '--b', 'DisplayName','IMU X');
        h.imuY = plot(ax1, imu_vel.time, imu_vel.y, '--r', 'DisplayName','IMU Y');
    end
    if isfield(enc_vel,'left')
        h.encLeft  = plot(ax1, enc_vel.time, enc_vel.left,  'g', 'DisplayName','Enc Left');
        h.encRight = plot(ax1, enc_vel.time, enc_vel.right, 'm', 'DisplayName','Enc Right');
    end

    grid on;
    xlabel('Time (s)');
    ylabel('Velocity');
    title('Velocity Components');
    legend('show');

    % ==============================
    % === Bottom subplot: Mag. ===
    % ==============================
    ax2 = subplot(2,1,2);
    hold(ax2,'on');

    if isfield(odom_vel,'mag')
        h.odomMag = plot(ax2, odom_vel.time, odom_vel.mag, 'k', 'DisplayName','Odom Mag');
    end
    if isfield(imu_vel,'mag')
        h.imuMag = plot(ax2, imu_vel.time, imu_vel.mag, '--k', 'DisplayName','IMU Mag');
    end
    if isfield(enc_vel,'left')
        enc_mag = sqrt(enc_vel.left.^2 + enc_vel.right.^2);
        h.encMag = plot(ax2, enc_vel.time, enc_mag, ':k', 'DisplayName','Enc Mag');
    end

    grid on;
    xlabel('Time (s)');
    ylabel('Velocity Magnitude');
    title('Velocity Magnitude');
    legend('show');


    % =======================
    % === Toggle panel ===
    % =======================
    cbPanel = uipanel('Title','Toggle Lines','FontSize',10, ...
                      'Position',[0.91 0.05 0.08 0.9]);

    % Lines shown by default
    defaultOn = {'odomX', 'odomY', 'odomMag'};

    fields = fieldnames(h);
    n = numel(fields);

    for k = 1:n
        isOn = ismember(fields{k}, defaultOn);
        if ~isOn
            h.(fields{k}).Visible = 'off';
        end
        uicontrol('Parent', cbPanel, ...
                  'Style', 'checkbox', ...
                  'String', fields{k}, ...
                  'Value', isOn, ...
                  'Units','normalized', ...
                  'Position',[0.05 1 - k*0.06 0.9 0.05], ...
                  'Callback', @(src,~) toggleLine(h.(fields{k}), src.Value));
    end

    % Rescale axes to visible lines only
    autoscaleAxes(ax1);
    autoscaleAxes(ax2);


    % ============================================
    % === Toggle function (with auto-rescale) ===
    % ============================================
    function toggleLine(lineObj, val)
        if val
            lineObj.Visible = 'on';
        else
            lineObj.Visible = 'off';
        end

        ax = ancestor(lineObj,'axes');  % get parent axes
        autoscaleAxes(ax);
    end


    % ======================================
    % === Autoscale helper function     ===
    % ======================================
    function autoscaleAxes(ax)
        visibleLines = findobj(ax, 'Type','line','Visible','on');

        if isempty(visibleLines)
            return;
        end

        xdata = get(visibleLines,'XData');
        ydata = get(visibleLines,'YData');

        % Ensure cell arrays
        if ~iscell(xdata), xdata = {xdata}; end
        if ~iscell(ydata), ydata = {ydata}; end

        % Compute bounds
        xMin = min(cellfun(@(v) min(v(:)), xdata));
        xMax = max(cellfun(@(v) max(v(:)), xdata));
        yMin = min(cellfun(@(v) min(v(:)), ydata));
        yMax = max(cellfun(@(v) max(v(:)), ydata));

        axis(ax, [xMin xMax yMin yMax]);
    end

end
