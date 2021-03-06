function pos_data = importVideoGroundTruth(filename, dataLines)
%IMPORTFILE Import data from a text file
%  LOPEN1 = IMPORTFILE(FILENAME) reads data from text file FILENAME for
%  the default selection.  Returns the data as a table.
%
%  LOPEN1 = IMPORTFILE(FILE, DATALINES) reads data for the specified row
%  interval(s) of text file FILENAME. Specify DATALINES as a positive
%  scalar integer or a N-by-2 array of positive scalar integers for
%  dis-contiguous row intervals.
%
%  Example:
%  lopen1 = importfile("/home/vaningen/MEGAsync/MSc Sensor Fusion Thesis/Code and Datasets/SHS Code/particle filter/lopen1.2_gt_from_video.csv", [3, Inf]);
%
%  See also READTABLE.
%
% Auto-generated by MATLAB on 29-Oct-2020 14:31:21

%% Input handling

% If dataLines is not specified, define defaults
if nargin < 2
    dataLines = [3, Inf];
end

%% Setup the Import Options and import the data
opts = delimitedTextImportOptions("NumVariables", 3);

% Specify range and delimiter
opts.DataLines = dataLines;
opts.Delimiter = ",";

% Specify column names and types
opts.VariableNames = ["time", "x", "y"];
opts.VariableTypes = ["double", "double", "double"];

% Specify file level properties
opts.ExtraColumnsRule = "ignore";
opts.EmptyLineRule = "read";

% Import the data
pos_data = readtable(filename, opts);
pos_data.time = seconds(pos_data.time);
pos_data = table2timetable(pos_data);

end