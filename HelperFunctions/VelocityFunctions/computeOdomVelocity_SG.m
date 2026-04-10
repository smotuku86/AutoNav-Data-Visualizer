function odom_vel = computeOdomVelocity_SG(odom)
    % Check for Signal Processing Toolbox (required for sgolay)
    if ~license('test', 'Signal_Toolbox')
        error('computeOdomVelocity_SG:MissingToolbox', ...
              ['Signal Processing Toolbox is required for Savitzky-Golay filtering.\n' ...
               'Install it via the MATLAB Add-On Explorer:\n' ...
               '  Home > Add-Ons > Get Add-Ons > search "Signal Processing Toolbox"']);
    end

    t = odom.time(:);
    dt = mean(diff(t));

    % SG window & order (tunable)
    order  = 3;
    window = 11; % MUST be odd

    [~, g] = sgolay(order, window);

    % --- Smooth pos and take SG derivative for velocity ---
    % conv() flips the kernel, so negate g(:,2) to get correct sign
    vx = conv(odom.pos_x, -g(:,2), 'same') / dt;
    vy = conv(odom.pos_y, -g(:,2), 'same') / dt;

    odom_vel.x    = vx;
    odom_vel.y    = vy;
    odom_vel.mag  = sqrt(vx.^2 + vy.^2);
    odom_vel.time = t;
end