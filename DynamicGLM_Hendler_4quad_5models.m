%% Dynamic GLM Hendler - 5 Models with Optimized Sigma (Empirical Bayes)
% 9 fish total (fish 6-14).
%     Replaced all hardcoded fish counts with nFish = length(FISH_NAMES).
% =========================================================================
% Models:
%   M1: Spatial           - 4 quadrant indicator weights
%   M2: Spatial + Persist  - M1 + persistence (previous outcome) weight
%   M3: Spatial Bias       - 4 weights: +1 if animal chose q, -1 if q was
%                            an option but not chosen, 0 if not an option
%   M4: Spatial Bias + Spatial  - M3 + M1 regressors (8 weights)
%   M5: Spatial Bias + Spatial + Persist - M3 + M1 + persistence (9 weights)
%
% Sigma optimized via decoupled Laplace empirical Bayes (Ashwood et al.)
%
% KEY IMPLEMENTATION DETAILS:
%   - MAP uses JOINT Newton via block-tridiagonal solver (KxK blocks).
%     This correctly handles coupling between weights when multiple
%     regressors are nonzero per trial (e.g., spatial bias model).
%     Per-weight coordinate descent fails for coupled regressors.
%   - Inner loop uses FIXED Gaussian likelihood approximation per
%     Algorithm 1: the RHS is computed once from the MAP and kept
%     constant while sigma is updated.
%
% REQUIRES: Statistics and Machine Learning Toolbox (for perfcurve)
% =========================================================================

clear; clc; close all;

%% ========================================================================
% USER CONFIGURATION
% =========================================================================

FISH_NAMES = {'6','7','8','9','10','11','12','13','14'};
nFish = length(FISH_NAMES);

% Path configuration
thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir); thisDir = pwd; end
rootDir = fileparts(thisDir);
DATA_NAME = 'Fish_Data_Updated_with_2ACT2P_V2.xlsx';
% Layout: <root>/code (scripts), <root>/data (workbook), <root>/output (figures).
% Falls back to a flat layout with the workbook next to the scripts.
if isfile(fullfile(rootDir, 'data', DATA_NAME))
    DATA_FILE   = fullfile(rootDir, 'data', DATA_NAME);
    OUTPUT_ROOT = fullfile(rootDir, 'output');
elseif isfile(fullfile(thisDir, DATA_NAME))
    DATA_FILE   = fullfile(thisDir, DATA_NAME);
    OUTPUT_ROOT = fullfile(thisDir, 'output');
else
    error('Data workbook %s not found in ../data or next to the script.', DATA_NAME);
end
% Per-fish model outputs go to output/FIGURE 3. Each fish is a sheet named by
% its number; trial outcome is the 'results' column; target and non_target are
% read from the columns of those names.
BASE_PATH = fullfile(OUTPUT_ROOT, 'FIGURE 3');
if ~isfolder(BASE_PATH); mkdir(BASE_PATH); end

% Hyperparameter optimization settings
OPT = struct();
OPT.sigInit       = 16;
OPT.sigma0        = 1.0;
OPT.max_outer     = 20;
OPT.max_inner     = 10;
OPT.sigma_tol     = 1e-4;
OPT.map_tol       = 1e-6;
OPT.map_max_iter  = 50;
OPT.sigma_min     = 1e-4;
OPT.sigma_max     = 100;

% Model names
MODEL_NAMES = {'M1: Spatial', 'M2: Spatial+Persist', ...
               'M3: SpatBias', 'M4: SpatBias+Spatial', ...
               'M5: SpatBias+Spatial+Persist'};
MODEL_SHORT = {'M1', 'M2', 'M3', 'M4', 'M5'};

%% ========================================================================
% MAIN LOOP
% =========================================================================

fprintf('%s\n', repmat('=', 1, 70));
fprintf('DYNAMIC GLM HENDLER - 5 MODELS (Optimized Sigma)\n');
fprintf('%s\n', repmat('=', 1, 70));
for m = 1:5; fprintf('  %s\n', MODEL_NAMES{m}); end
fprintf('\n');

all_results = struct([]);

for fish_num = 1:nFish
    result = analyze_fish(fish_num, FISH_NAMES, BASE_PATH, DATA_FILE, OPT, MODEL_NAMES, MODEL_SHORT);
    if isempty(all_results)
        all_results = result;
    else
        all_results(end+1) = result; %#ok<SAGROW>
    end
end

%% ========================================================================
% CROSS-FISH SUMMARY
% =========================================================================

fprintf('\n%s\n', repmat('=', 1, 70));
fprintf('CROSS-FISH SUMMARY\n');
fprintf('%s\n', repmat('=', 1, 70));

% Print AUC table
fprintf('\n%-10s %6s %6s', 'Fish', 'N', 'Acc');
for m = 1:5; fprintf(' %8s', [MODEL_SHORT{m} '_AUC']); end
fprintf('\n%s\n', repmat('-', 1, 70));
for i = 1:length(all_results)
    r = all_results(i);
    fprintf('%-10s %6d %5.1f%%', r.fish_id, r.n_trials, r.accuracy*100);
    for m = 1:5; fprintf(' %8.3f', r.AUC(m)); end
    fprintf('\n');
end

% Print BIC table
fprintf('\n%-10s', 'Fish');
for m = 1:5; fprintf(' %10s', [MODEL_SHORT{m} '_BIC']); end
fprintf(' %8s\n', 'Best');
fprintf('%s\n', repmat('-', 1, 75));
for i = 1:length(all_results)
    r = all_results(i);
    fprintf('%-10s', r.fish_id);
    for m = 1:5; fprintf(' %10.1f', r.BIC(m)); end
    fprintf(' %8s\n', MODEL_SHORT{r.best_model});
end

% Summary statistics per model
fprintf('\n  Per-model summary:\n');
for m = 1:5
    aucs = arrayfun(@(r) r.AUC(m), all_results);
    fprintf('    %s: Mean AUC = %.3f +/- %.3f\n', MODEL_NAMES{m}, mean(aucs), std(aucs));
end

% Count best model
for m = 1:5
    n_best = sum([all_results.best_model] == m);
    if n_best > 0
        fprintf('    %s preferred in %d/%d fish\n', MODEL_SHORT{m}, n_best, nFish);
    end
end

% Save grand summary
save(fullfile(BASE_PATH, 'All_Fish_Summary_5Models.mat'), 'all_results', 'MODEL_NAMES', 'MODEL_SHORT');

% Build summary table for CSV/Excel (exclude cell/array fields)
tbl_fish_id = {all_results.fish_id}';
tbl_n = [all_results.n_trials]';
tbl_acc = [all_results.accuracy]';
tbl_best = [all_results.best_model]';
auc_mat = vertcat(all_results.AUC);
bic_mat = vertcat(all_results.BIC);
evd_mat = vertcat(all_results.Evidence);
T = table(tbl_fish_id, tbl_n, tbl_acc, ...
    auc_mat(:,1), auc_mat(:,2), auc_mat(:,3), auc_mat(:,4), auc_mat(:,5), ...
    bic_mat(:,1), bic_mat(:,2), bic_mat(:,3), bic_mat(:,4), bic_mat(:,5), ...
    evd_mat(:,1), evd_mat(:,2), evd_mat(:,3), evd_mat(:,4), evd_mat(:,5), ...
    tbl_best, ...
    'VariableNames', {'Fish', 'N_trials', 'Accuracy', ...
    'M1_AUC','M2_AUC','M3_AUC','M4_AUC','M5_AUC', ...
    'M1_BIC','M2_BIC','M3_BIC','M4_BIC','M5_BIC', ...
    'M1_Evidence','M2_Evidence','M3_Evidence','M4_Evidence','M5_Evidence', ...
    'Best_Model'});
writetable(T, fullfile(BASE_PATH, 'All_Fish_Summary_5Models.xlsx'));
writetable(T, fullfile(BASE_PATH, 'All_Fish_Summary_5Models.csv'));

%% Grand summary figure
figure('Position', [50, 50, 1600, 1000]);
fish_labels = arrayfun(@(x) sprintf('F%d', x), 6:(5+nFish), 'UniformOutput', false);
model_colors = [0.2 0.7 0.2; 0.8 0.2 0.2; 0.2 0.4 0.8; 0.9 0.6 0.1; 0.5 0.2 0.7];

% AUC comparison (all 5 models)
subplot(2,2,1);
auc_mat = vertcat(all_results.AUC);
bw = 0.15;
x = 1:nFish;
for m = 1:5
    bar(x + (m-3)*bw, auc_mat(:,m), bw, 'FaceColor', model_colors(m,:), ...
        'FaceAlpha', 0.8); hold on;
end
set(gca, 'XTick', x, 'XTickLabel', fish_labels);
ylabel('AUC'); ylim([0.45 1]);
title('Model AUC Comparison'); legend(MODEL_SHORT, 'Location', 'best', 'FontSize', 8);
grid on; set(gca, 'GridAlpha', 0.3);

% BIC comparison (all 5 models)
subplot(2,2,2);
bic_mat = vertcat(all_results.BIC);
min_bic = min(bic_mat, [], 2);
delta_bic_mat = bic_mat - min_bic;  % relative to best
for m = 1:5
    bar(x + (m-3)*bw, delta_bic_mat(:,m), bw, 'FaceColor', model_colors(m,:), ...
        'FaceAlpha', 0.8); hold on;
end
set(gca, 'XTick', x, 'XTickLabel', fish_labels);
ylabel('\DeltaBIC (vs best)'); title('BIC Comparison (lower = better)');
legend(MODEL_SHORT, 'Location', 'best', 'FontSize', 8);
grid on; set(gca, 'GridAlpha', 0.3);

% Best model per fish
subplot(2,2,3);
best_counts = histcounts([all_results.best_model], 0.5:5.5);
b = bar(best_counts, 'FaceColor', 'flat');
b.CData = model_colors;
set(gca, 'XTickLabel', MODEL_SHORT);
ylabel('Number of Fish'); title('Best Model (by BIC)');
grid on; set(gca, 'GridAlpha', 0.3);

% Overall accuracy
subplot(2,2,4);
bar([all_results.accuracy], 'FaceColor', [0.5 0.5 0.5]);
yline(0.5, 'r--');
set(gca, 'XTick', 1:nFish, 'XTickLabel', fish_labels);
ylabel('Accuracy'); ylim([0.4 1]);
title('Overall Accuracy');
grid on; set(gca, 'GridAlpha', 0.3);

sgtitle('Cross-Fish Summary - 5 Models (Optimized \sigma)', 'FontSize', 14, 'FontWeight', 'bold');
saveas(gcf, fullfile(BASE_PATH, 'All_Fish_Summary_5Models.png'));
close(gcf);

fprintf('\n%s\n', repmat('=', 1, 70));
fprintf('ANALYSIS COMPLETE\n');
fprintf('%s\n', repmat('=', 1, 70));
fprintf('Files saved to: %s\n', BASE_PATH);
fprintf('Done!\n');


%% ========================================================================
% ANALYSIS FUNCTION FOR A SINGLE FISH
% =========================================================================

function result = analyze_fish(fish_number, FISH_NAMES, BASE_PATH, DATA_FILE, OPT, MODEL_NAMES, MODEL_SHORT)

    fish_name = FISH_NAMES{fish_number};
    fish_id = sprintf('Fish_%d', fish_number + 5);
    output_dir = fullfile(BASE_PATH, fish_id);
    if ~isfolder(output_dir); mkdir(output_dir); end

    fprintf('\n%s\n', repmat('=', 1, 70));
    fprintf('ANALYZING %s (%s)\n', fish_id, fish_name);
    fprintf('%s\n', repmat('=', 1, 70));

    % --- Load and prepare data from the combined workbook (sheet named by number) ---
    raw = readcell(DATA_FILE, 'Sheet', fish_name);
    headers = strtrim(string(raw(1,:)));
    res_col = find(strcmpi(headers, "results"), 1);
    if isempty(res_col); error('No results column on sheet %s.', fish_name); end
    % Target and non-target stimulus-position columns, read by name.
    t_col  = find(strcmpi(headers, "target"), 1);
    nt_col = find(strcmpi(headers, "non_target") | strcmpi(headers, "non target"), 1);
    if isempty(t_col) || isempty(nt_col)
        % Fallback for older workbooks: detect the two position columns and
        % apply the verified convention (left = non-target, right = target).
        is_pos = startsWith(headers, "Quad(", 'IgnoreCase', true) | ...
                 ismember(lower(headers), ["ant","spider","morph","circle"]);
        pos_cols = find(is_pos);
        if numel(pos_cols) ~= 2
            error('Could not locate target/non_target columns on sheet %s.', fish_name);
        end
        nt_col = pos_cols(1); t_col = pos_cols(2);
    end

    body = raw(2:end, :); nRaw = size(body,1);
    res_raw = nan(nRaw,1); tgt_raw = nan(nRaw,1); nt_raw = nan(nRaw,1);
    for r = 1:nRaw
        res_raw(r) = local_num(body{r,res_col});
        tgt_raw(r) = local_num(body{r,t_col});
        nt_raw(r)  = local_num(body{r,nt_col});
    end
    valid_rows = ismember(res_raw, [0 1]) & ~isnan(tgt_raw) & ~isnan(nt_raw);

    N = sum(valid_rows);
    original_results = res_raw(valid_rows);     % 0/1
    y = original_results + 1;                    % 1/2 for the model
    target_locations = tgt_raw(valid_rows);
    non_target_locations = nt_raw(valid_rows);
    trials = (0:N-1)';
    sessions = ones(N, 1);   % session column not used by the fit

    fprintf('Trials: %d, Overall Accuracy: %.1f%%\n', N, mean(original_results)*100);

    % --- Quadrant statistics ---
    quadrant_counts = zeros(4, 1);
    quadrant_accuracy = nan(4, 1);
    for q = 1:4
        mask = target_locations == q;
        quadrant_counts(q) = sum(mask);
        if sum(mask) > 0
            quadrant_accuracy(q) = mean(original_results(mask));
        end
    end
    fprintf('Quadrant accuracy: Q1=%.1f%%, Q2=%.1f%%, Q3=%.1f%%, Q4=%.1f%%\n', ...
        quadrant_accuracy(1)*100, quadrant_accuracy(2)*100, ...
        quadrant_accuracy(3)*100, quadrant_accuracy(4)*100);

    % --- Create regressors ---
    % Spatial indicators (target quadrant = 1, else 0)
    q1 = double(target_locations == 1);
    q2 = double(target_locations == 2);
    q3 = double(target_locations == 3);
    q4 = double(target_locations == 4);

    % Persistence regressor: +1 if animal made the same choice type as previous trial
    %   (target->target or non-target->non-target = persisted = +1)
    %   (target->non-target or non-target->target = switched  = -1)
    prev_outcome = zeros(N, 1);
    for i = 2:N
        if original_results(i) == original_results(i-1)
            prev_outcome(i) = 1;   % persisted
        else
            prev_outcome(i) = -1;  % switched
        end
    end

    % Spatial bias regressors:
    %   +1 if animal CHOSE this quadrant:
    %       (target==q & outcome==1) or (non_target==q & outcome==0)
    %   -1 if this quadrant was an option but animal DID NOT choose it:
    %       (target==q & outcome==0) or (non_target==q & outcome==1)
    %    0 if quadrant was neither target nor non-target
    for q = 1:4
        is_targ = (target_locations == q);
        is_ntarg = (non_target_locations == q);
        sb_tmp = zeros(N, 1);
        sb_tmp(is_targ  & original_results == 1) =  1;   % target, correct -> chose q
        sb_tmp(is_ntarg & original_results == 0) =  1;   % non-target, incorrect -> chose q
        sb_tmp(is_targ  & original_results == 0) = -1;   % target, incorrect -> rejected q
        sb_tmp(is_ntarg & original_results == 1) = -1;   % non-target, correct -> rejected q
        switch q
            case 1; sb1 = sb_tmp;
            case 2; sb2 = sb_tmp;
            case 3; sb3 = sb_tmp;
            case 4; sb4 = sb_tmp;
        end
    end

    % Running accuracy
    [q_running, overall_running] = compute_running_accuracy(original_results, target_locations, 15);

    % =====================================================================
    % FIT ALL 5 MODELS
    % =====================================================================

    % --- M1: Spatial (4 weights) ---
    fprintf('\n  Fitting M1: Spatial...\n');
    X_m1 = [q1, q2, q3, q4];
    [wMAP_m1, W_std_m1, evd_m1, sig_m1, info_m1] = fit_dynamic_glm_eb(y, X_m1, OPT);
    pred_m1 = sigmoid_fn(sum(X_m1' .* wMAP_m1, 1))';
    metrics_m1 = compute_metrics(original_results, pred_m1, 4, N);
    fprintf('    sigmas=[%.4f %.4f %.4f %.4f], AUC=%.3f, BIC=%.1f\n', ...
        sig_m1(1), sig_m1(2), sig_m1(3), sig_m1(4), metrics_m1.auc, metrics_m1.bic);

    % --- M2: Spatial + Persistence (5 weights) ---
    fprintf('  Fitting M2: Spatial + Persistence...\n');
    X_m2 = [prev_outcome, q1, q2, q3, q4];
    [wMAP_m2, W_std_m2, evd_m2, sig_m2, info_m2] = fit_dynamic_glm_eb(y, X_m2, OPT);
    pred_m2 = sigmoid_fn(sum(X_m2' .* wMAP_m2, 1))';
    metrics_m2 = compute_metrics(original_results, pred_m2, 5, N);
    fprintf('    sigmas=[%.4f %.4f %.4f %.4f %.4f], AUC=%.3f, BIC=%.1f\n', ...
        sig_m2(1), sig_m2(2), sig_m2(3), sig_m2(4), sig_m2(5), metrics_m2.auc, metrics_m2.bic);

    % --- M3: Spatial Bias (4 weights) ---
    fprintf('  Fitting M3: Spatial Bias...\n');
    X_m3 = [sb1, sb2, sb3, sb4];
    [wMAP_m3, W_std_m3, evd_m3, sig_m3, info_m3] = fit_dynamic_glm_eb(y, X_m3, OPT);
    pred_m3 = sigmoid_fn(sum(X_m3' .* wMAP_m3, 1))';
    metrics_m3 = compute_metrics(original_results, pred_m3, 4, N);
    fprintf('    sigmas=[%.4f %.4f %.4f %.4f], AUC=%.3f, BIC=%.1f\n', ...
        sig_m3(1), sig_m3(2), sig_m3(3), sig_m3(4), metrics_m3.auc, metrics_m3.bic);

    % --- M4: Spatial Bias + Spatial (8 weights) ---
    fprintf('  Fitting M4: Spatial Bias + Spatial...\n');
    X_m4 = [sb1, sb2, sb3, sb4, q1, q2, q3, q4];
    [wMAP_m4, W_std_m4, evd_m4, sig_m4, info_m4] = fit_dynamic_glm_eb(y, X_m4, OPT);
    pred_m4 = sigmoid_fn(sum(X_m4' .* wMAP_m4, 1))';
    metrics_m4 = compute_metrics(original_results, pred_m4, 8, N);
    fprintf('    AUC=%.3f, BIC=%.1f\n', metrics_m4.auc, metrics_m4.bic);

    % --- M5: Spatial Bias + Spatial + Persistence (9 weights) ---
    fprintf('  Fitting M5: Spatial Bias + Spatial + Persistence...\n');
    X_m5 = [prev_outcome, sb1, sb2, sb3, sb4, q1, q2, q3, q4];
    [wMAP_m5, W_std_m5, evd_m5, sig_m5, info_m5] = fit_dynamic_glm_eb(y, X_m5, OPT);
    pred_m5 = sigmoid_fn(sum(X_m5' .* wMAP_m5, 1))';
    metrics_m5 = compute_metrics(original_results, pred_m5, 9, N);
    fprintf('    AUC=%.3f, BIC=%.1f\n', metrics_m5.auc, metrics_m5.bic);

    % Collect all metrics
    all_auc = [metrics_m1.auc, metrics_m2.auc, metrics_m3.auc, metrics_m4.auc, metrics_m5.auc];
    all_bic = [metrics_m1.bic, metrics_m2.bic, metrics_m3.bic, metrics_m4.bic, metrics_m5.bic];
    all_evd = [evd_m1, evd_m2, evd_m3, evd_m4, evd_m5];
    all_pred = {pred_m1, pred_m2, pred_m3, pred_m4, pred_m5};
    [~, best_model] = min(all_bic);

    fprintf('\n  MODEL COMPARISON (BIC):\n');
    for m = 1:5
        marker = '';
        if m == best_model; marker = ' ***BEST***'; end
        fprintf('    %s: BIC=%.1f, AUC=%.3f%s\n', MODEL_NAMES{m}, all_bic(m), all_auc(m), marker);
    end

    % Per-quadrant predictions for M1 (spatial weights are indices 1-4)
    q_pred_m1 = cell(4,1);
    for q = 1:4; q_pred_m1{q} = sigmoid_fn(wMAP_m1(q,:))'; end

    % Per-quadrant predictions for M3 (spatial bias weights are indices 1-4)
    q_pred_m3_bias = cell(4,1);
    for q = 1:4; q_pred_m3_bias{q} = sigmoid_fn(wMAP_m3(q,:))'; end

    % =====================================================================
    % PLOTTING
    % =====================================================================
    colors_q = [0.122 0.467 0.706; 0.839 0.153 0.157;
                0.173 0.627 0.173; 0.580 0.404 0.741];
    model_colors = [0.2 0.7 0.2; 0.8 0.2 0.2; 0.2 0.4 0.8; 0.9 0.6 0.1; 0.5 0.2 0.7];

    % ----- FIGURE 1: M1 Weight Trajectories -----
    figure('Position', [50, 50, 1600, 1200], 'Visible', 'off');
    for q_idx = 1:4
        subplot(2, 2, q_idx);
        w = wMAP_m1(q_idx, :); w_std = W_std_m1(q_idx, :);
        fill([trials; flipud(trials)], ...
             [w'-1.96*w_std'; flipud(w'+1.96*w_std')], ...
             colors_q(q_idx,:), 'FaceAlpha', 0.3, 'EdgeColor', 'none'); hold on;
        plot(trials, w, 'Color', colors_q(q_idx,:), 'LineWidth', 2);
        yline(0, '--', 'Color', [0.5 0.5 0.5], 'Alpha', 0.5);
        yline(mean(w), ':', 'Color', colors_q(q_idx,:), 'Alpha', 0.7);
        xlabel('Trial'); ylabel('Weight');
        title(sprintf('Q%d (n=%d, acc=%.1f%%, \\sigma=%.4f)', ...
            q_idx, quadrant_counts(q_idx), quadrant_accuracy(q_idx)*100, sig_m1(q_idx)), ...
            'FontWeight', 'bold');
        legend({'95% CI', 'Weight', '', sprintf('Mean=%.2f', mean(w))}, 'Location', 'best');
        grid on; set(gca, 'GridAlpha', 0.3);
    end
    sgtitle(sprintf('%s - M1 Spatial Weights', fish_id), 'FontSize', 16, 'FontWeight', 'bold');
    saveas(gcf, fullfile(output_dir, [fish_id, '_M1_weights.png']));
    close(gcf);

    % ----- FIGURE 2: M1 Predictions vs Running Accuracy -----
    figure('Position', [50, 50, 1600, 1200], 'Visible', 'off');
    for q_idx = 1:4
        subplot(2, 2, q_idx);
        plot(trials, q_running{q_idx}, 'k-', 'LineWidth', 2); hold on;
        plot(trials, q_pred_m1{q_idx}, '--', 'Color', colors_q(q_idx,:), 'LineWidth', 2);
        trial_mask = target_locations == q_idx;
        scatter(trials(trial_mask), original_results(trial_mask), ...
            20, colors_q(q_idx,:), 'filled', 'MarkerFaceAlpha', 0.15);
        yline(0.5, '--', 'Color', [0.5 0.5 0.5], 'Alpha', 0.5);
        xlabel('Trial'); ylabel('P(Correct)');
        title(sprintf('Q%d Fit (n=%d, acc=%.1f%%)', ...
            q_idx, quadrant_counts(q_idx), quadrant_accuracy(q_idx)*100), 'FontWeight', 'bold');
        ylim([-0.05, 1.05]);
        legend({'Running Accuracy', 'M1 P(correct)', 'Outcomes'}, 'Location', 'best');
        grid on; set(gca, 'GridAlpha', 0.3);
    end
    sgtitle(sprintf('%s - M1 Model Fit vs Data', fish_id), 'FontSize', 16, 'FontWeight', 'bold');
    saveas(gcf, fullfile(output_dir, [fish_id, '_M1_fit.png']));
    close(gcf);

    % ----- FIGURE 3: M3 Spatial Bias Weight Trajectories -----
    figure('Position', [50, 50, 1600, 1200], 'Visible', 'off');
    for q_idx = 1:4
        subplot(2, 2, q_idx);
        w = wMAP_m3(q_idx, :); w_std = W_std_m3(q_idx, :);
        fill([trials; flipud(trials)], ...
             [w'-1.96*w_std'; flipud(w'+1.96*w_std')], ...
             colors_q(q_idx,:), 'FaceAlpha', 0.3, 'EdgeColor', 'none'); hold on;
        plot(trials, w, 'Color', colors_q(q_idx,:), 'LineWidth', 2);
        yline(0, '--', 'Color', [0.5 0.5 0.5], 'Alpha', 0.5);
        yline(mean(w), ':', 'Color', colors_q(q_idx,:), 'Alpha', 0.7);
        xlabel('Trial'); ylabel('Weight');
        title(sprintf('Q%d Bias (\\sigma=%.4f)', q_idx, sig_m3(q_idx)), 'FontWeight', 'bold');
        legend({'95% CI', 'Weight', '', sprintf('Mean=%.2f', mean(w))}, 'Location', 'best');
        grid on; set(gca, 'GridAlpha', 0.3);
    end
    sgtitle(sprintf('%s - M3 Spatial Bias Weights', fish_id), 'FontSize', 16, 'FontWeight', 'bold');
    saveas(gcf, fullfile(output_dir, [fish_id, '_M3_spatbias_weights.png']));
    close(gcf);

    % ----- FIGURE 4: M3 Spatial Bias Fit vs Running Accuracy -----
    figure('Position', [50, 50, 1600, 1200], 'Visible', 'off');
    for q_idx = 1:4
        subplot(2, 2, q_idx);
        plot(trials, q_running{q_idx}, 'k-', 'LineWidth', 2); hold on;
        plot(trials, q_pred_m3_bias{q_idx}, '--', 'Color', colors_q(q_idx,:), 'LineWidth', 2);
        trial_mask = target_locations == q_idx;
        scatter(trials(trial_mask), original_results(trial_mask), ...
            20, colors_q(q_idx,:), 'filled', 'MarkerFaceAlpha', 0.15);
        yline(0.5, '--', 'Color', [0.5 0.5 0.5], 'Alpha', 0.5);
        xlabel('Trial'); ylabel('P(Correct)');
        title(sprintf('Q%d (n=%d, acc=%.1f%%)', ...
            q_idx, quadrant_counts(q_idx), quadrant_accuracy(q_idx)*100), 'FontWeight', 'bold');
        ylim([-0.05, 1.05]);
        legend({'Running Accuracy', 'M3 sigmoid(w_{bias})', 'Outcomes'}, 'Location', 'best');
        grid on; set(gca, 'GridAlpha', 0.3);
    end
    sgtitle(sprintf('%s - M3 Spatial Bias Fit', fish_id), 'FontSize', 16, 'FontWeight', 'bold');
    saveas(gcf, fullfile(output_dir, [fish_id, '_M3_spatbias_fit.png']));
    close(gcf);

    % ----- FIGURE 5: Persistence Weight (from M2 and M5) -----
    figure('Position', [50, 50, 1400, 900], 'Visible', 'off');

    subplot(2, 2, 1);
    hw2 = wMAP_m2(1, :); hs2 = W_std_m2(1, :);
    fill([trials; flipud(trials)], ...
         [hw2'-1.96*hs2'; flipud(hw2'+1.96*hs2')], ...
         [1 0.65 0], 'FaceAlpha', 0.3, 'EdgeColor', 'none'); hold on;
    plot(trials, hw2, 'Color', [1 0.65 0], 'LineWidth', 2);
    yline(0, '--', 'Color', [0.5 0.5 0.5]); yline(mean(hw2), ':', 'Color', [1 0.65 0]);
    xlabel('Trial'); ylabel('Weight');
    title(sprintf('M2 Persistence (\\sigma=%.4f, mean=%.3f)', sig_m2(1), mean(hw2)), 'FontWeight', 'bold');
    grid on; set(gca, 'GridAlpha', 0.3);

    subplot(2, 2, 2);
    histogram(hw2, 30, 'FaceColor', [1 0.65 0], 'FaceAlpha', 0.7, 'EdgeColor', 'k'); hold on;
    xline(0, '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 2);
    xline(mean(hw2), '-', 'Color', 'r', 'LineWidth', 2);
    xlabel('Persistence Weight'); ylabel('Count');
    title('M2 Persistence Distribution', 'FontWeight', 'bold');
    grid on; set(gca, 'GridAlpha', 0.3);

    subplot(2, 2, 3);
    hw5 = wMAP_m5(1, :); hs5 = W_std_m5(1, :);
    fill([trials; flipud(trials)], ...
         [hw5'-1.96*hs5'; flipud(hw5'+1.96*hs5')], ...
         [0.6 0.2 0.8], 'FaceAlpha', 0.3, 'EdgeColor', 'none'); hold on;
    plot(trials, hw5, 'Color', [0.6 0.2 0.8], 'LineWidth', 2);
    yline(0, '--', 'Color', [0.5 0.5 0.5]); yline(mean(hw5), ':', 'Color', [0.6 0.2 0.8]);
    xlabel('Trial'); ylabel('Weight');
    title(sprintf('M5 Persistence (\\sigma=%.4f, mean=%.3f)', sig_m5(1), mean(hw5)), 'FontWeight', 'bold');
    grid on; set(gca, 'GridAlpha', 0.3);

    subplot(2, 2, 4);
    histogram(hw5, 30, 'FaceColor', [0.6 0.2 0.8], 'FaceAlpha', 0.7, 'EdgeColor', 'k'); hold on;
    xline(0, '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 2);
    xline(mean(hw5), '-', 'Color', 'r', 'LineWidth', 2);
    xlabel('Persistence Weight'); ylabel('Count');
    title('M5 Persistence Distribution', 'FontWeight', 'bold');
    grid on; set(gca, 'GridAlpha', 0.3);

    sgtitle(sprintf('%s - Persistence Weights', fish_id), 'FontSize', 16, 'FontWeight', 'bold');
    saveas(gcf, fullfile(output_dir, [fish_id, '_persistence_weights.png']));
    close(gcf);

    % ----- FIGURE 6: Summary Statistics -----
    figure('Position', [50, 50, 1800, 1000], 'Visible', 'off');

    % Mean M1 weights per quadrant
    subplot(2, 3, 1);
    mean_w = mean(wMAP_m1, 2); std_w = std(wMAP_m1, 0, 2);
    b = bar(mean_w, 'FaceColor', 'flat'); hold on;
    b.CData = colors_q;
    errorbar(1:4, mean_w, std_w, 'k.', 'LineWidth', 1.5, 'CapSize', 5);
    yline(0, '--', 'Color', [0.5 0.5 0.5]);
    set(gca, 'XTickLabel', {'Q1','Q2','Q3','Q4'});
    ylabel('Mean Weight +/- SD');
    title('M1 Mean Quadrant Weights', 'FontWeight', 'bold');
    grid on; set(gca, 'GridAlpha', 0.3);

    % Mean M3 spatial bias weights
    subplot(2, 3, 2);
    mean_sb = mean(wMAP_m3, 2); std_sb = std(wMAP_m3, 0, 2);
    b = bar(mean_sb, 'FaceColor', 'flat'); hold on;
    b.CData = colors_q;
    errorbar(1:4, mean_sb, std_sb, 'k.', 'LineWidth', 1.5, 'CapSize', 5);
    yline(0, '--', 'Color', [0.5 0.5 0.5]);
    set(gca, 'XTickLabel', {'Q1','Q2','Q3','Q4'});
    ylabel('Mean Weight +/- SD');
    title('M3 Mean Spatial Bias Weights', 'FontWeight', 'bold');
    grid on; set(gca, 'GridAlpha', 0.3);

    % Raw quadrant accuracy
    subplot(2, 3, 3);
    b = bar(quadrant_accuracy, 'FaceColor', 'flat');
    b.CData = colors_q;
    yline(0.5, '--', 'Color', [0.5 0.5 0.5]);
    set(gca, 'XTickLabel', {'Q1','Q2','Q3','Q4'});
    ylabel('Accuracy'); ylim([0 1]);
    title('Raw Quadrant Accuracy', 'FontWeight', 'bold');
    grid on; set(gca, 'GridAlpha', 0.3);

    % ROC curves (all 5 models)
    subplot(2, 3, 4);
    for m = 1:5
        [fpr_m, tpr_m] = compute_roc(original_results, all_pred{m});
        plot(fpr_m, tpr_m, '-', 'Color', model_colors(m,:), 'LineWidth', 2); hold on;
    end
    plot([0 1], [0 1], 'k--', 'LineWidth', 1);
    xlabel('False Positive Rate'); ylabel('True Positive Rate');
    title('ROC Curves', 'FontWeight', 'bold');
    leg_labels = arrayfun(@(m) sprintf('%s (%.3f)', MODEL_SHORT{m}, all_auc(m)), 1:5, 'UniformOutput', false);
    legend(leg_labels, 'Location', 'southeast', 'FontSize', 8);
    grid on; set(gca, 'GridAlpha', 0.3);

    % BIC comparison (all 5 models)
    subplot(2, 3, 5);
    b = bar(all_bic, 'FaceColor', 'flat', 'EdgeColor', 'k', 'LineWidth', 1.5);
    b.CData = model_colors;
    set(gca, 'XTickLabel', MODEL_SHORT);
    ylabel('BIC (lower = better)');
    title(sprintf('BIC Comparison (best: %s)', MODEL_SHORT{best_model}), 'FontWeight', 'bold');
    grid on; set(gca, 'GridAlpha', 0.3);

    % Overall fit (smoothed, best model)
    subplot(2, 3, 6);
    win = 20;
    acc_smooth = movmean(original_results, win, 'omitnan');
    pred_best_smooth = movmean(all_pred{best_model}, win, 'omitnan');
    plot(trials, acc_smooth, 'k-', 'LineWidth', 2); hold on;
    plot(trials, pred_best_smooth, '--', 'Color', model_colors(best_model,:), 'LineWidth', 2);
    yline(0.5, '--', 'Color', [0.5 0.5 0.5]);
    xlabel('Trial'); ylabel('P(Correct)');
    title(sprintf('Best Model Fit (%s)', MODEL_SHORT{best_model}), 'FontWeight', 'bold');
    ylim([0 1]);
    legend({'Actual (smoothed)', sprintf('%s Predicted', MODEL_SHORT{best_model})}, 'Location', 'best');
    grid on; set(gca, 'GridAlpha', 0.3);

    sgtitle(sprintf('%s - Summary', fish_id), 'FontSize', 16, 'FontWeight', 'bold');
    saveas(gcf, fullfile(output_dir, [fish_id, '_summary.png']));
    close(gcf);

    % ----- FIGURE 7: All Quadrant Weights Overlaid (M1 and M3) -----
    figure('Position', [50, 50, 1400, 900], 'Visible', 'off');

    subplot(2, 1, 1);
    for q_idx = 1:4
        plot(trials, wMAP_m1(q_idx,:), 'Color', colors_q(q_idx,:), 'LineWidth', 2); hold on;
    end
    yline(0, '--', 'Color', [0.5 0.5 0.5]);
    xlabel('Trial'); ylabel('Weight');
    title('M1: Spatial Weights', 'FontWeight', 'bold');
    legend(arrayfun(@(q) sprintf('Q%d (acc=%.1f%%)', q, quadrant_accuracy(q)*100), ...
        1:4, 'UniformOutput', false), 'Location', 'best');
    grid on; set(gca, 'GridAlpha', 0.3);

    subplot(2, 1, 2);
    for q_idx = 1:4
        plot(trials, wMAP_m3(q_idx,:), 'Color', colors_q(q_idx,:), 'LineWidth', 2); hold on;
    end
    yline(0, '--', 'Color', [0.5 0.5 0.5]);
    xlabel('Trial'); ylabel('Weight');
    title('M3: Spatial Bias Weights', 'FontWeight', 'bold');
    legend(arrayfun(@(q) sprintf('Q%d', q), 1:4, 'UniformOutput', false), 'Location', 'best');
    grid on; set(gca, 'GridAlpha', 0.3);

    sgtitle(sprintf('%s - Quadrant Weight Comparison', fish_id), 'FontSize', 16, 'FontWeight', 'bold');
    saveas(gcf, fullfile(output_dir, [fish_id, '_weights_comparison.png']));
    close(gcf);

    % ----- FIGURE 8: Sigma Convergence -----
    figure('Position', [50, 50, 1800, 600], 'Visible', 'off');
    all_infos = {info_m1, info_m2, info_m3, info_m4, info_m5};
    for m = 1:5
        subplot(1, 5, m);
        sh = all_infos{m}.sigma_history;
        K_m = size(sh, 2);
        for k = 1:K_m
            plot(1:size(sh,1), sh(:,k), '-o', 'LineWidth', 1.5, 'MarkerSize', 4); hold on;
        end
        xlabel('Iteration'); ylabel('\sigma');
        title(MODEL_SHORT{m}, 'FontWeight', 'bold');
        grid on; set(gca, 'GridAlpha', 0.3);
    end
    sgtitle(sprintf('%s - \\sigma Convergence', fish_id), 'FontSize', 16, 'FontWeight', 'bold');
    saveas(gcf, fullfile(output_dir, [fish_id, '_sigma_convergence.png']));
    close(gcf);

    % =====================================================================
    % SAVE TO EXCEL
    % =====================================================================

    % Trial-level data
    trial_table = table(trials, sessions, target_locations, non_target_locations, ...
        original_results, prev_outcome, overall_running, ...
        pred_m1, pred_m2, pred_m3, pred_m4, pred_m5, ...
        'VariableNames', {'trial', 'session', 'target_quadrant', 'non_target_quadrant', ...
        'outcome', 'prev_outcome', 'overall_running_acc', ...
        'M1_prediction', 'M2_prediction', 'M3_prediction', 'M4_prediction', 'M5_prediction'});

    for q = 1:4
        trial_table.(sprintf('Q%d_running_acc', q)) = q_running{q};
    end

    % M1 weights
    for q = 1:4
        trial_table.(sprintf('M1_Q%d_weight', q)) = wMAP_m1(q,:)';
        trial_table.(sprintf('M1_Q%d_weight_std', q)) = W_std_m1(q,:)';
    end

    % M2 weights (persistence is index 1, quadrants 2-5)
    trial_table.M2_persistence_weight = wMAP_m2(1,:)';
    trial_table.M2_persistence_weight_std = W_std_m2(1,:)';
    for q = 1:4
        trial_table.(sprintf('M2_Q%d_weight', q)) = wMAP_m2(q+1,:)';
        trial_table.(sprintf('M2_Q%d_weight_std', q)) = W_std_m2(q+1,:)';
    end

    % M3 spatial bias weights
    for q = 1:4
        trial_table.(sprintf('M3_SB_Q%d_weight', q)) = wMAP_m3(q,:)';
        trial_table.(sprintf('M3_SB_Q%d_weight_std', q)) = W_std_m3(q,:)';
    end

    % M4 weights (spatial bias 1-4, spatial 5-8)
    for q = 1:4
        trial_table.(sprintf('M4_SB_Q%d_weight', q)) = wMAP_m4(q,:)';
        trial_table.(sprintf('M4_Sp_Q%d_weight', q)) = wMAP_m4(q+4,:)';
    end

    % M5 weights (persistence 1, spatial bias 2-5, spatial 6-9)
    trial_table.M5_persistence_weight = wMAP_m5(1,:)';
    for q = 1:4
        trial_table.(sprintf('M5_SB_Q%d_weight', q)) = wMAP_m5(q+1,:)';
        trial_table.(sprintf('M5_Sp_Q%d_weight', q)) = wMAP_m5(q+5,:)';
    end

    % Spatial bias regressors
    trial_table.sb1 = sb1; trial_table.sb2 = sb2;
    trial_table.sb3 = sb3; trial_table.sb4 = sb4;

    % Summary data
    metric_names = {'N_trials'; 'Overall_accuracy'; ...
        'M1_AUC'; 'M1_PseudoR2'; 'M1_BIC'; 'M1_LogLik'; 'M1_Evidence'; ...
        'M2_AUC'; 'M2_PseudoR2'; 'M2_BIC'; 'M2_LogLik'; 'M2_Evidence'; ...
        'M3_AUC'; 'M3_PseudoR2'; 'M3_BIC'; 'M3_LogLik'; 'M3_Evidence'; ...
        'M4_AUC'; 'M4_PseudoR2'; 'M4_BIC'; 'M4_LogLik'; 'M4_Evidence'; ...
        'M5_AUC'; 'M5_PseudoR2'; 'M5_BIC'; 'M5_LogLik'; 'M5_Evidence'; ...
        'Best_Model_BIC'};

    all_metrics = {metrics_m1, metrics_m2, metrics_m3, metrics_m4, metrics_m5};
    mv = {N; mean(original_results)};
    for m = 1:5
        mv = [mv; {all_metrics{m}.auc; all_metrics{m}.pseudo_r2; ...
              all_metrics{m}.bic; all_metrics{m}.log_likelihood; all_evd(m)}]; %#ok<AGROW>
    end
    mv = [mv; {MODEL_SHORT{best_model}}];

    summary_table = table(metric_names, mv, 'VariableNames', {'Metric', 'Value'});

    % Sigma summary
    sig_names = {};
    sig_vals = [];
    % M1 sigmas
    for q = 1:4; sig_names{end+1} = sprintf('M1_sigma_Q%d', q); sig_vals(end+1) = sig_m1(q); end %#ok<AGROW>
    % M2 sigmas
    sig_names{end+1} = 'M2_sigma_persist'; sig_vals(end+1) = sig_m2(1);
    for q = 1:4; sig_names{end+1} = sprintf('M2_sigma_Q%d', q); sig_vals(end+1) = sig_m2(q+1); end %#ok<AGROW>
    % M3 sigmas
    for q = 1:4; sig_names{end+1} = sprintf('M3_sigma_SB_Q%d', q); sig_vals(end+1) = sig_m3(q); end %#ok<AGROW>
    % M4 sigmas
    for q = 1:4; sig_names{end+1} = sprintf('M4_sigma_SB_Q%d', q); sig_vals(end+1) = sig_m4(q); end %#ok<AGROW>
    for q = 1:4; sig_names{end+1} = sprintf('M4_sigma_Sp_Q%d', q); sig_vals(end+1) = sig_m4(q+4); end %#ok<AGROW>
    % M5 sigmas
    sig_names{end+1} = 'M5_sigma_persist'; sig_vals(end+1) = sig_m5(1);
    for q = 1:4; sig_names{end+1} = sprintf('M5_sigma_SB_Q%d', q); sig_vals(end+1) = sig_m5(q+1); end %#ok<AGROW>
    for q = 1:4; sig_names{end+1} = sprintf('M5_sigma_Sp_Q%d', q); sig_vals(end+1) = sig_m5(q+5); end %#ok<AGROW>

    sigma_table = table(sig_names(:), sig_vals(:), 'VariableNames', {'Parameter', 'Sigma'});

    excel_path = fullfile(output_dir, [fish_id, '_analysis.xlsx']);
    writetable(trial_table, excel_path, 'Sheet', 'Trial_Data');
    writetable(summary_table, excel_path, 'Sheet', 'Summary');
    writetable(sigma_table, excel_path, 'Sheet', 'Optimized_Sigmas');
    fprintf('\n  Saved Excel: %s\n', excel_path);

    % =====================================================================
    % SAVE TO MATLAB .mat
    % =====================================================================
    mat_data = struct();
    mat_data.fish_number = fish_number + 5;
    mat_data.fish_id = fish_id;
    mat_data.fish_name = fish_name;
    mat_data.n_trials = N;
    mat_data.trials = trials;
    mat_data.sessions = sessions;
    mat_data.target_quadrant = target_locations;
    mat_data.non_target_quadrant = non_target_locations;
    mat_data.outcome = original_results;
    mat_data.prev_outcome = prev_outcome;
    mat_data.quadrant_counts = quadrant_counts;
    mat_data.quadrant_accuracy = quadrant_accuracy;
    mat_data.overall_running_acc = overall_running;
    mat_data.sb_regressors = [sb1, sb2, sb3, sb4];

    % Store all model results
    model_labels = {'M1','M2','M3','M4','M5'};
    all_wMAP = {wMAP_m1, wMAP_m2, wMAP_m3, wMAP_m4, wMAP_m5};
    all_Wstd = {W_std_m1, W_std_m2, W_std_m3, W_std_m4, W_std_m5};
    all_sigs = {sig_m1, sig_m2, sig_m3, sig_m4, sig_m5};

    for m = 1:5
        ml = model_labels{m};
        mat_data.([ml '_weights']) = all_wMAP{m};
        mat_data.([ml '_weights_std']) = all_Wstd{m};
        mat_data.([ml '_predictions']) = all_pred{m};
        mat_data.([ml '_sigmas']) = all_sigs{m};
        mat_data.([ml '_sigma_history']) = all_infos{m}.sigma_history;
        mat_data.([ml '_evidence']) = all_evd(m);
        mat_data.([ml '_auc']) = all_auc(m);
        mat_data.([ml '_bic']) = all_bic(m);
        mat_data.([ml '_log_likelihood']) = all_metrics{m}.log_likelihood;
        mat_data.([ml '_pseudo_r2']) = all_metrics{m}.pseudo_r2;
    end

    mat_data.best_model = best_model;
    mat_data.all_auc = all_auc;
    mat_data.all_bic = all_bic;
    mat_data.all_evidence = all_evd;

    for q = 1:4
        mat_data.(sprintf('Q%d_running_acc', q)) = q_running{q};
    end

    mat_path = fullfile(output_dir, [fish_id, '_analysis.mat']);
    save(mat_path, '-struct', 'mat_data');
    fprintf('  Saved MATLAB: %s\n', mat_path);

    % --- Return result struct ---
    result.fish_number = fish_number + 5;
    result.fish_id = fish_id;
    result.n_trials = N;
    result.accuracy = mean(original_results);
    result.AUC = all_auc;
    result.BIC = all_bic;
    result.Evidence = all_evd;
    result.best_model = best_model;
end


%% ========================================================================
% CORE: EMPIRICAL BAYES FITTING WITH DECOUPLED LAPLACE
% =========================================================================
% Two key correctness features:
%
% 1) JOINT NEWTON via block-tridiagonal solver:
%    The Hessian is block-tridiagonal with KxK blocks. Each block couples
%    all K weights at a given trial through the likelihood. Per-weight
%    coordinate descent fails when regressors have multiple nonzero entries
%    per trial (e.g., spatial bias with +1/-1). The block solver handles
%    the coupling correctly.
%
% 2) FIXED RHS in inner loop (Algorithm 1, steps 3-5):
%    The Gaussian likelihood approximation is computed ONCE from the MAP
%    and kept constant across inner iterations. The RHS for the cheap
%    wMAP update is: rhs_k = (-H_orig_k) * wMAP_k, computed once.
%    Inner iterations only change the prior (via sigma) and solve:
%    (C_new^{-1} + Gamma^{-1}) * w_new = fixed_rhs
% =========================================================================

function [wMAP, W_std, logEvidence, sigmas, optim_info] = fit_dynamic_glm_eb(y, X, OPT)

    [N, K] = size(X);
    y01 = (y(:) == 2);

    sigInit      = OPT.sigInit;
    max_outer    = OPT.max_outer;
    max_inner    = OPT.max_inner;
    sigma_tol    = OPT.sigma_tol;
    map_tol      = OPT.map_tol;
    map_max_iter = OPT.map_max_iter;
    sigma_min    = OPT.sigma_min;
    sigma_max    = OPT.sigma_max;

    inv_sigInit2 = 1 / sigInit^2;
    sigmas = OPT.sigma0 * ones(K, 1);

    sigma_history = zeros(max_outer, K);
    evidence_history = zeros(max_outer, 1);

    W = zeros(K, N);
    best_evidence = -Inf;
    best_sigmas = sigmas;
    best_W = W;

    for outer = 1:max_outer

        inv_sig2 = 1 ./ (sigmas.^2);

        % =============================================================
        % STEP 2: Full MAP via joint Newton (block-tridiagonal solve)
        % The full negative Hessian is block-tridiagonal with KxK blocks:
        %   Block(t,t) = diag(prior_t) + x_t * x_t' * lambda_t
        %   Block(t,t+1) = -diag(inv_sig2)
        % =============================================================
        for map_iter = 1:map_max_iter
            % Linear predictor and logistic quantities
            g = sum(X' .* W, 1)';      % N x 1
            p = sigmoid_fn(g);
            residuals = y01 - p;
            lambda = p .* (1 - p);

            % Build KxK block-diagonal entries A(t) and per-block RHS
            A_blocks = zeros(K, K, N);  % A(:,:,t) = K x K block at trial t
            rhs_blocks = zeros(K, N);   % rhs(:,t) = K x 1 rhs at trial t

            for t = 1:N
                % Prior contribution to diagonal
                if t == 1
                    prior_diag = inv_sigInit2 + inv_sig2;
                elseif t == N
                    prior_diag = inv_sig2;
                else
                    prior_diag = 2 * inv_sig2;
                end

                % Likelihood Hessian block: x_t * x_t' * lambda_t
                xt = X(t, :)';  % K x 1
                A_blocks(:,:,t) = diag(prior_diag) + (xt * xt') * lambda(t);

                % Gradient at trial t
                grad_lik_t = xt * residuals(t);
                grad_prior_t = zeros(K, 1);
                for k = 1:K
                    if t == 1
                        grad_prior_t(k) = -(inv_sigInit2 + inv_sig2(k)) * W(k,1);
                        if N > 1; grad_prior_t(k) = grad_prior_t(k) + inv_sig2(k) * W(k,2); end
                    elseif t == N
                        grad_prior_t(k) = inv_sig2(k)*W(k,t-1) - inv_sig2(k)*W(k,t);
                    else
                        grad_prior_t(k) = inv_sig2(k)*W(k,t-1) - 2*inv_sig2(k)*W(k,t) + inv_sig2(k)*W(k,t+1);
                    end
                end

                % RHS = (-H_t) * w_t + grad_t
                wt = W(:, t);
                Hw = A_blocks(:,:,t) * wt;
                if t > 1;  Hw = Hw + (-diag(inv_sig2)) * W(:, t-1); end
                if t < N;  Hw = Hw + (-diag(inv_sig2)) * W(:, t+1); end
                rhs_blocks(:, t) = Hw + grad_lik_t + grad_prior_t;
            end

            % Solve block-tridiagonal system
            W_new = block_tridiag_solve(A_blocks, inv_sig2, rhs_blocks);

            max_change = max(abs(W_new(:) - W(:)));
            W = W_new;
            if max_change < map_tol; break; end
        end

        % Recompute at converged MAP
        g = sum(X' .* W, 1)';
        p = sigmoid_fn(g);
        lambda = p .* (1 - p);

        % =============================================================
        % STEPS 3-4: Compute FIXED Gaussian likelihood approximation
        % Gamma_k^{-1} = diag(x_k^2 * lambda)  (FIXED from MAP)
        % fixed_rhs_k = (-H_orig_k) * wMAP_k    (FIXED, constant)
        % =============================================================
        lik_hess_diags = zeros(N, K);  % Gamma_k^{-1} diagonals, per weight
        fixed_rhs = zeros(K, N);       % constant RHS for inner loop
        for k = 1:K
            xk = X(:, k);
            hld = xk.^2 .* lambda;
            lik_hess_diags(:, k) = hld;

            % Build (-H_orig_k) = C_orig_k^{-1} + Gamma_k^{-1}
            [pd_d, pd_e] = build_rw_prior_hess(N, inv_sig2(k), inv_sigInit2);
            md = pd_d + hld;
            % fixed_rhs_k = (-H_orig_k) * wMAP_k
            fixed_rhs(k, :) = tridiag_multiply(md, pd_e, W(k,:)')';
        end

        % =============================================================
        % STEP 5: Decoupled Laplace inner loop
        % Update sigma and w using FIXED Gaussian likelihood approx.
        % Per-weight tridiagonal solves are correct here because the
        % Gaussian likelihood is separable per weight (Gamma is diagonal
        % in the per-weight sense).
        % =============================================================
        for inner = 1:max_inner
            sigmas_prev = sigmas;
            inv_sig2 = 1 ./ (sigmas.^2);

            for k = 1:K
                hld = lik_hess_diags(:, k);

                % New posterior precision: C_new_k^{-1} + Gamma_k^{-1}
                [pd_d, pd_e] = build_rw_prior_hess(N, inv_sig2(k), inv_sigInit2);
                md = pd_d + hld;

                % Solve: (C_new + Gamma^{-1}) w = fixed_rhs  (CONSTANT RHS!)
                W(k,:) = tridiag_solve_vec(md, pd_e, fixed_rhs(k,:)')';

                % Posterior covariance for sigma update
                [cov_diag, cov_offdiag, ~] = tridiag_inv_diag_offdiag(md, pd_e);

                % Closed-form sigma update:
                % sigma_k^2 = [sum(diff(w)^2) + tr(Sigma D'D)] / (N-1)
                dw = diff(W(k,:)');
                data_term = sum(dw.^2);
                trace_term = cov_diag(1) + cov_diag(N);
                if N > 2
                    trace_term = trace_term + 2 * sum(cov_diag(2:N-1));
                end
                trace_term = trace_term - 2 * sum(cov_offdiag);

                new_sig2 = (data_term + trace_term) / (N - 1);
                sigmas(k) = min(max(sqrt(max(new_sig2, sigma_min^2)), sigma_min), sigma_max);
            end

            rel_change = max(abs(sigmas - sigmas_prev) ./ max(sigmas_prev, 1e-10));
            if rel_change < sigma_tol; break; end
        end

        % =============================================================
        % STEP 6: Compute log evidence (Laplace approximation)
        % log E = L(wMAP) + log p(wMAP|theta) - log N(wMAP|wMAP, (-H)^{-1})
        % =============================================================
        inv_sig2 = 1 ./ (sigmas.^2);
        g = sum(X' .* W, 1)';
        p = sigmoid_fn(g);
        p_clip = max(min(p, 1-1e-10), 1e-10);
        log_lik = sum(y01 .* log(p_clip) + (1-y01) .* log(1-p_clip));

        log_prior = 0;
        logdet_post = 0;
        lambda_final = p .* (1 - p);

        for k = 1:K
            w_k = W(k,:)';
            dw = diff(w_k);
            log_prior = log_prior - 0.5 * inv_sig2(k) * sum(dw.^2);
            log_prior = log_prior - 0.5 * inv_sigInit2 * w_k(1)^2;
            log_prior = log_prior - 0.5 * (N-1) * log(2*pi*sigmas(k)^2) ...
                        - 0.5 * log(2*pi*sigInit^2);

            xk = X(:, k);
            hld = xk.^2 .* lambda_final;
            [pd_d, pd_e] = build_rw_prior_hess(N, inv_sig2(k), inv_sigInit2);
            md = pd_d + hld;
            [~, ~, ld] = tridiag_inv_diag_offdiag(md, pd_e);
            logdet_post = logdet_post + ld;
        end

        logEvidence = log_lik + log_prior + 0.5 * K * N * log(2*pi) - 0.5 * logdet_post;
        sigma_history(outer, :) = sigmas';
        evidence_history(outer) = logEvidence;

        if logEvidence > best_evidence
            best_evidence = logEvidence;
            best_sigmas = sigmas;
            best_W = W;
        end

        if outer > 1
            rel_outer = max(abs(sigma_history(outer,:) - sigma_history(outer-1,:)) ...
                         ./ max(sigma_history(outer-1,:), 1e-10));
            if rel_outer < sigma_tol; break; end
        end
    end

    n_outer = outer;
    sigmas = best_sigmas;
    W = best_W;
    wMAP = W;

    % Final credible intervals with optimized sigmas
    inv_sig2 = 1 ./ (sigmas.^2);
    g = sum(X' .* wMAP, 1)';
    p = sigmoid_fn(g);
    lambda = p .* (1 - p);
    W_std = zeros(K, N);
    logdet_total = 0;

    for k = 1:K
        xk = X(:, k);
        hld = xk.^2 .* lambda;
        [pd_d, pd_e] = build_rw_prior_hess(N, inv_sig2(k), inv_sigInit2);
        md = pd_d + hld;
        [inv_diag, ~, ld] = tridiag_inv_diag_offdiag(md, pd_e);
        W_std(k, :) = sqrt(max(inv_diag, 1e-10))';
        logdet_total = logdet_total + ld;
    end

    % Final evidence
    p_clip = max(min(p, 1-1e-10), 1e-10);
    log_lik = sum(y01 .* log(p_clip) + (1-y01) .* log(1-p_clip));
    log_prior = 0;
    for k = 1:K
        w_k = wMAP(k,:)';
        dw = diff(w_k);
        log_prior = log_prior - 0.5 * inv_sig2(k) * sum(dw.^2);
        log_prior = log_prior - 0.5 * inv_sigInit2 * w_k(1)^2;
        log_prior = log_prior - 0.5 * (N-1) * log(2*pi*sigmas(k)^2) ...
                    - 0.5 * log(2*pi*sigInit^2);
    end
    logEvidence = log_lik + log_prior + 0.5 * K * N * log(2*pi) - 0.5 * logdet_total;

    optim_info.n_outer = n_outer;
    optim_info.sigma_history = sigma_history(1:n_outer, :);
    optim_info.evidence_history = evidence_history(1:n_outer);
    optim_info.final_evidence = logEvidence;
end


%% ========================================================================
% BLOCK-TRIDIAGONAL SOLVER (JOINT NEWTON)
% =========================================================================
% Solves the block-tridiagonal system arising from the joint Newton step
% over all K weights simultaneously. Block structure:
%   Block(t,t):   A(:,:,t) = diag(prior_t) + x_t*x_t'*lambda_t  (KxK)
%   Block(t,t+1): B = -diag(inv_sig2)                             (KxK)
%
% Uses block Thomas algorithm: O(N*K^3), exact for K <= 9.
% =========================================================================

function W_out = block_tridiag_solve(A_blocks, inv_sig2, rhs_blocks)
% BLOCK_TRIDIAG_SOLVE  Solve block-tridiagonal system.
%   A_blocks: (K, K, N) - diagonal blocks
%   inv_sig2: (K, 1) - off-diagonal blocks are B = -diag(inv_sig2)
%   rhs_blocks: (K, N) - right-hand side
%   Returns: W_out (K, N) - solution

    K = size(A_blocks, 1);
    N = size(A_blocks, 3);
    B = -diag(inv_sig2);  % K x K, constant off-diagonal block

    % Forward sweep
    D_inv = zeros(K, K, N);
    rhs_mod = zeros(K, N);

    D_inv(:,:,1) = inv(A_blocks(:,:,1));
    rhs_mod(:,1) = rhs_blocks(:,1);

    for t = 2:N
        % M = B * D_inv_{t-1} * B  (since B is symmetric)
        temp = D_inv(:,:,t-1) * B;
        M = B * temp;
        D_t = A_blocks(:,:,t) - M;
        D_inv(:,:,t) = inv(D_t);
        rhs_mod(:,t) = rhs_blocks(:,t) - B * (D_inv(:,:,t-1) * rhs_mod(:,t-1));
    end

    % Backward sweep
    W_out = zeros(K, N);
    W_out(:,N) = D_inv(:,:,N) * rhs_mod(:,N);
    for t = N-1:-1:1
        W_out(:,t) = D_inv(:,:,t) * (rhs_mod(:,t) - B * W_out(:,t+1));
    end
end


%% ========================================================================
% TRIDIAGONAL MATRIX UTILITIES
% =========================================================================

function grad = compute_rw_prior_grad(w, inv_sig2, inv_sigInit2)
    N = length(w);
    grad = zeros(N, 1);
    if N == 1; grad(1) = -inv_sigInit2 * w(1); return; end
    grad(1) = -(inv_sigInit2 + inv_sig2) * w(1) + inv_sig2 * w(2);
    for t = 2:N-1
        grad(t) = inv_sig2 * w(t-1) - 2*inv_sig2 * w(t) + inv_sig2 * w(t+1);
    end
    grad(N) = inv_sig2 * w(N-1) - inv_sig2 * w(N);
end

function [main_diag, off_diag] = build_rw_prior_hess(N, inv_sig2, inv_sigInit2)
    main_diag = zeros(N, 1);
    off_diag = zeros(max(N-1, 0), 1);
    if N == 1; main_diag(1) = inv_sigInit2; return; end
    main_diag(1) = inv_sigInit2 + inv_sig2;
    for t = 2:N-1; main_diag(t) = 2 * inv_sig2; end
    main_diag(N) = inv_sig2;
    off_diag(:) = -inv_sig2;
end

function y = tridiag_multiply(d, e, x)
    N = length(d);
    y = d .* x;
    if N > 1
        y(1:N-1) = y(1:N-1) + e .* x(2:N);
        y(2:N) = y(2:N) + e .* x(1:N-1);
    end
end

function x = tridiag_solve_vec(d, e, b)
    N = length(d);
    d_mod = zeros(N, 1); b_mod = zeros(N, 1);
    d_mod(1) = d(1); b_mod(1) = b(1);
    for i = 2:N
        m = e(i-1) / d_mod(i-1);
        d_mod(i) = d(i) - m * e(i-1);
        b_mod(i) = b(i) - m * b_mod(i-1);
    end
    x = zeros(N, 1);
    x(N) = b_mod(N) / d_mod(N);
    for i = N-1:-1:1
        x(i) = (b_mod(i) - e(i) * x(i+1)) / d_mod(i);
    end
end

function [inv_diag, inv_offdiag, logdet] = tridiag_inv_diag_offdiag(d, e)
    N = length(d);
    if N == 1
        inv_diag = 1/d(1); inv_offdiag = []; logdet = log(abs(d(1)));
        return;
    end

    % Forward/backward minors
    theta = zeros(N+1, 1);
    theta(1) = 1; theta(2) = d(1);
    for i = 2:N
        theta(i+1) = d(i) * theta(i) - e(i-1)^2 * theta(i-1);
    end

    phi = zeros(N+2, 1);
    phi(N+1) = 1; phi(N) = d(N);
    for i = N-1:-1:1
        phi(i) = d(i) * phi(i+1) - e(i)^2 * phi(i+2);
    end

    det_val = theta(N+1);
    logdet = log(abs(det_val));

    if abs(det_val) < 1e-300 || isnan(det_val) || isinf(det_val)
        [inv_diag, inv_offdiag, logdet] = tridiag_inv_stable(d, e);
        return;
    end

    inv_diag = zeros(N, 1);
    for i = 1:N
        inv_diag(i) = theta(i) * phi(i+1) / det_val;
    end

    inv_offdiag = zeros(N-1, 1);
    for i = 1:N-1
        inv_offdiag(i) = -e(i) * theta(i) * phi(i+2) / det_val;
    end

    inv_diag = abs(inv_diag);
end

function [inv_diag, inv_offdiag, logdet] = tridiag_inv_stable(d, e)
    N = length(d);
    d_fwd = zeros(N, 1); l_sub = zeros(N-1, 1);
    d_fwd(1) = d(1);
    logdet = log(abs(d_fwd(1)));
    for i = 2:N
        l_sub(i-1) = e(i-1) / d_fwd(i-1);
        d_fwd(i) = d(i) - l_sub(i-1) * e(i-1);
        logdet = logdet + log(abs(d_fwd(i)));
    end
    inv_diag = zeros(N, 1);
    inv_diag(N) = 1 / d_fwd(N);
    for i = N-1:-1:1
        inv_diag(i) = 1/d_fwd(i) + l_sub(i)^2 * inv_diag(i+1);
    end
    inv_offdiag = zeros(N-1, 1);
    for i = 1:N-1
        inv_offdiag(i) = -l_sub(i) * inv_diag(i+1);
    end
    inv_diag = abs(inv_diag);
end


%% ========================================================================
% HELPER FUNCTIONS
% =========================================================================

function p = sigmoid_fn(x)
    x = max(min(x, 500), -500);
    p = 1 ./ (1 + exp(-x));
end

function metrics = compute_metrics(y_true, y_pred, n_params, n_trials)
    y_pred_clip = max(min(y_pred, 1-1e-10), 1e-10);
    log_lik = sum(y_true .* log(y_pred_clip) + (1-y_true) .* log(1-y_pred_clip));
    p_null = mean(y_true);
    log_lik_null = n_trials * (p_null * log(p_null + 1e-10) + (1-p_null) * log(1-p_null + 1e-10));
    if log_lik_null ~= 0
        pseudo_r2 = 1 - (log_lik / log_lik_null);
    else
        pseudo_r2 = 0;
    end
    try
        [~, ~, ~, auc] = perfcurve(y_true, y_pred, 1);
    catch
        auc = 0.5;
    end
    bic = -2 * log_lik + n_params * log(n_trials);
    aic = -2 * log_lik + 2 * n_params;
    metrics.log_likelihood = log_lik;
    metrics.pseudo_r2 = pseudo_r2;
    metrics.auc = auc;
    metrics.accuracy = mean((y_pred > 0.5) == y_true);
    metrics.bic = bic;
    metrics.aic = aic;
    metrics.n_params = n_params;
end

function [q_running, overall_running] = compute_running_accuracy(outcomes, target_locations, window)
    N = length(outcomes);
    q_running = cell(4, 1);
    for q = 1:4; q_running{q} = nan(N, 1); end
    overall_running = nan(N, 1);
    for t = 1:N
        s = max(1, t - window);
        e = min(N, t + window);
        if (e - s + 1) >= 3
            overall_running(t) = mean(outcomes(s:e));
        end
        for q = 1:4
            mask = target_locations(s:e) == q;
            if sum(mask) >= 2
                chunk = outcomes(s:e);
                q_running{q}(t) = mean(chunk(mask));
            end
        end
    end
end

function [fpr, tpr] = compute_roc(y_true, y_pred)
    thresholds = sort(unique(y_pred), 'descend');
    thresholds = [1+eps; thresholds; -eps];
    fpr = zeros(length(thresholds), 1);
    tpr = zeros(length(thresholds), 1);
    P = sum(y_true == 1);
    N_neg = sum(y_true == 0);
    for i = 1:length(thresholds)
        predicted_pos = y_pred >= thresholds(i);
        tp = sum(predicted_pos & y_true == 1);
        fp = sum(predicted_pos & y_true == 0);
        tpr(i) = tp / max(P, 1);
        fpr(i) = fp / max(N_neg, 1);
    end
end

function v = local_num(x)
    % Convert one workbook cell to a number, returning NaN for blanks,
    % missing cells, or non-numeric outcome codes (e.g. 'C','M','S','A','NAN').
    v = NaN;
    if isnumeric(x) && isscalar(x)
        if ~isnan(x); v = double(x); end
    elseif ischar(x) || (isstring(x) && isscalar(x))
        v = str2double(x);
    end
end
