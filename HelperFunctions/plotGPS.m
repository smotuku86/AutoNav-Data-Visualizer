function [] = plotGPS(GPS_data)

    % Ensure inputs are column vectors of doubles
    latitudes = double(GPS_data.latitude(:));
    longitudes = double(GPS_data.longitude(:));
    altitudes = double(GPS_data.altitude(:));

    % Compute bounding box
    minLat = min(latitudes);
    maxLat = max(latitudes);
    minLon = min(longitudes);
    maxLon = max(longitudes);

    % Add buffer
    BufferSize = 0.005;
    LatSize = maxLat - minLat;
    LonSize = maxLon - minLon;

    if (LatSize == 0)
        LatSize = .0005;
    end
    if (LonSize == 0)
        LonSize = .0005;
    end

    minLon = minLon - LonSize*BufferSize;
    maxLon = maxLon + LonSize*BufferSize;
    minLat = minLat - LatSize*BufferSize;
    maxLat = maxLat + LatSize*BufferSize;

    % Clean altitudes
    altitudes = reshape(altitudes, [], 1);
    if any(isnan(altitudes))
        altitudes = fillmissing(altitudes, 'linear');
    end

    % Altitude scale
    cmin = min(altitudes);
    cmax = max(altitudes);

    if cmin == cmax
        cmin = cmin - 1;
        cmax = cmax + 1;
    end

    % Create geographic axes
    figure('Name','GPS','Color','w');
    gx = geoaxes;
    geobasemap(gx, 'satellite');
    geolimits(gx, [minLat maxLat], [minLon maxLon]);
    hold(gx, 'on');

    % Scatter plot colored by altitude
    cmap = parula(256);
    scatterHandle = geoscatter(gx, latitudes, longitudes, 25, altitudes, 'filled');

    % Apply colormap + limits
    colormap(gx, cmap);
    caxis(gx, [cmin cmax]);

    % Add colorbar
    cb = colorbar;
    ylabel(cb, 'Altitude [m]');

    title(gx, 'GPS Points Colored by Altitude');

    hold(gx, 'off');
end
