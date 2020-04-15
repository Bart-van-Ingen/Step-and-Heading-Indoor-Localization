function [Acceleration, step_detection] = stepDetection(target)

% determine which import to use depending on file extension
[~, ~, fExt] = fileparts(target.file.name);
switch lower(fExt)
    case '.csv'
        Acceleration = CSVFile2Timetable(target);
    case '.json'
        Acceleration = JSONFile2Timetable(target);
    otherwise
        error('Unexpected file extension: %s', fExt);
end
disp(['dataset size is:' int2str(height(Acceleration)) ' rows']);
% Acceleration = JSONFile2Timetable(person1_test_path1);
disp('     import data')

%% create timetable for processed data
step_detection = timetable(Acceleration.Time);

%% optimal settings according to salvi et al

% filtering
filt_window_size = 13;
filt_type = 'gaussian';
filt_std = 0.35;
filt_cutoff_freq = 3; % Hz
filt_cutoff_gain = -60; %dB

% scoring
score_type = 'mean difference';
score_window_size = 35;

% detection
detect_threshold = 1;

% post-processing
pp_window_t = 0.200; %s

%% preprocessing: generate the norm of the acceleration signal
% TODO: interpolation to get constant sampling time
disp('     calculate norm')
step_detection.acc0_magnitude = sqrt(Acceleration.X.^2 + Acceleration.Y.^2 + ...
    Acceleration.Z.^2);

%% Threshold on standard deviation of 
disp('     apply threshold on standard deviation')
step_detection.acc0_magnitude_thres = NaN(height(step_detection),1);
step_detection.acc0_magnitude_std = NaN(height(step_detection),1);

step_detection.acc0_magnitude_std = movstd(step_detection.acc0_magnitude,70);

threshold_row_index = step_detection.acc0_magnitude_std > 0.6;
threshold_rows = step_detection(threshold_row_index,:);

step_detection.acc0_magnitude_thres = step_detection.acc0_magnitude .* threshold_row_index;

%% Filter Convolution process
disp('     Apply gaussian filter')
gauss_window = gaussianWindow(filt_window_size, filt_std);
gauss_sum = sum(gauss_window);
kernel = transpose(gauss_window./gauss_sum);
conv_gauss_filter = conv(step_detection.acc0_magnitude_thres, kernel, 'same');
step_detection.acc1_conv_gauss = conv_gauss_filter;

%% Scor convolution process
disp('     Apply scoring')
score_middle_index = round(score_window_size/2);

kernel1 = ones(score_window_size,1).*(-1/(score_window_size - 1));
kernel1(score_middle_index,1) = 1;
conv_score = conv(step_detection.acc1_conv_gauss, kernel1, 'same');

step_detection.acc2_conv_score = conv_score;

%% Detection stage:
disp('     Detect peaks')
% Detecting outliers with builtin matlab methods
step_detection.acc3_quick_detect = NaN(height(step_detection),1);

cum_moving_mean = movmean(step_detection.acc2_conv_score, [length(step_detection.acc2_conv_score)-1 0]);
cum_moving_std = movstd(step_detection.acc2_conv_score, [length(step_detection.acc2_conv_score)-1 0]);

cum_detect_score_row_index = (step_detection.acc2_conv_score - cum_moving_mean) > ...
                    cum_moving_std .* detect_threshold;
                
threshold_rows = step_detection(cum_detect_score_row_index,:);
step_detection(threshold_rows.Time,:).acc3_quick_detect = threshold_rows.acc1_conv_gauss;

%% find local maxima through sliding window
disp('     Find local maxima')
step_detection.acc4_builtin_max = NaN(height(step_detection),1);

builtinmax = islocalmax(step_detection.acc3_quick_detect,'MinSeparation',seconds(pp_window_t), ...
                        'SamplePoints',step_detection.Time);

threshold_row_index = step_detection.acc0_magnitude_std > 0.6;
local_max_rows = step_detection(builtinmax,:);
step_detection(local_max_rows.Time,:).acc4_builtin_max = local_max_rows.acc3_quick_detect;

