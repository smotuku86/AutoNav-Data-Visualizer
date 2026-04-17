# AutoNav Data Visualizer System

MATLAB toolbox for visualizing ROS2 log data from the VT AutoNav robot. Designed to work in conjunction with the `AutoNav Automated Testing and Data Aquisition System` which outputs CSV files that can be pulled apart and processed here.

## Getting Started

1. Open `AutoNavDataAnalysis.prj` in MATLAB to add all paths
2. Launch either app from the `App/` folder
3. `TestingGUI.m` is a legacy GUI interface.
4. `DataVisualizer.m` is a flexible GUI interface.

## Apps

| App | Description |
|-----|-------------|
| **TestingGUI** | Predefined plot layouts — select topics and view standard plots |
| **DataVisualizer** | Drag-and-drop subplot builder with configurable grid, labels, and transforms |

### DataVisualizer Features

- **Drag-and-drop** fields onto subplots (X/Y axes, dual Y-axis for mixed units)
- **Special plots:** GPS (satellite map), Odometry path, Odom GPS-aligned (North/East), CMD Vel, Electrical, IMU
- **Transforms:** FFT, Filter (Butterworth/FFT-based), Bode TF estimation (H1), Bode Single
- **IMU orientation correction** — auto-detects mounting angle from gravity, rotates to robot frame
- **Transform chaining** — filter outputs can feed into FFT or Bode via output bubbles
- **Custom labels/titles** per subplot, toggleable units and labels

## Data Pipeline

```
CSV (ROS2 log) → parse_log() → clean_log() → LogData struct
```

- `parse_log` reads CSV into nested struct: `data.topic.field` (column vectors, `.time` on each topic)
- `clean_log` converts odom quaternions to yaw, offsets odom/encoders to zero at t=0

## Retrieving Data

From your computer (not the container or Jetson):

```
scp -r jetson:~/AutoNav_25-26/logs ~/Downloads/logs
```

Requires `jetson` configured in `~/.ssh/config`. Refer to the main GitHub repo AutoNav_25-26 for information on how to get this ssh config set up if not already done.

## Project Structure

```
App/                  GUI apps (TestingGUI, DataVisualizer)
App/html/             uihtml interface for drag-and-drop
HelperFunctions/      parse_log, clean_log, plot functions, align_fields, transform_imu
TestingData/          Sample CSV logs from tests completed throughout the semester.
```
