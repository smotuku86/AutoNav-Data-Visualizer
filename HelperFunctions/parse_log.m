function data = parse_log(filename)
% Read file as text lines
fid = fopen(filename, 'r');
if fid == -1
    error('Could not open file: %s', filename);
end
lines = textscan(fid, '%s', 'Delimiter', '\n');
fclose(fid);
lines = lines{1};

% Skip header if present
if startsWith(lines{1}, 'ROS2_Clock')
    lines(1) = [];
end

data = struct(); % initialize output
seen_keys = containers.Map('KeyType','char','ValueType','logical');

t0_global = NaN; % first timestamp in seconds (for relative time)

for i = 1:length(lines)
    line = strtrim(lines{i});
    if isempty(line)
        continue;
    end

    % Split line into comma-separated parts (respecting quotes)
    parts = regexp(line, '(?<=^|\s|,)"[^"]*"|[^,]+', 'match');
    if numel(parts) < 4
        continue; % malformed line
    end

    % Timestamp string
    ts_str = parts{1};
    ts_num = str2double(ts_str); % convert to numeric
    if isnan(ts_num)
        continue; % skip malformed timestamp
    end

    % Convert nanoseconds -> seconds
    time_sec = ts_num / 1e9;

    % Set global start time
    if isnan(t0_global)
        t0_global = time_sec;
    end

    % Relative time since start
    time_sec = time_sec - t0_global;

    % Extract topic and identifiers
    topic_raw = strrep(parts{2}, '"', '');
    identifiers = strsplit(strrep(parts{3}, '"', ''), ',');

    % Convert values to numbers
    values = str2double(parts(4:end));

    % Clean topic name for struct field
    topic_name = strrep(topic_raw, '/', '_');
    topic_name = regexprep(topic_name, '^_+', '');

    % Build unique key (topic + timestamp string)
    key = sprintf('%s_%s', topic_name, ts_str);

    % Skip duplicates
    if isKey(seen_keys, key)
        continue;
    end
    seen_keys(key) = true;

    % Initialize topic struct if needed
    if ~isfield(data, topic_name)
        data.(topic_name) = struct();
        data.(topic_name).time = [];
        for id = 1:numel(identifiers)
            field = matlab.lang.makeValidName(identifiers{id});
            data.(topic_name).(field) = [];
        end
    end

    % Append new row
    data.(topic_name).time(end+1,1) = time_sec;
    for j = 1:length(identifiers)
        field = matlab.lang.makeValidName(identifiers{j});
        if j <= numel(values)
            data.(topic_name).(field)(end+1,1) = values(j);
        else
            data.(topic_name).(field)(end+1,1) = NaN;
        end
    end
end
end
