%% step detection and counting - windowed peak detection
%salvi et al approach

close all
clear all

data_directory = '/home/vaningen/MEGAsync/MSc Sensor Fusion Thesis/Datasets/';
log_name = 'HIMU-2020-03-24_18-58-04.csv';

Acceleration = importHyperImuFile(strcat(data_directory, log_name));
Acceleration.Properties.VariableNames = ["X","Y","Z"];
disp('done importing')

%% plotting the raw data
figure(1)
s1 = stackedplot(Acceleration);
title('3-axis raw accelerometer data for 8 steps')

%% create timetable for processed data
step_detection = timetable(Acceleration.timestamp);

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
detect_threshold = 1.2;

% post-processing
pp_window_t = 0.200; %s

%% preprocessing: generate the norm of the acceleration signal
% TODO: interpolation to get constant sampling time
disp('calculating norm')
step_detection.acc0_magnitude = sqrt(Acceleration.X.^2 + Acceleration.Y.^2 + ...
    Acceleration.Z.^2);

%% filtering:
% TODO: they reference low pass filter with 3 Hz cut off frequency
% but do not use it for the gaussian filter

disp('filtering norm')

filtering_window = Queue();
gauss_window = gaussianWindow(filt_window_size, filt_std);
gauss_sum = sum(gauss_window);
filt_middle_index = round(filt_window_size/2);

% initialize column for data collection
step_detection.acc1_gauss = NaN(height(step_detection),1);

filt_queue_size = [];

for n = 1:1:height(step_detection)
    
    dp_gauss = step_detection(n,:);
    filtering_window.enqueue(dp_gauss);
    
    filt_queue_size = [filt_queue_size,filtering_window.getLength()];
    
    if (filtering_window.getLength() == filt_window_size)
        
        ssum = 0;
        
        for window_index = 1: filt_window_size
            dp_window_mag = filtering_window.elements(window_index,:).acc0_magnitude;
            ssum = ssum +  dp_window_mag.* gauss_window(window_index);
        end
        
        dp_middle= filtering_window.elements(filt_middle_index,:);
        step_detection(dp_middle.Time,:).acc1_gauss = ssum/gauss_sum;
        filtering_window.dequeue();
    end
end

%% scoring

disp('applying scoring')

scoring_window = Queue();
score_middle_index = round(score_window_size/2);

step_detection.acc2_score = NaN(height(step_detection),1);

score_queue_size = [];

for n = 1:1:height(step_detection)
    
    dp_score = step_detection(n,:);
    scoring_window.enqueue(dp_score);
    
    score_queue_size = [score_queue_size,scoring_window.getLength()];
    
    if (scoring_window.getLength() == score_window_size)
        
        middle_data_point = scoring_window.elements(score_middle_index,:);
        
        diff_left = 0;
        diff_right = 0;
        
        % find total difference on the left
        for window_index = 1: score_middle_index - 1
            
            value = middle_data_point.acc1_gauss - ...
                scoring_window.elements(window_index,:).acc1_gauss;
            
            diff_left = diff_left + value;
        end
        
        % find total difference on the right
        for window_index = score_middle_index + 1 : score_window_size
            
            value = middle_data_point.acc1_gauss - ...
                scoring_window.elements(window_index,:).acc1_gauss;
            
            diff_right = diff_right + value;
        end
        
        % calculate peak score and create a new point
        avg = (diff_left + diff_right)/(score_window_size -1);
        
        step_detection(middle_data_point.Time,:).acc2_score = avg ;
        scoring_window.dequeue();
    end
end

%% Detection stage:

disp('detecting peaks')

n = 0;
step_detection.acc3_detect = NaN(height(step_detection),1);

for data_index = 1:1:height(step_detection)
    
    dp_detect = step_detection(data_index,:);
    
    detect_score = dp_detect.acc2_score;
    
    if  not(isnan(detect_score))
        
        n = n + 1;
        
        if n == 1
            detect_mean = detect_score;
            detect_std = 0;
            
        elseif n == 2
            det_o_mean = detect_mean;
            detect_mean = (detect_score + detect_mean)/2;
            detect_std = sqrt( ...
                ((detect_score - detect_mean)^2 + ...
                (det_o_mean - detect_mean)^2) / 2 ...
                );
        else
            det_o_mean = detect_mean;
            detect_mean = (detect_score + (n - 1)*detect_mean) / n;
            detect_std = sqrt(((n - 2) * detect_std^2 / (n - 1)) + ...
                (det_o_mean - detect_mean)^2 + ...
                (detect_score - detect_mean)^2 / n);
        end
        
        if n > 15
            if (detect_score - detect_mean) > detect_std * detect_threshold
                step_detection(dp_detect.Time,:).acc3_detect = ...
                    step_detection(dp_detect.Time,:).acc1_gauss;
            end
        end
    end
end

%% finding local minimum through sliding window

disp('finding maximums')

n = 0;
slidding_window = [];
step_detection.acc4_max = NaN(height(step_detection),1);

for data_index = 1:1:height(step_detection)
    
    dp_max = step_detection(data_index,:);
    
    if  not(isnan(dp_max.acc3_detect))
        n = n + 1;
        
        if n == 1
            local_max = dp_max;
            
        else
            if dp_max.Time - local_max.Time > seconds(pp_window_t)
                step_detection(local_max.Time,:).acc4_max = local_max.acc3_detect;
                local_max = dp_max;
                slidding_window = [slidding_window, dp_max.Time];
            else
                if dp_max.acc3_detect >= local_max.acc3_detect
                    local_max = dp_max;
                end
            end
        end
    elseif(data_index == height(step_detection))
        step_detection(local_max.Time,:).acc4_max = local_max.acc3_detect;
    end
end

%%
close all
figure(4)
hax=axes;

hold on
plot(step_detection.Time,step_detection.acc1_gauss)
scatter(step_detection.Time,step_detection.acc4_max)

% for i = 1:length(slidding_window)
%     line([slidding_window(i) slidding_window(i)],get(hax,'YLim'),'Color',[1 0 0])
% end
hold off
%%
stackedplot(step_detection)
