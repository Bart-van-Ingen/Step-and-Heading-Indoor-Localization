clc
close all
clear all

gt2algo_comparisons = [];

path.path  = '/home/vaningen/MEGAsync/MSc Sensor Fusion Thesis/Code and Datasets/Online Code/oxford step counter/validation/';
path.time_unit = 1E-9;

gt_sd_datasets = dir(strcat(path.path,'/*.csv'));
%
for gt_sd_dataset = gt_sd_datasets'

file.directory = [gt_sd_dataset.folder '/'] ;
file.name = gt_sd_dataset.name;

target.file = file;
target.dataSetProp = DataSetProp("Accelerometer","Time",(path.time_unit), ...
    ["X","Y","Z","algo_step_detect","truth_step_detect"]);

sd.name = file.name;

[sd.matlab_algo_steps, sd.Acceleration, sd.sd_components] = stepDetection(target, 'file', false);

sd.sd_comparison = createTimeSeriesCompare(sd.Acceleration, sd.matlab_algo_steps.data);

% find the step time series of android and ground truth 
sd.android_algo_steps = findSteps(sd.sd_comparison.sd_android_algo_points, sd.Acceleration);
sd.ground_truth_steps = findSteps(sd.sd_comparison.sd_ground_truth_points, sd.Acceleration);

for result_index = 1 : 25
    debugDisp([ gt_sd_dataset.name "- delta_t: " result_index], true)
    delta_t = result_index * 0.02; 
    matlab_pseudo_confusion(result_index) = TpFpFnCalc(sd.matlab_algo_steps.data, sd.ground_truth_steps.data,delta_t);
    android_pseudo_confusion(result_index) = TpFpFnCalc(sd.android_algo_steps.data, sd.ground_truth_steps.data,delta_t);
end

sd.matlab_pseudo_confusion = matlab_pseudo_confusion;
sd.android_pseudo_confusion = android_pseudo_confusion;

gt2algo_comparisons = [gt2algo_comparisons; sd];

end
%% Absolute number of steps detected

bar_comp_data = [];
bar_names = {};
n = 0;
figure(1)
for comparison = gt2algo_comparisons'
   n = n + 1;
   % formatting name for nice plotting by replacing _ with space
   name_format = strrep(comparison.name,'_',' ');
   
   %cut the string at the char 5 so that date info is not seen in plot
   name = strsplit(name_format,'5');
   
   %only use the name
   bar_names(n) = {name{1}(1:end-2)}; 
   bar_comp_data = [ bar_comp_data; comparison.ground_truth_steps.nr_steps, comparison.matlab_algo_steps.nr_steps, ...
                comparison.android_algo_steps.nr_steps];    
end
bar_names = categorical(bar_names);
bar(bar_names,bar_comp_data)
ylabel('number of steps')
title('step counting comparison') 
legend('ground truth','matlab algorithm','android algorithm')

% step counting percentual accuracy

bar_comp_data = [];
bar_names = {};
n = 0;
figure(2)
for comparison = gt2algo_comparisons'
   n = n + 1;
   % formatting name for nice plotting
   name = strsplit(strrep(comparison.name,'_',' '),'5');
   bar_names(n) = {name{1}(1:end-2)}; 
   
   %grouping dataset together
   bar_comp_data = [ bar_comp_data;  ... 
                (comparison.matlab_algo_steps.nr_steps - comparison.ground_truth_steps.nr_steps)./comparison.ground_truth_steps.nr_steps *100, ...
                (comparison.android_algo_steps.nr_steps -comparison.ground_truth_steps.nr_steps)./comparison.ground_truth_steps.nr_steps * 100];    
end
bar_names = categorical(bar_names);
bar(bar_names,bar_comp_data)
ylabel('percentage error (%)')
title("step counting error") 
legend('matlab algorithm','android algorithm')

%% absolute true positives
bar_comp_data = [];
bar_names = {};
n = 0;
figure()
for comparison = gt2algo_comparisons'
    n = n + 1;
   % formatting name for nice plotting
   name = strsplit(strrep(comparison.name,'_',' '),'5');
   bar_names(n) = {name{1}(1:end-2)}; 
   
   %grouping dataset together
   bar_comp_data = [ bar_comp_data; max([comparison.matlab_pseudo_confusion.true_positive]), ...
                                    max([comparison.android_pseudo_confusion.true_positive]), ...
                                    comparison.ground_truth_steps.nr_steps ];    

end
bar_names = categorical(bar_names);
bar(bar_names,bar_comp_data)
ylabel('number of steps')
title("step true positives compared to ground truth detection") 
legend('matlab algorithm true positives','android algorithm true positives','ground truth detection')

%% percentual true positives
bar_comp_data = [];
max_matlab_tp_delta_t_table = [];
max_android_tp_delta_t_table = [];
bar_names = {};
n = 0;
figure()
for comparison = gt2algo_comparisons'
    n = n + 1;
   % formatting name for nice plotting
   name = strsplit(strrep(comparison.name,'_',' '),'5');
   bar_names(n) = {name{1}(1:end-2)}; 
   
   [max_matlab_tp, max_matlab_tp_index] = max([comparison.matlab_pseudo_confusion.true_positive],[],2,'linear');
   [max_android_tp, max_android_tp_index] = max([comparison.android_pseudo_confusion.true_positive],[],2,'linear');
   
   max_matlab_tp_delta_t = comparison.matlab_pseudo_confusion(max_matlab_tp_index).delta_t;
   max_matlab_tp_delta_t_table = [max_matlab_tp_delta_t_table, max_matlab_tp_delta_t];
   
   max_android_tp_delta_t = comparison.matlab_pseudo_confusion(max_android_tp_index).delta_t;
   max_android_tp_delta_t_table = [max_android_tp_delta_t_table, max_android_tp_delta_t];
   
   %grouping dataset together
   bar_comp_data = [ bar_comp_data; ( max_matlab_tp - comparison.ground_truth_steps.nr_steps)/comparison.ground_truth_steps.nr_steps*100, ...
                                    (max_android_tp - comparison.ground_truth_steps.nr_steps)/comparison.ground_truth_steps.nr_steps*100, ...
                                    ];    

end
bar_names = categorical(bar_names);
b = bar(bar_names,bar_comp_data);

xtips1 = b(1).XEndPoints;
ytips1 = b(1).YEndPoints;
labels1 = string(max_matlab_tp_delta_t_table);
text(xtips1,ytips1,labels1,'HorizontalAlignment','center',...
    'VerticalAlignment','top')

xtips2 = b(2).XEndPoints;
ytips2 = b(2).YEndPoints;
labels2 = string(max_android_tp_delta_t_table);
text(xtips2,ytips2,labels2,'HorizontalAlignment','center',...
    'VerticalAlignment','top')

ylabel('percent error from ground truth (%)')
title("step true positives error compared to ground truth detection") 
legend('matlab algorithm true positives','android algorithm true positives')

%%
figure()
hold on
plot([pseudo_confusion.delta_t], [pseudo_confusion.true_positive]);
plot([pseudo_confusion.delta_t], [pseudo_confusion.false_negative]);
plot([pseudo_confusion.delta_t], [pseudo_confusion.false_positive]);
hold off
% title('unique matlab step to ground truth step link

%%

figure()
plot(sd_components.Time, sd_components.acc0_magnitude)
hold on
scatter(algo_steps.Time, algo_steps.acc0_magnitude)
scatter(truth_steps.Time, truth_steps.acc0_magnitude)
legend('acceleration norm','matlab algo','ground truth')
hold off

%%

diff_truth = diff(comparison.ground_truth_steps.data.Time);
figure()
% histogram(diff_truth)
plot(diff_truth)
title('truth diff')

diff_matalgo = diff(comparison.matlab_algo_steps.data.Time);
figure()
% histogram(diff_matalgo)
plot(diff_matalgo)
title('matlab diff')

diff_algo = diff(comparison.android_algo_steps.data.Time);
figure()
% histogram(diff_algo)
plot(diff_algo)
title('algo diff')

spreadfigures

%%
stackedplot(diff_truth, diff_matalgo, diff_algo)