%% AutoNav Data Analysis 
clear;clc;close all;

basePath = fileparts(mfilename('fullpath')); %filepath of this file on user's device
helperPath = fullfile(basePath, 'HelperFunctions');   % Helper Functions
dataPath = fullfile(basePath, 'TestingData');         % Path for Data
addpath(genpath(helperPath));
addpath(genpath(dataPath));

% Load the dataset for analysis
%data = parse_log('GPSTestingLog.txt');
%data = parse_log('t002_20251112_160708.csv');
data = parse_log('t002_20251114_171257.csv');

data = clean_log(data); 
%Plot Results
%plotGPS(data.gps_fix)
%plot_odom(data.odom);
%plot_cmd_vel(data.cmd_vel)
plot_imu(data.zed_zed_node_imu_data);

% % 
 [odom_vel, imu_vel, enc_vel] = getVelocities(data);
 plotVelocities(odom_vel, imu_vel, enc_vel);
% 
% plot_encoder_count(data.encoders)

