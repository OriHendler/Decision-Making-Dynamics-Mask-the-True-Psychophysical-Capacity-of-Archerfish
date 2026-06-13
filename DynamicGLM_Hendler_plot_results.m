%% Dynamic GLM Hendler Plotting Script - Supports Figure 2 (7 models) & Figure 3 (5 models)
% =========================================================================
% Standalone script: loads Fish_X_analysis.mat files and generates
% per-model plots of weights, model fit vs actual behavior, and BIC.
%
%       For every combination of 3 fish from FISH_LIST (C(n,3)):
%       Row 1: Best-model accuracy fit (wide panel, spans 3 sub-cols)
%       Row 2: Target position 1 | Target position 2 | Spatial bias
%       Row 3: Shape persistence | Win-stay | Lose-stay (blank if absent)
%   - Supports both FIGURE 2 (2-position, 7 models) and FIGURE 3 (4-quadrant, 5 models)
%   - Loops over multiple fish automatically (FISH_LIST)
%   - MODEL_REMAP: allows user to reorder/rename model display order
%     (identity by default; change when needed)
%
% Windows match the main analysis code:
%   - Per-position/quadrant running accuracy: ±15 centered (from .mat)
%   - Smoothed fit overlay: movmean with win=20
%
% USAGE: Set FIGURE_NUM, FISH_LIST, and paths below, then run.
% =========================================================================

clear; clc; close all;

%% ========================================================================
% USER CONFIGURATION
% =========================================================================

% --- Which figure? ---
%   2 = 2-position task, 7 models (DynamicGLM_Hendler_2pos_7models)
%   3 = 4-quadrant task, 5 models (DynamicGLM_Hendler_4quad_5models)
FIGURE_NUM = 3;

% --- Which fish to plot? (list of fish numbers) ---
FISH_LIST = [6:1:14];   % <-- edit this list

% --- Run only the combined 3-fish figures? ---
% Set to true to skip per-fish plots, cross-fish summaries, and M4-vs-history.
% Only generates the combined 3-fish comparison figures (Figure 2 only).
COMBINED_ONLY = 0;

% --- Combined 3-fish figure ---
COMB_FISH = [1 2 4];   % which 3 fish to compare
COMB_FONT = 12;        % base font size

% --- Persistence test ---
% Set true to run ONLY the all-fish persistence test (skips everything else).
% Test slides PERS_WIN_SIZE-trial windows, shuffles each window's outcomes
% PERS_N_PERM_WIN times, and counts windows with significant excess
% repetition (z > 1.96) or excess switching (z < -1.96). Pooled binomial
% test reported across all fish in FISH_LIST.
RUN_PERSISTENCE_TEST = 0;
PERS_WIN_SIZE        = 100;
PERS_N_PERM_WIN      = 500;
PERS_STEP            = 10;
PERS_MIN_NULL_SD     = 1.0;   % exclude windows where the test has no power

% --- Smoothing window for fit overlay ---
SMOOTH_WIN = 20;
NORMALIZE_ACC = true;
PRIOR_NTRIALS  = 100;
% Path layout: <root>/code (scripts), <root>/data (workbook), <root>/output (figures).
% Falls back to a flat layout with the workbook next to the scripts.
thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir); thisDir = pwd; end
rootDir = fileparts(thisDir);
DATA_NAME = 'Fish_Data_Updated_with_2ACT2P_V2.xlsx';
if isfile(fullfile(rootDir, 'data', DATA_NAME))
    PRIOR_EXCEL = fullfile(rootDir, 'data', DATA_NAME);
    BASE_ROOT   = fullfile(rootDir, 'output');
elseif isfile(fullfile(thisDir, DATA_NAME))
    PRIOR_EXCEL = fullfile(thisDir, DATA_NAME);
    BASE_ROOT   = fullfile(thisDir, 'output');
else
    PRIOR_EXCEL = ''; NORMALIZE_ACC = false;
    BASE_ROOT   = fullfile(rootDir, 'output');
end
PRIOR_SHEET = '14';

% --- MODEL REMAP (future use) ---
% Maps display order -> original model index in the .mat file.
% Default: identity (no remapping). Change when needed, e.g.:
%   MODEL_REMAP = [3 1 2 4 5];  % would show M3 first, then M1, M2, M4, M5
% IMPORTANT: length must equal N_MODELS for the chosen figure.
MODEL_REMAP = [];  % empty = identity (no remapping)

%% ========================================================================
% FIGURE-SPECIFIC DEFINITIONS
% =========================================================================

if FIGURE_NUM == 2
    % ----- FIGURE 2: 2-position, 7 models -----
    FIGURE_FOLDER = fullfile(BASE_ROOT, 'FIGURE 2');
    N_MODELS = 7;

    MODEL_SHORT_ORIG = {'M1','M2','M3','M4','M5','M6','M7'};
    MODEL_NAMES_ORIG = {'M1: Spatial', 'M2: Spatial+Persist', 'M3: SpatBias', ...
        'M4: SpatBias+Spatial', 'M5: SpatBias+Spatial+Persist', ...
        'M6: M4+WinStay+LoseStay', 'M7: M5+WinStay+LoseStay'};

    WT_NAMES_ORIG = { ...
        {'P1','P2'}, ...
        {'Persist','P1','P2'}, ...
        {'SB1','SB2'}, ...
        {'SB1','SB2','P1','P2'}, ...
        {'Persist','SB1','SB2','P1','P2'}, ...
        {'SB1','SB2','P1','P2','WinStay','LoseStay'}, ...
        {'Persist','SB1','SB2','P1','P2','WinStay','LoseStay'}};

    MODEL_COLORS_ORIG = [0.2 0.7 0.2; 0.8 0.2 0.2; 0.2 0.4 0.8; ...
                         0.9 0.6 0.1; 0.5 0.2 0.7; 0.1 0.7 0.7; 0.8 0.4 0.6];

    RUNNING_ACC_PREFIX = 'Pos';   % fields: Pos1_running_acc, Pos2_running_acc
    RUNNING_ACC_SOURCE = 'positions';  % uses d.positions to get the indices

    LOCATION_COLORS = [0.122 0.467 0.706; 0.839 0.153 0.157];  % 2 positions
    LOCATION_LABEL = 'Pos';

elseif FIGURE_NUM == 3
    % ----- FIGURE 3: 4-quadrant, 5 models -----
    FIGURE_FOLDER = fullfile(BASE_ROOT, 'FIGURE 3');
    N_MODELS = 5;

    MODEL_SHORT_ORIG = {'M1','M2','M3','M4','M5'};
    MODEL_NAMES_ORIG = {'M1: Spatial', 'M2: Spatial+Persist', ...
        'M3: SpatBias', 'M4: SpatBias+Spatial', ...
        'M5: SpatBias+Spatial+Persist'};

    WT_NAMES_ORIG = { ...
        {'Q1','Q2','Q3','Q4'}, ...
        {'Persist','Q1','Q2','Q3','Q4'}, ...
        {'SB1','SB2','SB3','SB4'}, ...
        {'SB1','SB2','SB3','SB4','Q1','Q2','Q3','Q4'}, ...
        {'Persist','SB1','SB2','SB3','SB4','Q1','Q2','Q3','Q4'}};

    MODEL_COLORS_ORIG = [0.2 0.7 0.2; 0.8 0.2 0.2; 0.2 0.4 0.8; ...
                         0.9 0.6 0.1; 0.5 0.2 0.7];

    RUNNING_ACC_PREFIX = 'Q';     % fields: Q1_running_acc, Q2_running_acc, ...
    RUNNING_ACC_SOURCE = 'quadrants';  % uses 1:4

    LOCATION_COLORS = [0.122 0.467 0.706; 0.839 0.153 0.157; ...
                       0.173 0.627 0.173; 0.580 0.404 0.741];  % 4 quadrants
    LOCATION_LABEL = 'Q';

else
    error('FIGURE_NUM must be 2 or 3.');
end

%% ========================================================================
% DISPLAY NAME MAP & DESIRED SUBPLOT ORDER
% =========================================================================
% Maps internal weight keys 
DISPLAY_NAME_MAP = struct( ...
    'P1',       'Target position 1', ...
    'P2',       'Target position 2', ...
    'Q1',       'Target position 1', ...
    'Q2',       'Target position 2', ...
    'Q3',       'Target position 3', ...
    'Q4',       'Target position 4', ...
    'SB1',      'Spatial bias 1', ...
    'SB2',      'Spatial bias 2', ...
    'SB3',      'Spatial bias 3', ...
    'SB4',      'Spatial bias 4', ...
    'Persist',  'Shape persistence', ...
    'WinStay',  'Win-stay', ...
    'LoseStay', 'Lose-stay');

if FIGURE_NUM == 2
    DISPLAY_NAME_MAP.SB1 = 'Spatial bias';
end

% Desired subplot order (by internal key). 
if FIGURE_NUM == 2
    DESIRED_ORDER = {'P1','P2','SB1','Persist','WinStay','LoseStay'};
else  % FIGURE_NUM == 3
    DESIRED_ORDER = {'Q1','Q2','Q3','Q4','SB1','SB2','SB3','Persist'};
end

%% ========================================================================
% APPLY MODEL REMAP
% =========================================================================
% If MODEL_REMAP is empty, use identity (no remapping).
% MODEL_REMAP(i) = j means: display slot i shows original model j.
% All arrays are reordered so the rest of the code just uses indices 1:N_MODELS.

if isempty(MODEL_REMAP)
    MODEL_REMAP = 1:N_MODELS;  % identity
end
assert(length(MODEL_REMAP) == N_MODELS, ...
    'MODEL_REMAP length (%d) must equal N_MODELS (%d)', length(MODEL_REMAP), N_MODELS);

% Reorder everything according to the remap
MODEL_SHORT  = MODEL_SHORT_ORIG(MODEL_REMAP);
MODEL_NAMES  = MODEL_NAMES_ORIG(MODEL_REMAP);
WT_NAMES     = WT_NAMES_ORIG(MODEL_REMAP);
model_colors = MODEL_COLORS_ORIG(MODEL_REMAP, :);

% Keep the ORIG short names for loading from .mat (always M1..M5 or M1..M7)
MAT_MODEL_SHORT = MODEL_SHORT_ORIG(MODEL_REMAP);  % original labels in remap order

%% ========================================================================
% COLOR MAP FOR INDIVIDUAL WEIGHTS
% =========================================================================
COLOR_MAP = struct( ...
    'P1',       [0.122 0.467 0.706], ...
    'P2',       [0.839 0.153 0.157], ...
    'Q1',       [0.122 0.467 0.706], ...
    'Q2',       [0.839 0.153 0.157], ...
    'Q3',       [0.173 0.627 0.173], ...
    'Q4',       [0.580 0.404 0.741], ...
    'SB1',      [0.200 0.400 0.800], ...
    'SB2',      [0.900 0.400 0.200], ...
    'SB3',      [0.173 0.627 0.173], ...
    'SB4',      [0.580 0.404 0.741], ...
    'Persist',  [1.000 0.650 0.000], ...
    'WinStay',  [0.100 0.700 0.700], ...
    'LoseStay', [0.800 0.400 0.600]);

%% ========================================================================
p_prior = NaN;
if NORMALIZE_ACC && ~isempty(PRIOR_EXCEL) && isfile(PRIOR_EXCEL)
    try
        prior_raw = readcell(PRIOR_EXCEL, 'Sheet', PRIOR_SHEET);
        prior_headers = string(prior_raw(1,:));
        res_col = find(strcmpi(prior_headers, "results"), 1);
        prior_vals = prior_raw(2:end, res_col);
        prior_y = nan(numel(prior_vals), 1);
        for hh = 1:numel(prior_vals)
            v = prior_vals{hh};
            if isnumeric(v) && ~isnan(v); prior_y(hh) = v; end
        end
        prior_y = prior_y(~isnan(prior_y));
        nPrior = min(PRIOR_NTRIALS, numel(prior_y));
        p_prior = mean(prior_y(1:nPrior));
        fprintf('Prior: p_prior = %.4f (from first %d trials)\n', p_prior, nPrior);
    catch ME
        fprintf('WARNING: Could not load prior: %s\n', ME.message);
        p_prior = NaN;
    end
elseif NORMALIZE_ACC
    fprintf('WARNING: Data workbook not found, normalization disabled.\n');
end

%% ========================================================================
% MAIN FISH LOOP (skipped when COMBINED_ONLY = true)
% =========================================================================

if ~COMBINED_ONLY && ~RUN_PERSISTENCE_TEST

for fi = 1:length(FISH_LIST)
    fish_num = FISH_LIST(fi);
    fish_folder = sprintf('Fish_%d', fish_num);
    mat_file = fullfile(FIGURE_FOLDER, fish_folder, [fish_folder '_analysis.mat']);

    if ~isfile(mat_file)
        fprintf('WARNING: %s not found, skipping.\n', mat_file);
        continue;
    end

    fprintf('\n%s\n', repmat('=', 1, 70));
    fprintf('PLOTTING: %s (Figure %d)\n', fish_folder, FIGURE_NUM);
    fprintf('%s\n', repmat('=', 1, 70));

    d = load(mat_file);
    [output_dir, ~, ~] = fileparts(mat_file);

    N = d.n_trials;
    trials = d.trials;
    y01 = d.outcome;
    fish_id = d.fish_id;

    % --- Load per-location running accuracy ---
    if strcmp(RUNNING_ACC_SOURCE, 'positions')
        positions = d.positions;
        n_loc = length(positions);
        loc_running = cell(n_loc, 1);
        loc_labels = cell(n_loc, 1);
        for p = 1:n_loc
            loc_running{p} = d.(sprintf('%s%d_running_acc', RUNNING_ACC_PREFIX, positions(p)));
            loc_labels{p} = sprintf('%s %d', LOCATION_LABEL, positions(p));
        end
    else  % quadrants
        n_loc = 4;
        loc_running = cell(n_loc, 1);
        loc_labels = cell(n_loc, 1);
        for q = 1:n_loc
            loc_running{q} = d.(sprintf('%s%d_running_acc', RUNNING_ACC_PREFIX, q));
            loc_labels{q} = sprintf('%s %d', LOCATION_LABEL, q);
        end
    end
    overall_running = d.overall_running_acc;

    % --- Load BIC/AUC (apply remap) ---
    all_bic_orig = d.all_bic;
    all_auc_orig = d.all_auc;
    all_bic = all_bic_orig(MODEL_REMAP);
    all_auc = all_auc_orig(MODEL_REMAP);
    [~, best_model] = min(all_bic);

    fprintf('Loaded: %s\n', mat_file);
    fprintf('Fish: %s, Trials: %d\n\n', fish_id, N);

    %% ====================================================================
    % FIGURE: BIC + AUC COMPARISON
    % =====================================================================
    figure('Position', [50 50 900 400], 'Name', 'BIC Comparison', 'Color', 'w');

    subplot(1,2,1);
    b = bar(all_bic, 'FaceColor', 'flat', 'EdgeColor', 'k', 'LineWidth', 1.5);
    b.CData = model_colors;
    set(gca, 'XTickLabel', MODEL_SHORT);
    ylabel('BIC (lower = better)', 'FontWeight', 'bold', 'FontSize', 16);
    title(sprintf('%s - BIC (best: %s)', fish_id, MODEL_SHORT{best_model}), ...
        'FontSize', 14, 'FontWeight', 'bold');
    style_axes(gca);

    subplot(1,2,2);
    b = bar(all_auc, 'FaceColor', 'flat', 'EdgeColor', 'k', 'LineWidth', 1.5);
    b.CData = model_colors;
    set(gca, 'XTickLabel', MODEL_SHORT);
    ylabel('AUC', 'FontWeight', 'bold', 'FontSize', 16); ylim([0.4 1]);
    title(sprintf('%s - AUC', fish_id), 'FontSize', 14, 'FontWeight', 'bold');
    style_axes(gca);

    set(gcf, 'Visible', 'on');
    saveas(gcf, fullfile(output_dir, [fish_id '_BIC_AUC_comparison.fig']));
    saveas(gcf, fullfile(output_dir, [fish_id '_BIC_AUC_comparison.png']));
    close(gcf);
    fprintf('Saved: BIC/AUC comparison\n');

    %% ====================================================================
    % PER-MODEL: WEIGHTS + FIT (2 figures per model)
    % =====================================================================

    for m = 1:N_MODELS
        ml_display = MODEL_SHORT{m};       % display label (after remap)
        ml_mat     = MAT_MODEL_SHORT{m};   % original label for .mat field access

        wMAP   = d.([ml_mat '_weights']);
        W_std  = d.([ml_mat '_weights_std']);
        pred   = d.([ml_mat '_predictions']);
        sigmas = d.([ml_mat '_sigmas']);
        auc_m  = d.([ml_mat '_auc']);
        bic_m  = d.([ml_mat '_bic']);

        K = size(wMAP, 1);
        wt_names = WT_NAMES{m};

        % --- WEIGHT TRAJECTORIES ---
        % Figure 3: fixed 3-row layout  Row1=Target(Q), Row2=Bias(SB), Row3=Persist
        % Figure 2: auto-layout as before
        if FIGURE_NUM == 3
            % ---- Figure 3: 3 SEPARATE figures, one per weight row, tight borders ----
            ROW_GROUPS_F4 = { ...
                {'Q1','Q2','Q3','Q4'},      'target_position',    'Target position'; ...
                {'SB1','SB2','SB3'},        'spatial_bias',       'Spatial bias';   ...
                {'Persist'},                'shape_persistence',  'Shape persistence' };

            % --- Pre-compute COMMON y-axis range across ALL weight panels for this fish ---
            yl_all = [Inf, -Inf];
            for ri = 1:size(ROW_GROUPS_F4, 1)
                for ci = 1:length(ROW_GROUPS_F4{ri, 1})
                    wkey = ROW_GROUPS_F4{ri, 1}{ci};
                    idx_yl = find(strcmp(wt_names, wkey));
                    if isempty(idx_yl); continue; end
                    ww  = wMAP(idx_yl, :);
                    wws = W_std(idx_yl, :);
                    yl_all(1) = min(yl_all(1), min(ww - wws));
                    yl_all(2) = max(yl_all(2), max(ww + wws));
                end
            end
            if isfinite(yl_all(1)) && isfinite(yl_all(2))
                pad_yl = (yl_all(2) - yl_all(1)) * 0.05;
                if pad_yl == 0; pad_yl = 0.5; end
                yl_all = [yl_all(1) - pad_yl, yl_all(2) + pad_yl];
            else
                yl_all = [];
            end

            % --- Generate one figure per row group ---
            % Pixel-based sizing so panels are the SAME size across figures,
            % and labels never get clipped regardless of panel count.
            PANEL_W_PX = 380;
            PANEL_H_PX = 300;
            MG_L_PX    = 85;   % room for ylabel + y-tick labels
            MG_R_PX    = 45;   % room for last x-tick (600) not to clip
            MG_T_PX    = 55;   % room for title
            MG_B_PX    = 85;   % room for xlabel + x-tick labels
            GAP_PX     = 55;

            for ri = 1:size(ROW_GROUPS_F4, 1)
                row_keys     = ROW_GROUPS_F4{ri, 1};
                row_filetag  = ROW_GROUPS_F4{ri, 2};
                n_panels     = length(row_keys);

                fig_w_row = MG_L_PX + n_panels*PANEL_W_PX + (n_panels-1)*GAP_PX + MG_R_PX;
                fig_h_row = MG_T_PX + PANEL_H_PX + MG_B_PX;
                figure('Position', [50 50 fig_w_row fig_h_row], ...
                    'Visible', 'off', 'Color', 'w');

                % Normalized positions derived from pixel intents
                panel_w_n = PANEL_W_PX / fig_w_row;
                panel_h_n = PANEL_H_PX / fig_h_row;
                mg_l_n    = MG_L_PX    / fig_w_row;
                mg_b_n    = MG_B_PX    / fig_h_row;
                gap_n     = GAP_PX     / fig_w_row;

                any_panel = false;
                for ci = 1:n_panels
                    wkey = row_keys{ci};
                    idx  = find(strcmp(wt_names, wkey));
                    ax_l_n = mg_l_n + (ci-1) * (panel_w_n + gap_n);
                    axes('Position', [ax_l_n, mg_b_n, panel_w_n, panel_h_n]); %#ok<LAXES>

                    if isempty(idx)
                        set(gca, 'Visible', 'off');
                        continue;
                    end
                    any_panel = true;
                    w  = wMAP(idx, :);
                    ws = W_std(idx, :);
                    if isfield(COLOR_MAP, wkey); col = COLOR_MAP.(wkey); else; col = [0.3 0.3 0.3]; end
                    disp_name = DISPLAY_NAME_MAP.(wkey);

                    fill([trials; flipud(trials)], ...
                         [w' - ws'; flipud(w' + ws')], ...
                         col, 'FaceAlpha', 0.3, 'EdgeColor', 'none', 'HandleVisibility', 'off'); hold on;
                    plot(trials, w, 'Color', col, 'LineWidth', 2);
                    yline(0, '--', 'Color', [0.5 0.5 0.5], 'Alpha', 0.5, 'HandleVisibility', 'off');
                    xlabel('Trials', 'FontWeight', 'bold', 'FontSize', 14);
                    if ci == 1
                        ylabel('Weight', 'FontWeight', 'bold', 'FontSize', 14);
                    end
                    title(disp_name, 'FontSize', 13, 'FontWeight', 'bold');
                    style_axes(gca);
                    if ~isempty(yl_all); ylim(yl_all); end
                    set(gca, 'XTick', [0 300 600]);
                    set(gca, 'YTick', [-2 2 6]);
                end

                if any_panel
                    set(gcf, 'Visible', 'on');
                    saveas(gcf, fullfile(output_dir, ...
                        sprintf('%s_%s_%s.fig', fish_id, ml_display, row_filetag)));
                    saveas(gcf, fullfile(output_dir, ...
                        sprintf('%s_%s_%s.png', fish_id, ml_display, row_filetag)));
                end
                close(gcf);
            end

        else
            % ---- Figure 2: original auto-layout ----
            % Determine ordered subset of weights to plot
            % Follows DESIRED_ORDER; SB2 (Fig 3) excluded (redundant).
            plot_keys = {};
            plot_rows = [];
            for di = 1:length(DESIRED_ORDER)
                key = DESIRED_ORDER{di};
                idx = find(strcmp(wt_names, key));
                if ~isempty(idx)
                    plot_keys{end+1} = key; %#ok<AGROW>
                    plot_rows(end+1)  = idx; %#ok<AGROW>
                end
            end
            K_plot = length(plot_keys);

            % Subplot layout based on count
            if K_plot <= 3
                n_rows = 1; n_cols = K_plot;
                fig_w = 500 * K_plot; fig_h = 450;
            elseif K_plot <= 4
                n_rows = 2; n_cols = 2;
                fig_w = 1000; fig_h = 800;
            elseif K_plot <= 6
                n_rows = 2; n_cols = 3;
                fig_w = 1400; fig_h = 800;
            else
                n_rows = 3; n_cols = 3;
                fig_w = 1400; fig_h = 1000;
            end

            figure('Position', [50 50 fig_w fig_h], 'Visible', 'off', 'Color', 'w');
            for ki = 1:K_plot
                k    = plot_rows(ki);
                wkey = plot_keys{ki};
                w  = wMAP(k, :);
                ws = W_std(k, :);
                if isfield(COLOR_MAP, wkey); col = COLOR_MAP.(wkey); else; col = [0.3 0.3 0.3]; end
                disp_name = DISPLAY_NAME_MAP.(wkey);

                subplot(n_rows, n_cols, ki);
                fill([trials; flipud(trials)], ...
                     [w' - ws'; flipud(w' + ws')], ...
                     col, 'FaceAlpha', 0.3, 'EdgeColor', 'none', 'HandleVisibility', 'off'); hold on;
                plot(trials, w, 'Color', col, 'LineWidth', 2);
                yline(0, '--', 'Color', [0.5 0.5 0.5], 'Alpha', 0.5, 'HandleVisibility', 'off');
                xlabel('Trials', 'FontWeight', 'bold', 'FontSize', 16);
                ylabel('Weight', 'FontWeight', 'bold', 'FontSize', 16);
                title(disp_name, 'FontSize', 12, 'FontWeight', 'bold');
                style_axes(gca);
            end
            sgtitle(sprintf('Fish %d Decision-making variables', fish_num), ...
                'FontSize', 18, 'FontWeight', 'bold');
            set(gcf, 'Visible', 'on');
            saveas(gcf, fullfile(output_dir, sprintf('%s_%s_weights.fig', fish_id, ml_display)));
            saveas(gcf, fullfile(output_dir, sprintf('%s_%s_weights.png', fish_id, ml_display)));
            close(gcf);
        end

        % --- MODEL FIT: smoothed actual vs prediction ---
        figure('Position', [50 50 700 500], 'Visible', 'off', 'Color', 'w');

        actual_smooth = movmean(y01, SMOOTH_WIN, 'omitnan');
        pred_smooth   = movmean(pred, SMOOTH_WIN, 'omitnan');
        if ~isnan(p_prior)
            actual_smooth = normalize_acc(actual_smooth, p_prior);
            pred_smooth   = normalize_acc(pred_smooth,   p_prior);
        end
        plot(trials, actual_smooth, 'k-', 'LineWidth', 2); hold on;
        plot(trials, pred_smooth, '--', 'Color', model_colors(m,:), 'LineWidth', 2);
        yline(0.5, ':', 'LineWidth', 1.1, 'Color', [0.20 0.20 0.20], 'HandleVisibility', 'off');
        xlabel('Trials', 'FontWeight', 'bold', 'FontSize', 16);
        ylabel('Accuracy', 'FontWeight', 'bold', 'FontSize', 16);
        ylim([0 1]);
        title(sprintf('%s - %s Fit (BIC=%.1f, AUC=%.3f)', ...
            fish_id, MODEL_NAMES{m}, bic_m, auc_m), 'FontSize', 18, 'FontWeight', 'bold');
        lgd = legend({'Actual', 'Predicted'}, 'Location', 'best');
        set(lgd, 'Box', 'off');
        style_axes(gca);
        set(gca, 'YTick', [0 0.5 1], 'XTick', [0 300 600]);

        set(gcf, 'Visible', 'on');
        saveas(gcf, fullfile(output_dir, sprintf('%s_%s_fit.fig', fish_id, ml_display)));
        saveas(gcf, fullfile(output_dir, sprintf('%s_%s_fit.png', fish_id, ml_display)));
        close(gcf);

        fprintf('Saved: %s weights + fit\n', ml_display);
    end

    %% ====================================================================
    % PER-LOCATION RUNNING ACCURACY (single figure, not per-model)
    % =====================================================================
    figure('Position', [50 50 700 500], 'Visible', 'off', 'Color', 'w');

    for p = 1:n_loc
        col_idx = min(p, size(LOCATION_COLORS, 1));
        plot(trials, loc_running{p}, 'Color', LOCATION_COLORS(col_idx,:), 'LineWidth', 2); hold on;
    end
    yline(0.5, ':', 'LineWidth', 1.1, 'Color', [0.20 0.20 0.20], 'HandleVisibility', 'off');
    xlabel('Trials', 'FontWeight', 'bold', 'FontSize', 16);
    ylabel('Running Acc', 'FontWeight', 'bold', 'FontSize', 16);
    title(sprintf('%s - Per-%s Running Accuracy (±15 window)', fish_id, LOCATION_LABEL), ...
        'FontSize', 18, 'FontWeight', 'bold');
    lgd = legend(loc_labels, 'Location', 'best');
    set(lgd, 'Box', 'off');
    style_axes(gca);
    set(gca, 'YTick', [0 0.5 1]);

    set(gcf, 'Visible', 'on');
    saveas(gcf, fullfile(output_dir, [fish_id '_per_location_accuracy.fig']));
    saveas(gcf, fullfile(output_dir, [fish_id '_per_location_accuracy.png']));
    close(gcf);
    fprintf('Saved: per-%s running accuracy\n', lower(LOCATION_LABEL));

    %% ====================================================================
    % ALL MODELS FIT OVERLAY
    % =====================================================================
    figure('Position', [50 50 1200 500], 'Visible', 'off', 'Color', 'w');

    actual_smooth_all = movmean(y01, SMOOTH_WIN, 'omitnan');
    if ~isnan(p_prior); actual_smooth_all = normalize_acc(actual_smooth_all, p_prior); end
    plot(trials, actual_smooth_all, 'k-', 'LineWidth', 2.5); hold on;
    for m = 1:N_MODELS
        ml_mat = MAT_MODEL_SHORT{m};
        pred = d.([ml_mat '_predictions']);
        pred_s = movmean(pred, SMOOTH_WIN, 'omitnan');
        if ~isnan(p_prior); pred_s = normalize_acc(pred_s, p_prior); end
        plot(trials, pred_s, '-', 'Color', model_colors(m,:), 'LineWidth', 1.5);
    end
    yline(0.5, ':', 'LineWidth', 1.1, 'Color', [0.20 0.20 0.20], 'HandleVisibility', 'off');
    xlabel('Trials', 'FontWeight', 'bold', 'FontSize', 16);
    ylabel('Accuracy', 'FontWeight', 'bold', 'FontSize', 16);
    ylim([0 1]);
    title(sprintf('%s - All Models vs Actual (win=%d)', fish_id, SMOOTH_WIN), ...
        'FontSize', 18, 'FontWeight', 'bold');
    lgd = legend([{'Actual'}, MODEL_SHORT], 'Location', 'best', 'FontSize', 9);
    set(lgd, 'Box', 'off');
    style_axes(gca);
    set(gca, 'YTick', [0 0.5 1]);

    set(gcf, 'Visible', 'on');
    saveas(gcf, fullfile(output_dir, [fish_id '_all_models_fit.fig']));
    saveas(gcf, fullfile(output_dir, [fish_id '_all_models_fit.png']));
    close(gcf);
    fprintf('Saved: all models overlay\n');

    %% ====================================================================
    % CONSOLE SUMMARY (per fish)
    % =====================================================================
    fprintf('\n%s\n', repmat('-', 1, 70));
    fprintf('MODEL SUMMARY: %s\n', fish_id);
    fprintf('%s\n', repmat('-', 1, 70));
    fprintf('\n%-30s %10s %10s %10s\n', 'Model', 'BIC', 'AUC', 'nParams');
    fprintf('%s\n', repmat('-', 1, 65));
    for m = 1:N_MODELS
        ml_mat = MAT_MODEL_SHORT{m};
        K = size(d.([ml_mat '_weights']), 1);
        marker = ''; if m == best_model; marker = ' ***'; end
        fprintf('%-30s %10.1f %10.3f %10d%s\n', MODEL_NAMES{m}, all_bic(m), all_auc(m), K, marker);
    end

    fprintf('\n  Weight details per model:\n');
    for m = 1:N_MODELS
        ml_mat = MAT_MODEL_SHORT{m};
        wMAP = d.([ml_mat '_weights']);
        sigmas = d.([ml_mat '_sigmas']);
        wt_names = WT_NAMES{m};
        K = size(wMAP, 1);
        fprintf('\n  %s:\n', MODEL_NAMES{m});
        fprintf('    %-12s %10s %10s %10s %10s\n', 'Weight', 'Mean', 'Min', 'Max', 'Sigma');
        for k = 1:K
            w = wMAP(k, :);
            fprintf('    %-12s %+10.3f %+10.3f %+10.3f %10.4f\n', ...
                wt_names{k}, mean(w), min(w), max(w), sigmas(k));
        end
    end

    fprintf('\nAll plots saved to: %s\n', output_dir);

end  % end fish loop

%% ========================================================================
% BEST MODEL ACROSS ALL FISH (auto-detect Fish_1, Fish_2, ...)
% =========================================================================

fprintf('\n%s\n', repmat('=', 1, 70));
fprintf('CROSS-FISH BEST MODEL SUMMARY (Figure %d)\n', FIGURE_NUM);
fprintf('%s\n', repmat('=', 1, 70));

% Auto-detect all Fish_X folders in the figure directory
fish_folders = dir(fullfile(FIGURE_FOLDER, 'Fish_*'));
fish_folders = fish_folders([fish_folders.isdir]);

best_models_all = [];
fish_labels_all = {};

for f = 1:length(fish_folders)
    fname = fish_folders(f).name;
    mat_path = fullfile(FIGURE_FOLDER, fname, [fname '_analysis.mat']);
    if ~isfile(mat_path)
        fprintf('  %s: .mat not found, skipping\n', fname);
        continue;
    end
    tmp = load(mat_path, 'all_bic');
    if ~isfield(tmp, 'all_bic')
        fprintf('  %s: no all_bic field, skipping\n', fname);
        continue;
    end
    % Apply remap to find best model in remapped order
    bic_remapped = tmp.all_bic(MODEL_REMAP);
    [~, bm] = min(bic_remapped);
    best_models_all(end+1) = bm; %#ok<SAGROW>
    fish_labels_all{end+1} = fname; %#ok<SAGROW>
    fprintf('  %s: best = %s (BIC=%.1f)\n', fname, MODEL_SHORT{bm}, bic_remapped(bm));
end

if ~isempty(best_models_all)
    figure('Position', [50 50 700 500], 'Color', 'w');

    best_counts = histcounts(best_models_all, 0.5:N_MODELS+0.5);
    b = bar(1:N_MODELS, best_counts, 'FaceColor', 'flat', 'EdgeColor', 'none');
    b.CData = model_colors;
    set(gca, 'XTick', 1:N_MODELS, 'XTickLabel', MODEL_SHORT);
    ylabel('Number of Fish', 'FontWeight', 'bold', 'FontSize', 16);
    xlabel('Model', 'FontWeight', 'bold', 'FontSize', 16);
    title(sprintf('Best Model by BIC - Figure %d (n=%d fish)', FIGURE_NUM, length(best_models_all)), ...
        'FontSize', 14, 'FontWeight', 'bold');
    ylim([0 max(best_counts)+1]);
    set(gca, 'YTick', 0:max(best_counts)+1);
    style_axes(gca);

    save_path = fullfile(FIGURE_FOLDER, sprintf('Best_Model_All_Fish_Fig%d', FIGURE_NUM));
    set(gcf, 'Visible', 'on');
    saveas(gcf, [save_path '.fig']);
    saveas(gcf, [save_path '.png']);
    close(gcf);
    fprintf('Saved: Best Model bar plot -> %s\n', save_path);
else
    fprintf('  No fish data found for best model plot.\n');
end

fprintf('\nDone!\n');

%% ========================================================================
% M4 vs BEST HISTORY MODEL – BIC COMPARISON ACROSS ALL FISH
% =========================================================================
% Scans BOTH Figure 2 (7-model) and Figure 3 (5-model) folders.
%   Figure 2 fish: M4 BIC vs min(M5,M6,M7) BIC  ("best history")
%   Figure 3 fish: M4 BIC vs M5 BIC
% Produces a figure matching the attached reference:
%   - Grey bar (without history / M4) and green bar (with history / best M5+)
%   - Mean ± std as bar height + error bar
%   - Individual fish as open circles connected by thin lines
% =========================================================================

fprintf('\n%s\n', repmat('=', 1, 70));
fprintf('M4 vs BEST-HISTORY BIC COMPARISON (all fish)\n');
fprintf('%s\n', repmat('=', 1, 70));

bic_m4_all      = [];   % M4 BIC per fish
bic_hist_all    = [];   % best M5+ BIC per fish
fish_label_comp = {};   % label for each fish

% ---------- Scan Figure 2 folder (7 models: M4 vs best of M5-M7) ----------
fig3_folder = fullfile(BASE_ROOT, 'FIGURE 2');
if isfolder(fig3_folder)
    f3_dirs = dir(fullfile(fig3_folder, 'Fish_*'));
    f3_dirs = f3_dirs([f3_dirs.isdir]);
    for fi = 1:length(f3_dirs)
        fpath = fullfile(fig3_folder, f3_dirs(fi).name, [f3_dirs(fi).name '_analysis.mat']);
        if ~isfile(fpath); continue; end
        tmp = load(fpath, 'all_bic');
        if ~isfield(tmp,'all_bic') || length(tmp.all_bic) < 7; continue; end
        bm4  = tmp.all_bic(4);
        bhist = min(tmp.all_bic(5:7));   % best of M5,M6,M7
        bic_m4_all(end+1)   = bm4;   %#ok<SAGROW>
        bic_hist_all(end+1) = bhist; %#ok<SAGROW>
        fish_label_comp{end+1} = f3_dirs(fi).name; %#ok<SAGROW>
        fprintf('  [Fig3] %s  M4=%.1f  BestHist=%.1f  (Δ=%.1f)\n', ...
            f3_dirs(fi).name, bm4, bhist, bm4-bhist);
    end
else
    fprintf('  Figure 2 folder not found: %s\n', fig3_folder);
end

% ---------- Scan Figure 3 folder (5 models: M4 vs M5) ----------
fig4_folder = fullfile(BASE_ROOT, 'FIGURE 3');
if isfolder(fig4_folder)
    f4_dirs = dir(fullfile(fig4_folder, 'Fish_*'));
    f4_dirs = f4_dirs([f4_dirs.isdir]);
    for fi = 1:length(f4_dirs)
        fpath = fullfile(fig4_folder, f4_dirs(fi).name, [f4_dirs(fi).name '_analysis.mat']);
        if ~isfile(fpath); continue; end
        tmp = load(fpath, 'all_bic');
        if ~isfield(tmp,'all_bic') || length(tmp.all_bic) < 5; continue; end
        bm4  = tmp.all_bic(4);
        bhist = tmp.all_bic(5);           % only M5 available
        bic_m4_all(end+1)   = bm4;   %#ok<SAGROW>
        bic_hist_all(end+1) = bhist; %#ok<SAGROW>
        fish_label_comp{end+1} = f4_dirs(fi).name; %#ok<SAGROW>
        fprintf('  [Fig4] %s  M4=%.1f  M5=%.1f        (Δ=%.1f)\n', ...
            f4_dirs(fi).name, bm4, bhist, bm4-bhist);
    end
else
    fprintf('  Figure 3 folder not found: %s\n', fig4_folder);
end

n_fish_comp = length(bic_m4_all);
if n_fish_comp == 0
    fprintf('  No fish data found for M4 vs best-history comparison.\n');
else
    % ---- Statistics ----
    mean_m4   = mean(bic_m4_all);   std_m4   = std(bic_m4_all);
    mean_hist = mean(bic_hist_all); std_hist = std(bic_hist_all);

    fprintf('\n  n=%d fish\n', n_fish_comp);
    fprintf('  M4 (without history): mean=%.1f  std=%.1f\n', mean_m4,   std_m4);
    fprintf('  Best M5+  (history) : mean=%.1f  std=%.1f\n', mean_hist, std_hist);

    % ---- Colours (match reference image) ----
    COL_M4   = [0.65 0.65 0.65];   % grey
    COL_HIST = [0.45 0.65 0.15];   % olive/green
    COL_LINE = [0.40 0.40 0.40];   % connecting line colour
    COL_PT   = [0.20 0.20 0.20];   % dot edge colour

    % ---- Jitter x-positions so overlapping points are visible ----
    rng(42);   % reproducible jitter
    jitter_amt = 0.08;
    x_m4   = 1 + (rand(1,n_fish_comp)-0.5)*2*jitter_amt;
    x_hist = 2 + (rand(1,n_fish_comp)-0.5)*2*jitter_amt;

    figure('Position', [100 100 550 600], 'Color', 'w');

    % Mean bars
    b1 = bar(1, mean_m4,   0.55, 'FaceColor', COL_M4,   'EdgeColor', 'none'); hold on;
    b2 = bar(2, mean_hist, 0.55, 'FaceColor', COL_HIST,  'EdgeColor', 'none');

    % Std error bars (cap style)
    errorbar(1, mean_m4,   std_m4,   'k-', 'LineWidth', 2.2, 'CapSize', 14);
    errorbar(2, mean_hist, std_hist, 'k-', 'LineWidth', 2.2, 'CapSize', 14);

    % Connecting lines (draw first so dots appear on top)
    for fi = 1:n_fish_comp
        plot([x_m4(fi), x_hist(fi)], [bic_m4_all(fi), bic_hist_all(fi)], ...
             '-', 'Color', [COL_LINE 0.55], 'LineWidth', 1.1);
    end

    % Individual fish dots
    for fi = 1:n_fish_comp
        plot(x_m4(fi),   bic_m4_all(fi),   'o', ...
             'MarkerSize', 9, 'LineWidth', 1.5, ...
             'MarkerFaceColor', 'w', 'MarkerEdgeColor', COL_PT);
        plot(x_hist(fi), bic_hist_all(fi), 'o', ...
             'MarkerSize', 9, 'LineWidth', 1.5, ...
             'MarkerFaceColor', 'w', 'MarkerEdgeColor', COL_PT);
    end

    % Axes cosmetics
    xlim([0.3 2.7]);
    set(gca, 'XTick', [1 2], ...
             'XTickLabel', {'without history', 'with history'}, ...
             'XTickLabelRotation', 0, ...
             'FontSize', 16, 'FontWeight', 'bold');
    ylabel('BIC', 'FontWeight', 'bold', 'FontSize', 18);
    title(sprintf('M4 vs Best History Model  (n=%d fish)', n_fish_comp), ...
          'FontSize', 15, 'FontWeight', 'bold');
    style_axes(gca);

    % Auto y-limits with 5% padding
    all_vals = [bic_m4_all, bic_hist_all];
    ylo = min(all_vals); yhi = max(all_vals);
    pad = (yhi - ylo) * 0.12;
    ylim([ylo - pad, yhi + pad]);

    % Save alongside Figure 3 outputs (or Figure 2 if Fig 4 not found)
    comp_fig4_dir = fullfile(BASE_ROOT, 'FIGURE 4');
    if ~isfolder(comp_fig4_dir); mkdir(comp_fig4_dir); end
    comp_save_base = fullfile(comp_fig4_dir, 'M4_vs_BestHistory_BIC_AllFish');
    set(gcf, 'Visible', 'on');
    saveas(gcf, [comp_save_base '.fig']);
    saveas(gcf, [comp_save_base '.png']);
    close(gcf);
    fprintf('Saved: M4 vs best-history BIC plot -> %s\n', comp_save_base);
end

end  % if ~COMBINED_ONLY

%% ========================================================================
% COMBINED 3-FISH FIGURES (Figure 2 only) — 3 separate figures
% =========================================================================
% Produces 3 standalone figures for the fish specified in COMB_FISH:
%   Fig A: Best-model accuracy fit (1×3)
%   Fig B: Target position 1 | Target position 2 | Spatial bias (1×9 grouped)
%   Fig C: Shape persistence | Win-stay | Lose-stay (1×9 grouped, blank if absent)
% =========================================================================

if FIGURE_NUM == 2 && length(COMB_FISH) == 3 && ~RUN_PERSISTENCE_TEST

    fprintf('\n%s\n', repmat('=', 1, 70));
    fprintf('COMBINED 3-FISH FIGURES: Fish %d, %d, %d\n', COMB_FISH(1), COMB_FISH(2), COMB_FISH(3));
    fprintf('%s\n', repmat('=', 1, 70));

    % Weight keys and labels
    ROW2_KEYS   = {'P1', 'P2', 'SB1'};
    ROW2_LABELS = {'Target position 1', 'Target position 2', 'Spatial bias'};
    ROW3_KEYS   = {'Persist', 'WinStay', 'LoseStay'};
    ROW3_LABELS = {'Shape persistence', 'Win-stay', 'Lose-stay'};

    % Font sizes from COMB_FONT
    fnt_t = COMB_FONT;        % titles
    fnt_l = COMB_FONT;        % axis labels
    fnt_k = COMB_FONT - 2;    % tick labels
    fnt_g = COMB_FONT - 1;    % legend

    % Load the 3 fish
    comb_fd = struct();
    all_ok = true;
    for ci = 1:3
        fn = COMB_FISH(ci);
        folder = sprintf('Fish_%d', fn);
        mpath  = fullfile(FIGURE_FOLDER, folder, [folder '_analysis.mat']);
        if ~isfile(mpath)
            fprintf('  ERROR: %s not found.\n', mpath);
            all_ok = false; continue;
        end
        dd = load(mpath);
        [~, bm] = min(dd.all_bic);
        ml = MODEL_SHORT_ORIG{bm};
        comb_fd(ci).fish_num   = fn;
        comb_fd(ci).best_model = bm;
        comb_fd(ci).best_label = MODEL_SHORT_ORIG{bm};
        comb_fd(ci).trials     = dd.trials;
        comb_fd(ci).outcome    = dd.outcome;
        comb_fd(ci).wMAP       = dd.([ml '_weights']);
        comb_fd(ci).W_std      = dd.([ml '_weights_std']);
        comb_fd(ci).pred       = dd.([ml '_predictions']);
        comb_fd(ci).bic        = dd.([ml '_bic']);
        comb_fd(ci).wt_names   = WT_NAMES_ORIG{bm};
    end

    fish_tag = sprintf('%d_%d_%d', COMB_FISH(1), COMB_FISH(2), COMB_FISH(3));

    if all_ok

    % ---- FIGURE A: Accuracy fits (1×3) ----
    figure('Position', [30 30 1500 420], 'Visible', 'off', 'Color', 'w');
    mg = struct('l',0.06,'r',0.02,'t',0.06,'b',0.15,'gap',0.05);
    pw = (1 - mg.l - mg.r - 2*mg.gap) / 3;
    ph = 1 - mg.t - mg.b;

    for col = 1:3
        fd = comb_fd(col);
        axes('Position', [mg.l + (col-1)*(pw+mg.gap), mg.b, pw, ph]);

        actual_s = movmean(fd.outcome, SMOOTH_WIN, 'omitnan');
        pred_s   = movmean(fd.pred,    SMOOTH_WIN, 'omitnan');
        if ~isnan(p_prior)
            actual_s = normalize_acc(actual_s, p_prior);
            pred_s   = normalize_acc(pred_s,   p_prior);
        end
        plot(fd.trials, actual_s, 'k-', 'LineWidth', 2); hold on;
        plot(fd.trials, pred_s, '--', 'Color', MODEL_COLORS_ORIG(fd.best_model,:), 'LineWidth', 2);
        yline(0.5, ':', 'LineWidth', 1.1, 'Color', [0.20 0.20 0.20], 'HandleVisibility', 'off');
        xlabel('Trials', 'FontWeight', 'bold', 'FontSize', fnt_l);
        if col == 1
            ylabel('Accuracy', 'FontWeight', 'bold', 'FontSize', fnt_l);
            lgd = legend({'Behavioral', 'Fit'}, 'Location', 'best', 'FontSize', fnt_g);
            set(lgd, 'Box', 'off');
        end
        ylim([0 1]); set(gca, 'YTick', [0 0.5 1], 'XTick', [0 300 600]);
        title(sprintf('Fish %d - %s (BIC=%.0f)', fd.fish_num, fd.best_label, fd.bic), ...
            'FontSize', fnt_t, 'FontWeight', 'bold');
        set(gca, 'FontSize', fnt_k, 'FontWeight', 'bold', 'TickDir', 'out', 'LineWidth', 1.2);
        box off;
    end

    set(gcf, 'Visible', 'on');
    sA = fullfile(FIGURE_FOLDER, sprintf('Combined_%s_accuracy', fish_tag));
    saveas(gcf, [sA '.fig']); saveas(gcf, [sA '.png']); close(gcf);
    fprintf('  Saved: %s\n', sA);

    % ---- Helper for weight figures (1×9 grouped as 3 groups of 3) ----
    % Shared layout for Fig B and Fig C
    mg9 = struct('l',0.05,'r',0.01,'t',0.08,'b',0.16, ...
                 'grp_gap',0.045,'sub_gap',0.015);
    usable_w9 = 1 - mg9.l - mg9.r;
    grp_w9    = (usable_w9 - 2*mg9.grp_gap) / 3;
    sub_w9    = (grp_w9 - 2*mg9.sub_gap) / 3;
    ph9       = 1 - mg9.t - mg9.b;
    grp_left9 = mg9.l + (0:2) .* (grp_w9 + mg9.grp_gap);

    % ---- Pre-compute common y-limits for Fig B (spatial weights) ----
    ylim_B = [Inf, -Inf];
    for col = 1:3
        fd = comb_fd(col);
        for ri = 1:3
            k = find(strcmp(fd.wt_names, ROW2_KEYS{ri}));
            if isempty(k); continue; end
            w = fd.wMAP(k,:); ws = fd.W_std(k,:);
            ylim_B(1) = min(ylim_B(1), min(w - ws));
            ylim_B(2) = max(ylim_B(2), max(w + ws));
        end
    end
    pad_B = (ylim_B(2) - ylim_B(1)) * 0.08;
    ylim_B = [ylim_B(1) - pad_B, ylim_B(2) + pad_B];

    % ---- Pre-compute common y-limits for Fig C (history weights) ----
    ylim_C = [Inf, -Inf];
    any_C = false;
    for col = 1:3
        fd = comb_fd(col);
        for ri = 1:3
            k = find(strcmp(fd.wt_names, ROW3_KEYS{ri}));
            if isempty(k); continue; end
            any_C = true;
            w = fd.wMAP(k,:); ws = fd.W_std(k,:);
            ylim_C(1) = min(ylim_C(1), min(w - ws));
            ylim_C(2) = max(ylim_C(2), max(w + ws));
        end
    end
    if any_C
        pad_C = (ylim_C(2) - ylim_C(1)) * 0.08;
        ylim_C = [ylim_C(1) - pad_C, ylim_C(2) + pad_C];
    end

    % ---- FIGURE B: Target position 1 / Target position 2 / Spatial bias ----
    figure('Position', [30 30 1700 380], 'Visible', 'off', 'Color', 'w');

    for col = 1:3
        fd = comb_fd(col);
        for ri = 1:3
            ax_l = grp_left9(col) + (ri-1)*(sub_w9 + mg9.sub_gap);
            axes('Position', [ax_l, mg9.b, sub_w9, ph9]);

            wkey = ROW2_KEYS{ri};
            k = find(strcmp(fd.wt_names, wkey));
            if isempty(k); set(gca, 'Visible', 'off'); continue; end
            w = fd.wMAP(k,:); ws = fd.W_std(k,:);
            if isfield(COLOR_MAP, wkey); cw = COLOR_MAP.(wkey); else; cw = [0.3 0.3 0.3]; end

            fill([fd.trials; flipud(fd.trials)], [w'-ws'; flipud(w'+ws')], ...
                 cw, 'FaceAlpha', 0.3, 'EdgeColor', 'none'); hold on;
            plot(fd.trials, w, 'Color', cw, 'LineWidth', 1.8);
            yline(0, '--', 'Color', [0.5 0.5 0.5], 'Alpha', 0.5);
            ylim(ylim_B);
            xlabel('Trials', 'FontWeight', 'bold', 'FontSize', fnt_l-1);
            if col == 1 && ri == 1
                ylabel('Weight', 'FontWeight', 'bold', 'FontSize', fnt_l);
            end
            if col == 1
                title(ROW2_LABELS{ri}, 'FontSize', fnt_t-1, 'FontWeight', 'bold');
            end
            set(gca, 'FontSize', fnt_k, 'FontWeight', 'bold', 'TickDir', 'out', 'LineWidth', 1.2, ...
                'XTick', [0 300 600], 'YTick', [-4 0 4]);
            box off;
        end
    end

    set(gcf, 'Visible', 'on');
    sB = fullfile(FIGURE_FOLDER, sprintf('Combined_%s_spatial_weights', fish_tag));
    saveas(gcf, [sB '.fig']); saveas(gcf, [sB '.png']); close(gcf);
    fprintf('  Saved: %s\n', sB);

    % ---- FIGURE C: Shape persistence / Win-stay / Lose-stay ----
    figure('Position', [30 30 1700 380], 'Visible', 'off', 'Color', 'w');

    any_weight_plotted = false;
    for col = 1:3
        fd = comb_fd(col);
        for ri = 1:3
            ax_l = grp_left9(col) + (ri-1)*(sub_w9 + mg9.sub_gap);
            axes('Position', [ax_l, mg9.b, sub_w9, ph9]);

            wkey = ROW3_KEYS{ri};
            k = find(strcmp(fd.wt_names, wkey));
            if isempty(k); set(gca, 'Visible', 'off'); continue; end
            any_weight_plotted = true;
            w = fd.wMAP(k,:); ws = fd.W_std(k,:);
            if isfield(COLOR_MAP, wkey); cw = COLOR_MAP.(wkey); else; cw = [0.3 0.3 0.3]; end

            fill([fd.trials; flipud(fd.trials)], [w'-ws'; flipud(w'+ws')], ...
                 cw, 'FaceAlpha', 0.3, 'EdgeColor', 'none'); hold on;
            plot(fd.trials, w, 'Color', cw, 'LineWidth', 1.8);
            yline(0, '--', 'Color', [0.5 0.5 0.5], 'Alpha', 0.5);
            ylim(ylim_C);
            xlabel('Trials', 'FontWeight', 'bold', 'FontSize', fnt_l-1);
            if col == 1 && ri == 1
                ylabel('Weight', 'FontWeight', 'bold', 'FontSize', fnt_l);
            end
            if col == 1
                title(ROW3_LABELS{ri}, 'FontSize', fnt_t-1, 'FontWeight', 'bold');
            end
            set(gca, 'FontSize', fnt_k, 'FontWeight', 'bold', 'TickDir', 'out', 'LineWidth', 1.2, ...
                'XTick', [0 300 600], 'YTick', [-2 0 2]);
            box off;
        end
    end

    if any_weight_plotted
        set(gcf, 'Visible', 'on');
        sC = fullfile(FIGURE_FOLDER, sprintf('Combined_%s_history_weights', fish_tag));
        saveas(gcf, [sC '.fig']); saveas(gcf, [sC '.png']); close(gcf);
        fprintf('  Saved: %s\n', sC);
    else
        close(gcf);
        fprintf('  Skipped history weights figure (no fish had these weights).\n');
    end

    % ---- FIGURE D: Sliding-window per-position persistence test (2×3) ----
    % Row 1: trajectory of observed P(repeat) per sliding window vs null mean
    %        + 95% null envelope (shaded).
    % Row 2: trajectory of z-score per window position with ±1.96 reference.
    figure('Position', [30 30 1500 800], 'Visible', 'off', 'Color', 'w');
    mgD = struct('l',0.06,'r',0.02,'t',0.05,'b',0.09,'col_gap',0.05,'row_gap',0.10);
    pwD = (1 - mgD.l - mgD.r - 2*mgD.col_gap) / 3;
    phD = (1 - mgD.t - mgD.b - mgD.row_gap) / 2;
    row1_bot = mgD.b + phD + mgD.row_gap;
    row2_bot = mgD.b;

    fprintf('\n  Running sliding-window permutation test (window %d, step %d, %d perms per window)...\n', ...
        PERS_WIN_SIZE, PERS_STEP, PERS_N_PERM_WIN);

    rng(42);  % reproducible permutations
    diff_data = cell(1, 3);
    for col = 1:3
        fd  = comb_fd(col);
        outc = fd.outcome(:); N = length(outc);
        n_w  = PERS_WIN_SIZE;
        max_pairs = n_w - 1;

        % Slide window across trials, FRESH shuffles at each position
        n_pos = floor((N - n_w) / PERS_STEP) + 1;
        center_t      = nan(N, 1);
        p_obs_t       = nan(N, 1);
        p_null_mean_t = nan(N, 1);
        p_null_lo_t   = nan(N, 1);
        p_null_hi_t   = nan(N, 1);
        z_t           = nan(N, 1);
        null_sd_t     = nan(N, 1);

        for tt_idx = 1:n_pos
            tt  = (tt_idx - 1) * PERS_STEP + 1;
            ctr = tt + floor(n_w/2) - 1;
            win_outc = outc(tt:tt + n_w - 1);
            R_obs    = sum(win_outc(2:end) == win_outc(1:end-1));

            % Fresh permutations for THIS window position
            R_null = zeros(PERS_N_PERM_WIN, 1);
            for s = 1:PERS_N_PERM_WIN
                pp = win_outc(randperm(n_w));
                R_null(s) = sum(pp(2:end) == pp(1:end-1));
            end

            center_t(ctr)       = ctr;
            p_obs_t(ctr)        = R_obs / max_pairs;
            p_null_mean_t(ctr)  = mean(R_null) / max_pairs;
            p_null_lo_t(ctr)    = prctile(R_null, 2.5)  / max_pairs;
            p_null_hi_t(ctr)    = prctile(R_null, 97.5) / max_pairs;
            sd = std(R_null);
            null_sd_t(ctr) = sd;
            if sd > 0
                z_t(ctr) = (R_obs - mean(R_null)) / sd;
            else
                z_t(ctr) = NaN;   % degenerate window (no power)
            end
        end

        diff_data{col} = struct('p_obs_t', p_obs_t, ...
            'p_null_mean_t', p_null_mean_t, ...
            'p_null_lo_t',   p_null_lo_t, ...
            'p_null_hi_t',   p_null_hi_t, ...
            'z_t', z_t, 'null_sd_t', null_sd_t, ...
            'trials', fd.trials(:), 'fn', fd.fish_num);
    end

    % ---- Common z-axis range across fish (with 10% padding) ----
    z_all = vertcat(diff_data{1}.z_t, diff_data{2}.z_t, diff_data{3}.z_t);
    zlo = min(z_all, [], 'omitnan'); zhi = max(z_all, [], 'omitnan');
    zpad = max(abs([zlo zhi])) * 0.10;  if isempty(zpad) || zpad == 0; zpad = 0.5; end
    zlim_ = [min(zlo - zpad, -2.5), max(zhi + zpad, 2.5)];

    fprintf('\n  --- Sliding-window persistence test: significant windows ---\n');
    fprintf('  Window size: %d trials.  Step: %d.  Permutations per window: %d.\n', ...
        PERS_WIN_SIZE, PERS_STEP, PERS_N_PERM_WIN);
    fprintf('  A window is "significant persistence" if z > 1.96, "significant switching" if z < -1.96.\n');
    fprintf('  Under independence ~2.5%% in each tail.  Informative windows: null SD >= %.2f.\n', PERS_MIN_NULL_SD);

    for col = 1:3
        dd = diff_data{col};
        tr = dd.trials;

        % ---- Row 1: observed vs null mean + 95% null envelope ----
        axes('Position', [mgD.l + (col-1)*(pwD+mgD.col_gap), row1_bot, pwD, phD]);
        valid = ~isnan(dd.p_null_lo_t) & ~isnan(dd.p_null_hi_t);
        fill([tr(valid); flipud(tr(valid))], ...
             [dd.p_null_lo_t(valid); flipud(dd.p_null_hi_t(valid))], ...
             [0.70 0.70 0.70], 'FaceAlpha', 0.30, 'EdgeColor', 'none', 'HandleVisibility', 'off');
        hold on;
        h_null = plot(tr, dd.p_null_mean_t, 'Color', [0.45 0.45 0.45], 'LineWidth', 1.6, 'LineStyle', '--');
        h_obs  = plot(tr, dd.p_obs_t,       'Color', [0.20 0.40 0.80], 'LineWidth', 2);
        ylim([0 1]);
        if col == 1
            ylabel('P(repeat)', 'FontWeight', 'bold', 'FontSize', fnt_l);
            lgd = legend([h_obs h_null], {'Observed', 'Null mean (± 95%% per-window envelope)'}, ...
                'Location', 'best', 'FontSize', fnt_g);
            set(lgd, 'Box', 'off');
        end
        title(sprintf('Fish %d', dd.fn), 'FontSize', fnt_t, 'FontWeight', 'bold');
        set(gca, 'YTick', [0 0.5 1], 'XTick', [0 300 600], ...
            'FontSize', fnt_k, 'FontWeight', 'bold', 'TickDir', 'out', 'LineWidth', 1.2, ...
            'XTickLabel', []);
        box off;

        % ---- Identify significant windows ----
        informative = dd.null_sd_t >= PERS_MIN_NULL_SD;
        sig_rep    = informative & (dd.z_t >  1.96);
        sig_switch = informative & (dd.z_t < -1.96);

        % ---- Row 2: z-score trajectory with significant windows marked ----
        axes('Position', [mgD.l + (col-1)*(pwD+mgD.col_gap), row2_bot, pwD, phD]);
        hold on;
        yl = zlim_;
        % Faint vertical bands at significant window positions
        for ii = find(sig_rep)'
            patch([ii-0.5 ii+0.5 ii+0.5 ii-0.5], [yl(1) yl(1) yl(2) yl(2)], ...
                  [0.95 0.55 0.55], 'FaceAlpha', 0.35, 'EdgeColor', 'none', 'HandleVisibility', 'off');
        end
        for ii = find(sig_switch)'
            patch([ii-0.5 ii+0.5 ii+0.5 ii-0.5], [yl(1) yl(1) yl(2) yl(2)], ...
                  [0.55 0.70 0.95], 'FaceAlpha', 0.35, 'EdgeColor', 'none', 'HandleVisibility', 'off');
        end
        % Uninformative regions faded, informative in blue
        z_info = dd.z_t;  z_info(~informative) = NaN;
        z_uninfo = dd.z_t;  z_uninfo(informative) = NaN;
        plot(tr, z_uninfo, 'Color', [0.80 0.80 0.80], 'LineWidth', 1.2);
        plot(tr, z_info,   'Color', [0.20 0.40 0.80], 'LineWidth', 2);
        yline(0,     '-',  'Color', [0.30 0.30 0.30], 'LineWidth', 1.2, 'HandleVisibility', 'off');
        yline( 1.96, '--', 'Color', [0.50 0.50 0.50], 'LineWidth', 1.0, 'HandleVisibility', 'off');
        yline(-1.96, '--', 'Color', [0.50 0.50 0.50], 'LineWidth', 1.0, 'HandleVisibility', 'off');
        ylim(yl);
        xlabel('Trials', 'FontWeight', 'bold', 'FontSize', fnt_l);
        if col == 1
            ylabel('z-score per window', 'FontWeight', 'bold', 'FontSize', fnt_l);
        end
        set(gca, 'XTick', [0 300 600], ...
            'FontSize', fnt_k, 'FontWeight', 'bold', 'TickDir', 'out', 'LineWidth', 1.2);
        box off;

        % ---- Console: simple counts ----
        n_info   = sum(informative);
        n_rep    = sum(sig_rep);
        n_switch = sum(sig_switch);
        pct_rep    = 100 * n_rep    / n_info;
        pct_switch = 100 * n_switch / n_info;
        fprintf('    Fish %d:  %d/%d informative windows  |  significant persistence: %3d windows (%4.1f%%)  |  significant switching: %3d windows (%4.1f%%)\n', ...
            dd.fn, n_info, sum(~isnan(dd.null_sd_t)), n_rep, pct_rep, n_switch, pct_switch);
    end

    set(gcf, 'Visible', 'on');
    sD = fullfile(FIGURE_FOLDER, sprintf('Combined_%s_persistence_test', fish_tag));
    saveas(gcf, [sD '.fig']); saveas(gcf, [sD '.png']); close(gcf);
    fprintf('  Saved: %s\n', sD);

    fprintf('Done: 4 combined figures saved.\n');

    end  % if all_ok

elseif FIGURE_NUM == 2
    fprintf('\nCOMB_FISH must have exactly 3 fish numbers.\n');
end

%% ========================================================================
% ALL-FISH PERSISTENCE TEST (loops over every fish in FISH_LIST)
% =========================================================================
% For each fish, runs the same sliding-window permutation test as Figure D
% (using PERS_WIN_SIZE / PERS_STEP / PERS_N_PERM_WIN / PERS_MIN_NULL_SD)
% and reports the number of windows with significant persistence (z > 1.96)
% and significant switching (z < -1.96). Then pools across all fish and
% runs a binomial test against the 2.5%% chance level in each tail.
% Set FISH_LIST = 1:5 for Figure 2 fish, FISH_LIST = 6:14 for Figure 3 fish.

if RUN_PERSISTENCE_TEST && FIGURE_NUM == 2 && length(FISH_LIST) >= 2

    fprintf('\n%s\n', repmat('=', 1, 80));
    fprintf('ALL-FISH PERSISTENCE TEST: fish %s\n', mat2str(FISH_LIST));
    fprintf('%s\n', repmat('=', 1, 80));
    fprintf('  Window size: %d trials.  Step: %d.  Permutations per window: %d.\n', ...
        PERS_WIN_SIZE, PERS_STEP, PERS_N_PERM_WIN);
    fprintf('  Significant: z > 1.96 (persistence) or z < -1.96 (switching).\n');
    fprintf('  Expected under independence: 2.5%% in each tail.\n\n');

    rng(123);  % reproducible

    fish_results = struct('fn', {}, 'n_info', {}, 'n_rep_sig', {}, 'n_switch_sig', {});

    for fi = 1:length(FISH_LIST)
        fn     = FISH_LIST(fi);
        folder = sprintf('Fish_%d', fn);
        mpath  = fullfile(FIGURE_FOLDER, folder, [folder '_analysis.mat']);
        if ~isfile(mpath)
            fprintf('  WARNING: %s not found, skipping Fish %d\n', mpath, fn);
            continue;
        end
        dd_  = load(mpath);
        outc = dd_.outcome(:); N = length(outc);
        n_w  = PERS_WIN_SIZE;

        % Sliding-window test, fresh shuffles at every position
        n_pos = floor((N - n_w) / PERS_STEP) + 1;
        z_t   = nan(n_pos, 1);
        sd_t  = nan(n_pos, 1);

        for tt_idx = 1:n_pos
            tt       = (tt_idx - 1) * PERS_STEP + 1;
            win_outc = outc(tt:tt + n_w - 1);
            R_obs    = sum(win_outc(2:end) == win_outc(1:end-1));
            R_null = zeros(PERS_N_PERM_WIN, 1);
            for s = 1:PERS_N_PERM_WIN
                pp = win_outc(randperm(n_w));
                R_null(s) = sum(pp(2:end) == pp(1:end-1));
            end
            sd_t(tt_idx) = std(R_null);
            if sd_t(tt_idx) > 0
                z_t(tt_idx) = (R_obs - mean(R_null)) / sd_t(tt_idx);
            end
        end

        informative = sd_t >= PERS_MIN_NULL_SD & ~isnan(z_t);
        n_info       = sum(informative);
        n_rep_sig    = sum(informative & z_t >  1.96);
        n_switch_sig = sum(informative & z_t < -1.96);

        fish_results(end+1).fn = fn; %#ok<SAGROW>
        fish_results(end).n_info        = n_info;
        fish_results(end).n_rep_sig     = n_rep_sig;
        fish_results(end).n_switch_sig  = n_switch_sig;

        fprintf('  Fish %2d:  %4d informative windows  |  persistence sig: %3d (%5.1f%%)  |  switching sig: %3d (%5.1f%%)\n', ...
            fn, n_info, n_rep_sig, 100*n_rep_sig/max(n_info,1), ...
            n_switch_sig, 100*n_switch_sig/max(n_info,1));
    end

    % ---- Pooled binomial test ----
    total_n      = sum([fish_results.n_info]);
    total_rep    = sum([fish_results.n_rep_sig]);
    total_switch = sum([fish_results.n_switch_sig]);
    p_chance     = 0.025;
    % One-sided: P(X >= observed) under Binomial(n, 0.025)
    p_rep_bino    = 1 - binocdf(total_rep    - 1, total_n, p_chance);
    p_switch_bino = 1 - binocdf(total_switch - 1, total_n, p_chance);

    fprintf('\n  POOLED across %d fish (%d total informative windows):\n', ...
        length(fish_results), total_n);
    fprintf('    Persistence: %3d/%4d windows (%5.2f%%)  vs 2.5%% expected  ->  p = %.3g  (binomial, one-sided)\n', ...
        total_rep, total_n, 100*total_rep/max(total_n,1), p_rep_bino);
    fprintf('    Switching:   %3d/%4d windows (%5.2f%%)  vs 2.5%% expected  ->  p = %.3g  (binomial, one-sided)\n', ...
        total_switch, total_n, 100*total_switch/max(total_n,1), p_switch_bino);

    % ---- Bar-chart summary figure ----
    if ~isempty(fish_results)
        figure('Position', [40 40 800 480], 'Visible', 'off', 'Color', 'w');
        n_f   = length(fish_results);
        x     = 1:n_f;
        rep_pct    = 100 * arrayfun(@(s) s.n_rep_sig    / max(s.n_info,1), fish_results);
        switch_pct = 100 * arrayfun(@(s) s.n_switch_sig / max(s.n_info,1), fish_results);
        bw = 0.38;
        bar(x - bw/2, rep_pct,    bw, 'FaceColor', [0.85 0.40 0.40], 'EdgeColor', 'none'); hold on;
        bar(x + bw/2, switch_pct, bw, 'FaceColor', [0.40 0.55 0.85], 'EdgeColor', 'none');
        yline(2.5, '--', 'Color', [0.3 0.3 0.3], 'LineWidth', 1.2, 'Label', '2.5% chance');
        xlim([0.4, n_f + 0.6]);
        xticks(x); xticklabels(arrayfun(@(s) sprintf('Fish %d', s.fn), fish_results, 'uni', false));
        ylabel('% of informative windows significant', 'FontWeight', 'bold', 'FontSize', 12);
        title(sprintf('Persistence test — pooled p = %.3g (persistence) vs %.3g (switching)', ...
            p_rep_bino, p_switch_bino), 'FontSize', 11, 'FontWeight', 'bold');
        legend({'Persistence (z > 1.96)', 'Switching (z < -1.96)'}, 'Location', 'best', 'Box', 'off');
        set(gca, 'FontSize', 11, 'FontWeight', 'bold', 'TickDir', 'out', 'LineWidth', 1.2);
        box off;
        set(gcf, 'Visible', 'on');
        tag = sprintf('AllFish_%s', regexprep(mat2str(FISH_LIST), '\W+', '_'));
        sP = fullfile(FIGURE_FOLDER, sprintf('Persistence_test_%s', tag));
        saveas(gcf, [sP '.fig']); saveas(gcf, [sP '.png']); close(gcf);
        fprintf('\n  Saved: %s\n', sP);
    end
end

%% ========================================================================
% HELPER: style axes (matches ACCURACY_analysis_single_excelV4)
% =========================================================================
function style_axes(ax)
    box(ax, 'off');
    set(ax, ...
        'TickDir',    'out', ...
        'LineWidth',  1.6, ...
        'FontSize',   14, ...
        'FontWeight', 'bold');
end

%% ========================================================================
% =========================================================================
function acc = normalize_acc(acc, fp)
    if ~isnan(fp)
        acc = 1 ./ (2*(1-fp)) .* acc + (1 - 1 ./ (2*(1-fp)));
    end
end

%% ========================================================================
% HELPER: find contiguous runs of true values in a logical vector
% Returns N-by-3 matrix [start, end, length] for each contiguous true run.
% =========================================================================
function runs = find_runs(logical_vec)
    logical_vec = logical(logical_vec(:));
    d      = diff([false; logical_vec; false]);
    starts = find(d ==  1);
    ends   = find(d == -1) - 1;
    if isempty(starts)
        runs = zeros(0, 3);
    else
        runs = [starts, ends, ends - starts + 1];
    end
end
