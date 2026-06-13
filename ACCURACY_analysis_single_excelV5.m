clear; clc; close all;

%% ===================== SETTINGS =====================
% Path layout: <root>/code (scripts), <root>/data (workbook), <root>/output (figures).
% Falls back to a flat layout with the workbook next to this script.
thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir); thisDir = pwd; end
rootDir = fileparts(thisDir);
DATA_NAME = 'Fish_Data_Updated_with_2ACT2P_V2.xlsx';
if isfile(fullfile(rootDir, 'data', DATA_NAME))
    EXCEL_FILE  = fullfile(rootDir, 'data', DATA_NAME);
    OUTPUT_ROOT = fullfile(rootDir, 'output');
elseif isfile(fullfile(thisDir, DATA_NAME))
    EXCEL_FILE  = fullfile(thisDir, DATA_NAME);
    OUTPUT_ROOT = fullfile(thisDir, 'output');
else
    error('Data workbook %s not found in ../data or next to the script.', DATA_NAME);
end

WIN       = 15;    % half-window: +/-15 = 31 trials centered
saveDir   = fullfile(OUTPUT_ROOT, "FIGURE 1");
dpi       = 600;
SAVE_FIG  = true;
SAVE_JPG  = true;
SAVE_TIF  = true;
SAVE_PDF  = true;

%% ===================== Fish numbering =====================
% Fish 1-5: 2ACT2P group; Fish 6-11: shape group; Fish 12-14: abstract shape group
fishNames = ["1","2","3","4","5","6","7","8","9","10","11","12","13","14"];
nFish = numel(fishNames);
displayLabel = strings(1, nFish);
for ii = 1:nFish
    displayLabel(ii) = sprintf("Fish %d", ii);
end

%% ===================== Group membership =====================
act2pFishIDs         = [1 2 3 4 5];
shapeFishIDs         = [6 7 8 9 10 11];
abstractshapeFishIDs = [12 13 14];

PRIOR_FISH_ID  = 14;   % prior fish (fish 14)
PRIOR_NTRIALS  = 100;

y_prior_all = load_results(EXCEL_FILE, fishNames(PRIOR_FISH_ID));
nPrior = min(PRIOR_NTRIALS, numel(y_prior_all));
p_prior = mean(y_prior_all(1:nPrior));

fishPrior = nan(1, nFish);
fishPrior(PRIOR_FISH_ID) = p_prior;

%% ===================== Colors =====================
act2pFishColors = [ ...
    0.200 0.627 0.173;
    0.122 0.471 0.706;
    0.651 0.337 0.157;
    0.890 0.467 0.761;
    0.498 0.498 0.498];

shapeFishColors = [ ...
    0.850 0.325 0.098;
    0.635 0.078 0.184;
    0.929 0.694 0.125;
    0.494 0.380 0.282;
    0.466 0.674 0.188;
    0.741 0.447 0.000];

abstractshapeFishColors = [ ...
    0.00  0.447 0.741;
    0.494 0.184 0.556;
    0.301 0.745 0.933];

%% ===================== PER-FISH BAR PLOTS (one panel per fish) =====================
fprintf('\n===== PER-FISH BAR PLOTS (100-trial bins, individual panels) =====\n');

BIN_SIZE = 100;

plot_perfish_subplots(act2pFishIDs, act2pFishColors, fishNames, displayLabel, ...
    EXCEL_FILE, fishPrior, BIN_SIZE, "perfish_2act2p_fish_1_5", ...
    saveDir, dpi, SAVE_FIG, SAVE_JPG, SAVE_TIF, SAVE_PDF);

plot_perfish_subplots(shapeFishIDs, shapeFishColors, fishNames, displayLabel, ...
    EXCEL_FILE, fishPrior, BIN_SIZE, "perfish_shape_fish_6_11", ...
    saveDir, dpi, SAVE_FIG, SAVE_JPG, SAVE_TIF, SAVE_PDF);

plot_perfish_subplots(abstractshapeFishIDs, abstractshapeFishColors, fishNames, displayLabel, ...
    EXCEL_FILE, fishPrior, BIN_SIZE, "perfish_abstractshape_fish_12_14", ...
    saveDir, dpi, SAVE_FIG, SAVE_JPG, SAVE_TIF, SAVE_PDF);

fprintf('\nDone.\n');

function plot_perfish_subplots(fishIDs, fishColors, fishNames, displayLabel, ...
                               excelFile, fishPrior, binSize, fileStem, ...
                               saveDir, dpi, SAVE_FIG, SAVE_JPG, SAVE_TIF, SAVE_PDF)

    nF = numel(fishIDs);

    % --- Load all fish data and compute binned accuracy ---
    allY = cell(nF, 1);
    maxTrials = 0;
    for i = 1:nF
        allY{i} = load_results(excelFile, fishNames(fishIDs(i)));
        maxTrials = max(maxTrials, numel(allY{i}));
    end

    nBins = ceil(maxTrials / binSize);
    if nBins == 0, return; end

    % Per-fish bin accuracy and SEM
    accMatrix = nan(nBins, nF);
    semMatrix = nan(nBins, nF);
    for i = 1:nF
        fishID = fishIDs(i);
        y = allY{i};
        fp = get_prior(fishPrior, fishID);
        nT = numel(y);
        for b = 1:nBins
            t1 = (b-1)*binSize + 1;
            t2 = min(b*binSize, nT);
            if t1 > nT, break; end
            binData = y(t1:t2);
            nB = numel(binData);
            accMatrix(b, i) = normalize_acc(mean(binData), fp);
            semMatrix(b, i) = normalize_sem(std(binData)/sqrt(nB), fp);
        end
    end

    % Bin labels
    binLabels = strings(nBins, 1);
    for b = 1:nBins
        t1 = (b-1)*binSize + 1;
        t2 = b*binSize;
        binLabels(b) = sprintf("%d-%d", t1, t2);
    end

    % --- Create figure with 1 row x nF columns ---
    figW = 280 * nF;  % width scales with number of fish
    figH = 350;
    fig = figure('Name', char(fileStem), 'Color', 'w');
    set(fig, 'Units', 'pixels', 'Position', [50 100 figW figH]);

    for i = 1:nF
        ax = subplot(1, nF, i);
        hold(ax, 'on');

        % Bars for this fish
        validBins = find(~isnan(accMatrix(:, i)));
        if isempty(validBins), continue; end

        hb = bar(ax, validBins, accMatrix(validBins, i), ...
            'FaceColor', fishColors(i,:), 'EdgeColor', 'none', 'BarWidth', 0.7);

        % SEM error bars
        semVals = semMatrix(validBins, i);
        errorbar(ax, validBins, accMatrix(validBins, i), semVals, ...
            'k', 'LineStyle', 'none', 'LineWidth', 1.0, 'CapSize', 4);

        % Reference lines
        plot(ax, [0.5 nBins+0.5], [0.50 0.50], ':', 'LineWidth', 1.0, 'Color', [0.20 0.20 0.20]);
        % plot(ax, [0.5 nBins+0.5], [0.65 0.65], '-.', 'LineWidth', 1.0, 'Color', [0.20 0.20 0.20]);

        % Axes formatting
        xlim(ax, [0.5 nBins + 0.5]);
        ylim(ax, [0 1]);
        set(ax, 'XTick', 1:nBins, 'XTickLabel', binLabels, 'YTick', [0 0.5 1]);
        xtickangle(ax, 45);
        box(ax, 'off');
        set(ax, 'TickDir', 'out', 'LineWidth', 1.2, 'FontSize', 10, 'FontWeight', 'bold');

        title(ax, displayLabel(fishIDs(i)), 'FontSize', 13, 'FontWeight', 'bold');
        xlabel(ax, 'Trials', 'FontSize', 11, 'FontWeight', 'bold');

        % Only show y-label on leftmost subplot
        if i == 1
            ylabel(ax, 'Accuracy', 'FontSize', 11, 'FontWeight', 'bold');
        else
            set(ax, 'YTickLabel', []);
        end
    end

    % Link y-axes so they stay synchronized
    allAxes = findobj(fig, 'Type', 'axes');
    linkaxes(allAxes, 'y');

    save_figure(fig, saveDir, fileStem, dpi, SAVE_FIG, SAVE_JPG, SAVE_TIF, SAVE_PDF);
    fprintf('Per-fish subplot figure saved: %s (%d fish, %d bins)\n', fileStem, nF, nBins);
end

%% ===================== BAR PLOT FUNCTION (per fish, with SEM error bars) =====================

function fp = get_prior(fishPrior, fishID)
    fp = NaN;
    if fishID <= numel(fishPrior)
        fp = fishPrior(fishID);
    end
end


function acc = normalize_acc(acc, fp)
    if ~isnan(fp)
        acc = 1./ (2*(1-fp)) * acc + (1 - 1./ (2*(1-fp)));
    end
end

%% ===================== HELPER: normalize SEM by prior (same linear scale) =====================

function s = normalize_sem(s, fp)
    if ~isnan(fp)
        s = s ./ (2*(1-fp));
    end
end

%% ===================== HELPER: load results column =====================

function y = load_results(excelFile, sheetName)
    % Use readcell to avoid MATLAB renaming columns when types are mixed
    raw = readcell(excelFile, 'Sheet', sheetName);

    % Find the 'results' column in the header row
    headers = string(raw(1,:));
    resCol = find(strcmpi(headers, "results"), 1);
    if isempty(resCol)
        error("Could not find 'results' column in sheet '%s'", sheetName);
    end

    % Extract values below the header
    vals = raw(2:end, resCol);

    % Convert to numeric: 0/1 stay, letters & "NAN" strings -> NaN
    y_raw = nan(numel(vals), 1);
    for k = 1:numel(vals)
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

    valid = ~isnan(y_raw);
    y = y_raw(valid);

    if isempty(y)
        error("No valid trials after NaN removal: %s (sheet: %s)", excelFile, sheetName);
    end
    if any(~ismember(y, [0 1]))
        error("results must be 0/1 (after NaN removal): %s (sheet: %s)", excelFile, sheetName);
    end
end

%% ===================== HELPER: compute window accuracy =====================

function save_figure(fig, saveDir, fileStem, dpi, SAVE_FIG, SAVE_JPG, SAVE_TIF, SAVE_PDF)
    if ~isfolder(saveDir), mkdir(saveDir); end

    if SAVE_FIG
        savefig(fig, fullfile(saveDir, fileStem + ".fig"));
    end

    resStr = ['-r' num2str(dpi)];

    if SAVE_JPG
        fpath = fullfile(saveDir, fileStem + ".jpg");
        try
            exportgraphics(fig, fpath, 'Resolution', dpi);
        catch
            print(fig, fpath, '-djpeg', resStr);
        end
    end

    if SAVE_TIF
        fpath = fullfile(saveDir, fileStem + ".tif");
        try
            exportgraphics(fig, fpath, 'Resolution', dpi);
        catch
            print(fig, fpath, '-dtiff', resStr);
        end
    end

    if SAVE_PDF
        fpath = fullfile(saveDir, fileStem + ".pdf");
        try
            exportgraphics(fig, fpath, 'ContentType', 'vector');
        catch
            print(fig, fpath, '-dpdf', '-bestfit');
        end
    end
end
