%% ========================================================================
%  FISH_TRIAL_DETAILS.m
%  ------------------------------------------------------------------------
%  Reads the single Excel data file and reports, per fish:
%     - fish number 
%     - sheet name
%     - group (2act2p / shape / abstract shape)
%     - raw rows in the 'results' column
%     - valid trials (0/1 after NaN removal)  
%     - dropped cells (letters / NaN / blanks)
%     - # correct (1s), # incorrect (0s)
%     - overall accuracy = correct / valid
%
%  Optionally writes the table to an Excel file (see SAVE_TABLE below).
%  ========================================================================

clear; clc;

%% ===================== SETTINGS =====================
% Auto-detect the data file path 
thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir); thisDir = pwd; end
rootDir = fileparts(thisDir);
DATA_NAME = 'Fish_Data_Updated_with_2ACT2P_V2.xlsx';
% Layout: <root>/code (scripts), <root>/data (workbook), <root>/output (results).
% Falls back to a flat layout with the workbook next to the script.
if isfile(fullfile(rootDir, 'data', DATA_NAME))
    EXCEL_FILE  = fullfile(rootDir, 'data', DATA_NAME);
    OUTPUT_ROOT = fullfile(rootDir, 'output');
elseif isfile(fullfile(thisDir, DATA_NAME))
    EXCEL_FILE  = fullfile(thisDir, DATA_NAME);
    OUTPUT_ROOT = fullfile(thisDir, 'output');
else
    error('Data workbook %s not found in ../data or next to the script.', DATA_NAME);
end

% Write the resulting table to an Excel file? (saved under the output folder)
SAVE_TABLE = false;
OUT_FILE   = fullfile(OUTPUT_ROOT, 'fish_trial_details.xlsx');

%% ===================== Fish ID -> sheet-name mapping =====================
% (identical ordering to ACCURACY_analysis_single_excelV5.m)
% Fish 1-5:   2ACT2P group
% Fish 6-11:  Shape group
% Fish 12-14: Abstract shape group
fishNames = ["1","2","3","4","5","6","7","8","9","10","11","12","13","14"];

nFish = numel(fishNames);

group = strings(1, nFish);
group(1:5)   = "2act2p";
group(6:11)  = "shape";
group(12:14) = "abstract shape";

%% ===================== Sanity check on the file =====================
if ~isfile(EXCEL_FILE)
    error('Excel file not found:\n  %s', EXCEL_FILE);
end

%% ===================== Read each sheet =====================
fprintf('\nData file: %s\n\n', EXCEL_FILE);

fishNum    = (1:nFish)';
rawRows    = nan(nFish, 1);
nValid     = nan(nFish, 1);
nDropped   = nan(nFish, 1);
nCorrect   = nan(nFish, 1);
nIncorrect = nan(nFish, 1);
accuracy   = nan(nFish, 1);
status     = strings(nFish, 1);

for ii = 1:nFish
    sheet = fishNames(ii);
    try
        [y, nRaw] = read_results(EXCEL_FILE, sheet);
        rawRows(ii)    = nRaw;
        nValid(ii)     = numel(y);
        nDropped(ii)   = nRaw - numel(y);
        nCorrect(ii)   = sum(y == 1);
        nIncorrect(ii) = sum(y == 0);
        if numel(y) > 0
            accuracy(ii) = nCorrect(ii) / numel(y);
        end
        status(ii) = "ok";
    catch ME
        status(ii) = "ERROR: " + string(ME.message);
        fprintf('  WARNING: Fish %d (%s) -> %s\n', ii, sheet, status(ii));
    end
end

%% ===================== Print table to console =====================
fprintf('\n%-5s %-16s %-15s %8s %8s %8s %8s %8s %9s\n', ...
    'Fish', 'Sheet', 'Group', 'RawRows', 'Valid', 'Dropped', 'Correct', 'Incorr', 'Acc');
fprintf('%s\n', repmat('-', 1, 95));
for ii = 1:nFish
    if status(ii) == "ok"
        fprintf('%-5d %-16s %-15s %8d %8d %8d %8d %8d %9.3f\n', ...
            ii, fishNames(ii), group(ii), rawRows(ii), nValid(ii), ...
            nDropped(ii), nCorrect(ii), nIncorrect(ii), accuracy(ii));
    else
        fprintf('%-5d %-16s %-15s   --- %s\n', ii, fishNames(ii), group(ii), status(ii));
    end
end
fprintf('%s\n', repmat('-', 1, 95));

okMask = status == "ok";
fprintf('Fish read OK: %d / %d\n', sum(okMask), nFish);
fprintf('Total valid trials across all fish: %d\n', nansum(nValid));
fprintf('Mean trials per fish: %.1f   (min %d, max %d)\n\n', ...
    mean(nValid(okMask)), min(nValid(okMask)), max(nValid(okMask)));

%% ===================== Build table (and optionally save) =====================
T = table(fishNum, fishNames(:), group(:), rawRows, nValid, nDropped, ...
    nCorrect, nIncorrect, accuracy, status, ...
    'VariableNames', {'FishNumber','Sheet','Group','RawRows','ValidTrials', ...
                      'Dropped','Correct','Incorrect','Accuracy','Status'});
disp(T);

if SAVE_TABLE
    if ~isfolder(OUTPUT_ROOT); mkdir(OUTPUT_ROOT); end
    writetable(T, OUT_FILE);
    fprintf('Saved table -> %s\n\n', OUT_FILE);
end

%% ===================== HELPER: read 'results' column =====================
function [y, nRaw] = read_results(excelFile, sheetName)
    % Mirrors load_results(), but also returns the
    % raw row count and does NOT error on empty (it returns an empty vector).
    raw = readcell(excelFile, 'Sheet', sheetName);

    headers = string(raw(1,:));
    resCol = find(strcmpi(headers, "results"), 1);
    if isempty(resCol)
        error("no 'results' column");
    end

    vals = raw(2:end, resCol);
    nRaw = numel(vals);

    y_raw = nan(nRaw, 1);
    for k = 1:nRaw
        v = vals{k};
        if isnumeric(v) && ~isnan(v)
            y_raw(k) = double(v);
        elseif ischar(v) || isstring(v)
            num = str2double(string(v));
            if ~isnan(num)
                y_raw(k) = num;
            end
            % letters like C, M, S, A, "NAN" -> stay NaN
        end
    end

    y = y_raw(~isnan(y_raw));

    if ~isempty(y) && any(~ismember(y, [0 1]))
        error("results must be 0/1 after NaN removal");
    end
end
