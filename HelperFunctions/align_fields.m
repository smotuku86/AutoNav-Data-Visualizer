function [xAligned, yAligned] = align_fields(xData, xTime, yData, yTime, method)
%ALIGN_FIELDS Align two data vectors from different topics onto a common time grid.
%   [xAligned, yAligned] = align_fields(xData, xTime, yData, yTime)
%   [xAligned, yAligned] = align_fields(xData, xTime, yData, yTime, method)
%
%   When X and Y come from different ROS2 topics with different sample
%   rates and timestamps, this function interpolates Y onto X's time grid
%   using interp1, then strips NaN edges from both vectors.
%
%   Inputs:
%       xData  - column vector of X-axis data values
%       xTime  - column vector of timestamps for xData
%       yData  - column vector of Y-axis data values
%       yTime  - column vector of timestamps for yData
%       method - interpolation method for interp1 (default: 'linear')
%
%   Outputs:
%       xAligned - X data with NaN rows removed
%       yAligned - Y data interpolated onto X's time grid, NaN rows removed

    if nargin < 5
        method = 'linear';
    end

    % Interpolate Y data onto X's time grid
    yInterp = interp1(yTime, yData, xTime, method, NaN);

    % Remove rows where either X or interpolated Y is NaN
    valid = ~isnan(xData) & ~isnan(yInterp);
    xAligned = xData(valid);
    yAligned = yInterp(valid);

end
