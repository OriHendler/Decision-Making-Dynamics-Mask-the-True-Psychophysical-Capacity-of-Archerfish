%% Dynamic GLM Hendler - 2 Positions, 7 Models (Empirical Bayes)
% =========================================================================
% For a two-alternative choice task with only 2 possible positions.
%
% Models:
%   M1: Spatial             - 2 position indicator weights
%   M2: Spatial + Persist   - M1 + persistence (prev outcome +-1)
%   M3: Spatial Bias        - 2 weights: +1 chose q, -1 rejected q
%   M4: Spatial Bias + Spatial (4 weights)
%   M5: Spatial Bias + Spatial + Persist (5 weights)
%   M6: M4 + WinStay + LoseStay (6 weights)
%   M7: M5 + WinStay + LoseStay (7 weights)
%
% Win-stay regressor (active only when prev trial results==1, animal went to target):
%   +1 if animal stayed at same position, -1 if switched, 0 if prev results==0
% Lose-stay regressor (active only when prev trial results==0, animal went to non-target):
%   +1 if animal stayed at same position, -1 if switched, 0 if prev results==1
%
% MAP uses JOINT Newton via block-tridiagonal solver.
% Sigma optimized via decoupled Laplace (Ashwood et al., Algorithm 1).
% =========================================================================

clear; clc; close all;

%% USER CONFIGURATION
FISH_NAMES = {'1','2','3','4','5'};

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
% Per-fish model outputs go to output/FIGURE 2. Each fish is a sheet named by
% its number; trial outcome is the 'results' column; target and non_target are
% read from the columns of those names.
BASE_PATH = fullfile(OUTPUT_ROOT, 'FIGURE 2');
if ~isfolder(BASE_PATH); mkdir(BASE_PATH); end

OPT = struct('sigInit',16, 'sigma0',1.0, 'max_outer',20, 'max_inner',10, ...
    'sigma_tol',1e-4, 'map_tol',1e-6, 'map_max_iter',50, 'sigma_min',1e-4, 'sigma_max',100);

N_MODELS = 7;
MODEL_NAMES = {'M1: Spatial', 'M2: Spatial+Persist', 'M3: SpatBias', ...
    'M4: SpatBias+Spatial', 'M5: SpatBias+Spatial+Persist', ...
    'M6: M4+WinStay+LoseStay', 'M7: M5+WinStay+LoseStay'};
MODEL_SHORT = {'M1','M2','M3','M4','M5','M6','M7'};

%% MAIN LOOP
fprintf('%s\nDYNAMIC GLM HENDLER - 2 POSITIONS, 7 MODELS\n%s\n', repmat('=',1,70), repmat('=',1,70));
for m = 1:N_MODELS; fprintf('  %s\n', MODEL_NAMES{m}); end; fprintf('\n');

all_results = struct([]);
for fish_num = 1:length(FISH_NAMES)
    result = analyze_fish(fish_num, FISH_NAMES, BASE_PATH, DATA_FILE, OPT, MODEL_NAMES, MODEL_SHORT, N_MODELS);
    if isempty(all_results); all_results = result; else; all_results(end+1) = result; end %#ok<SAGROW>
end

%% CROSS-FISH SUMMARY
fprintf('\n%s\nCROSS-FISH SUMMARY\n%s\n', repmat('=',1,70), repmat('=',1,70));
fprintf('\n%-10s %6s %6s', 'Fish', 'N', 'Acc');
for m = 1:N_MODELS; fprintf(' %7s', MODEL_SHORT{m}); end; fprintf('\n%s\n', repmat('-',1,75));
for i = 1:length(all_results)
    r = all_results(i);
    fprintf('%-10s %6d %5.1f%%', r.fish_id, r.n_trials, r.accuracy*100);
    for m = 1:N_MODELS; fprintf(' %7.3f', r.AUC(m)); end; fprintf('\n');
end
fprintf('\nBIC table:\n%-10s', 'Fish');
for m = 1:N_MODELS; fprintf(' %10s', MODEL_SHORT{m}); end; fprintf(' %6s\n', 'Best');
fprintf('%s\n', repmat('-',1,90));
for i = 1:length(all_results)
    r = all_results(i); fprintf('%-10s', r.fish_id);
    for m = 1:N_MODELS; fprintf(' %10.1f', r.BIC(m)); end
    fprintf(' %6s\n', MODEL_SHORT{r.best_model});
end
for m = 1:N_MODELS
    nb = sum([all_results.best_model]==m);
    if nb > 0; fprintf('  %s preferred in %d/%d fish\n', MODEL_SHORT{m}, nb, length(all_results)); end
end

save(fullfile(BASE_PATH, 'All_Fish_Summary_7Models.mat'), 'all_results', 'MODEL_NAMES', 'MODEL_SHORT');
auc_mat = vertcat(all_results.AUC); bic_mat = vertcat(all_results.BIC); evd_mat = vertcat(all_results.Evidence);
vn = [{'Fish','N_trials','Accuracy'}, ...
    arrayfun(@(m) [MODEL_SHORT{m} '_AUC'], 1:N_MODELS, 'UniformOutput', false), ...
    arrayfun(@(m) [MODEL_SHORT{m} '_BIC'], 1:N_MODELS, 'UniformOutput', false), ...
    arrayfun(@(m) [MODEL_SHORT{m} '_Evd'], 1:N_MODELS, 'UniformOutput', false), {'Best_Model'}];
T = table({all_results.fish_id}', [all_results.n_trials]', [all_results.accuracy]', ...
    auc_mat(:,1),auc_mat(:,2),auc_mat(:,3),auc_mat(:,4),auc_mat(:,5),auc_mat(:,6),auc_mat(:,7), ...
    bic_mat(:,1),bic_mat(:,2),bic_mat(:,3),bic_mat(:,4),bic_mat(:,5),bic_mat(:,6),bic_mat(:,7), ...
    evd_mat(:,1),evd_mat(:,2),evd_mat(:,3),evd_mat(:,4),evd_mat(:,5),evd_mat(:,6),evd_mat(:,7), ...
    [all_results.best_model]', 'VariableNames', vn);
writetable(T, fullfile(BASE_PATH, 'All_Fish_Summary_7Models.xlsx'));
writetable(T, fullfile(BASE_PATH, 'All_Fish_Summary_7Models.csv'));

model_colors = [0.2 0.7 0.2; 0.8 0.2 0.2; 0.2 0.4 0.8; 0.9 0.6 0.1; 0.5 0.2 0.7; 0.1 0.7 0.7; 0.8 0.4 0.6];
nFish = length(all_results);
fish_labels = arrayfun(@(x) sprintf('F%d',x), 1:nFish, 'UniformOutput', false);

figure('Position', [50 50 1600 1000]);
subplot(2,2,1); bw=0.12; x=1:nFish;
for m=1:N_MODELS; bar(x+(m-4)*bw,auc_mat(:,m),bw,'FaceColor',model_colors(m,:),'FaceAlpha',0.8); hold on; end
set(gca,'XTick',x,'XTickLabel',fish_labels); ylabel('AUC'); ylim([0.45 1]); title('AUC');
legend(MODEL_SHORT,'Location','best','FontSize',7); grid on; set(gca,'GridAlpha',0.3);
subplot(2,2,2); dbic=bic_mat-min(bic_mat,[],2);
for m=1:N_MODELS; bar(x+(m-4)*bw,dbic(:,m),bw,'FaceColor',model_colors(m,:),'FaceAlpha',0.8); hold on; end
set(gca,'XTick',x,'XTickLabel',fish_labels); ylabel('\DeltaBIC'); title('BIC (lower=better)');
legend(MODEL_SHORT,'Location','best','FontSize',7); grid on; set(gca,'GridAlpha',0.3);
subplot(2,2,3); bc=histcounts([all_results.best_model],0.5:N_MODELS+0.5);
b=bar(bc,'FaceColor','flat'); b.CData=model_colors; set(gca,'XTickLabel',MODEL_SHORT);
ylabel('# Fish'); title('Best Model'); grid on; set(gca,'GridAlpha',0.3);
subplot(2,2,4); bar([all_results.accuracy],'FaceColor',[.5 .5 .5]); yline(0.5,'r--');
set(gca,'XTick',1:nFish,'XTickLabel',fish_labels); ylabel('Accuracy'); ylim([0.4 1]); title('Accuracy');
grid on; set(gca,'GridAlpha',0.3);
sgtitle('2-Position: 7 Models Summary','FontSize',14,'FontWeight','bold');
saveas(gcf, fullfile(BASE_PATH,'All_Fish_Summary_7Models.png')); close(gcf);
fprintf('\n%s\nANALYSIS COMPLETE\n%s\nFiles: %s\n', repmat('=',1,70), repmat('=',1,70), BASE_PATH);


%% ========================================================================
% ANALYZE ONE FISH
% =========================================================================
function result = analyze_fish(fish_number, FISH_NAMES, BASE_PATH, DATA_FILE, OPT, MODEL_NAMES, MODEL_SHORT, N_MODELS)
    fish_name = FISH_NAMES{fish_number};
    fish_id = sprintf('Fish_%d', fish_number);
    output_dir = fullfile(BASE_PATH, fish_id);
    if ~isfolder(output_dir); mkdir(output_dir); end
    fprintf('\n%s\nANALYZING %s (%s)\n%s\n', repmat('=',1,70), fish_id, fish_name, repmat('=',1,70));

    % --- Read this fish from the combined workbook (sheet named by number) ---
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
    valid = ismember(res_raw, [0 1]) & ~isnan(tgt_raw) & ~isnan(nt_raw);
    y01 = res_raw(valid);                 % 1=went to target, 0=went to non_target
    target = tgt_raw(valid); non_target = nt_raw(valid);
    N = numel(y01);
    y = y01 + 1;          % 1/2 for the model
    trials = (0:N-1)';
    sessions = ones(N,1); % session column not used by the fit
    fprintf('Trials: %d, Accuracy: %.1f%%\n', N, mean(y01)*100);

    positions = unique([target; non_target]); n_pos = length(positions);
    pos_counts = zeros(n_pos,1); pos_accuracy = nan(n_pos,1);
    for p = 1:n_pos
        mask = target==positions(p); pos_counts(p)=sum(mask);
        if sum(mask)>0; pos_accuracy(p)=mean(y01(mask)); end
    end
    for p=1:n_pos; fprintf('  Pos %d: n=%d, acc=%.1f%%\n', positions(p), pos_counts(p), pos_accuracy(p)*100); end

    % --- Regressors ---
    q1 = double(target==positions(1)); q2 = double(target==positions(2));

    % Persistence: +1 if animal made the same choice type as previous trial
    %   (target->target or non-target->non-target = persisted = +1)
    %   (target->non-target or non-target->target = switched  = -1)
    prev_outcome = zeros(N,1);
    for i=2:N
        if y01(i) == y01(i-1)
            prev_outcome(i) = 1;   % persisted
        else
            prev_outcome(i) = -1;  % switched
        end
    end

    % Spatial bias: encoding what the animal chose
    %   results=1 means animal went to target, results=0 means went to non-target
    %   +1 if animal went to position q (target==q & results==1, OR non_target==q & results==0)
    %   -1 if q was an option but animal went to the other (target==q & results==0, OR non_target==q & results==1)
    %    0 if q was not an option on this trial
    sb1 = zeros(N,1); sb2 = zeros(N,1);
    for i=1:N
        for p=1:n_pos
            qq=positions(p); is_t=(target(i)==qq); is_nt=(non_target(i)==qq); val=0;
            if is_t && y01(i)==1; val=1; elseif is_nt && y01(i)==0; val=1;       % animal went to q
            elseif is_t && y01(i)==0; val=-1; elseif is_nt && y01(i)==1; val=-1; end  % animal did not go to q
            if p==1; sb1(i)=val; else; sb2(i)=val; end
        end
    end

    % Win-stay regressor (active only when prev trial results==1, i.e. animal went to target):
    %   Previous position = target(t-1) [results(t-1)==1 means animal was at target]
    %   Current position  = target(t) if results(t)==1, non_target(t) if results(t)==0
    %   +1 if animal stayed at same position as previous trial
    %   -1 if animal switched to the other position
    %    0 if prev trial results==0 (animal went to non-target)
    %
    % Lose-stay regressor (active only when prev trial results==0, i.e. animal went to non-target):
    %   Previous position = non_target(t-1) [results(t-1)==0 means animal was at non-target]
    %   Current position  = target(t) if results(t)==1, non_target(t) if results(t)==0
    %   +1 if animal stayed at same position as previous trial
    %   -1 if animal switched to the other position
    %    0 if prev trial results==1 (animal went to target)
    win_stay = zeros(N,1); lose_stay = zeros(N,1);
    for i=2:N
        % Determine animal's current position
        if y01(i) == 1
            current_choice = target(i);       % results==1: animal went to target
        else
            current_choice = non_target(i);   % results==0: animal went to non-target
        end

        if y01(i-1) == 1  % prev trial: animal went to target
            prev_pos = target(i-1);
            if current_choice == prev_pos
                win_stay(i) = 1;     % stayed
            else
                win_stay(i) = -1;    % switched
            end
        else               % prev trial: animal went to non-target
            prev_pos = non_target(i-1);
            if current_choice == prev_pos
                lose_stay(i) = 1;    % stayed
            else
                lose_stay(i) = -1;   % switched
            end
        end
    end

    [pos_running, overall_running] = compute_running_accuracy(y01, target, positions, 15);

    % --- Fit all 7 models ---
    fprintf('\n  Fitting M1: Spatial...\n');
    X_m1=[q1,q2]; [wMAP_m1,Ws_m1,e1,s1,i1]=fit_dynamic_glm_eb(y,X_m1,OPT);
    p1=sigmoid_fn(sum(X_m1'.*wMAP_m1,1))'; mt1=compute_metrics(y01,p1,2,N);
    fprintf('    AUC=%.3f, BIC=%.1f\n', mt1.auc, mt1.bic);

    fprintf('  Fitting M2: Spatial+Persist...\n');
    X_m2=[prev_outcome,q1,q2]; [wMAP_m2,Ws_m2,e2,s2,i2]=fit_dynamic_glm_eb(y,X_m2,OPT);
    p2=sigmoid_fn(sum(X_m2'.*wMAP_m2,1))'; mt2=compute_metrics(y01,p2,3,N);
    fprintf('    AUC=%.3f, BIC=%.1f\n', mt2.auc, mt2.bic);

    fprintf('  Fitting M3: SpatBias...\n');
    X_m3=[sb1,sb2]; [wMAP_m3,Ws_m3,e3,s3,i3]=fit_dynamic_glm_eb(y,X_m3,OPT);
    p3=sigmoid_fn(sum(X_m3'.*wMAP_m3,1))'; mt3=compute_metrics(y01,p3,2,N);
    fprintf('    AUC=%.3f, BIC=%.1f\n', mt3.auc, mt3.bic);

    fprintf('  Fitting M4: SpatBias+Spatial...\n');
    X_m4=[sb1,sb2,q1,q2]; [wMAP_m4,Ws_m4,e4,s4,i4]=fit_dynamic_glm_eb(y,X_m4,OPT);
    p4=sigmoid_fn(sum(X_m4'.*wMAP_m4,1))'; mt4=compute_metrics(y01,p4,4,N);
    fprintf('    AUC=%.3f, BIC=%.1f\n', mt4.auc, mt4.bic);

    fprintf('  Fitting M5: SpatBias+Spatial+Persist...\n');
    X_m5=[prev_outcome,sb1,sb2,q1,q2]; [wMAP_m5,Ws_m5,e5,s5,i5]=fit_dynamic_glm_eb(y,X_m5,OPT);
    p5=sigmoid_fn(sum(X_m5'.*wMAP_m5,1))'; mt5=compute_metrics(y01,p5,5,N);
    fprintf('    AUC=%.3f, BIC=%.1f\n', mt5.auc, mt5.bic);

    fprintf('  Fitting M6: M4+WinStay+LoseStay...\n');
    X_m6=[sb1,sb2,q1,q2,win_stay,lose_stay]; [wMAP_m6,Ws_m6,e6,s6,i6]=fit_dynamic_glm_eb(y,X_m6,OPT);
    p6=sigmoid_fn(sum(X_m6'.*wMAP_m6,1))'; mt6=compute_metrics(y01,p6,6,N);
    fprintf('    AUC=%.3f, BIC=%.1f\n', mt6.auc, mt6.bic);

    fprintf('  Fitting M7: M5+WinStay+LoseStay...\n');
    X_m7=[prev_outcome,sb1,sb2,q1,q2,win_stay,lose_stay]; [wMAP_m7,Ws_m7,e7,s7,i7]=fit_dynamic_glm_eb(y,X_m7,OPT);
    p7=sigmoid_fn(sum(X_m7'.*wMAP_m7,1))'; mt7=compute_metrics(y01,p7,7,N);
    fprintf('    AUC=%.3f, BIC=%.1f\n', mt7.auc, mt7.bic);

    all_met={mt1,mt2,mt3,mt4,mt5,mt6,mt7};
    all_auc=cellfun(@(m) m.auc, all_met); all_bic=cellfun(@(m) m.bic, all_met);
    all_evd=[e1,e2,e3,e4,e5,e6,e7];
    all_pred={p1,p2,p3,p4,p5,p6,p7};
    all_wMAP={wMAP_m1,wMAP_m2,wMAP_m3,wMAP_m4,wMAP_m5,wMAP_m6,wMAP_m7};
    all_Wstd={Ws_m1,Ws_m2,Ws_m3,Ws_m4,Ws_m5,Ws_m6,Ws_m7};
    all_sigs={s1,s2,s3,s4,s5,s6,s7};
    all_infos={i1,i2,i3,i4,i5,i6,i7};
    [~,best_model]=min(all_bic);

    fprintf('\n  MODEL COMPARISON (BIC):\n');
    for m=1:N_MODELS
        mk=''; if m==best_model; mk=' ***BEST***'; end
        fprintf('    %s: BIC=%.1f, AUC=%.3f%s\n', MODEL_NAMES{m}, all_bic(m), all_auc(m), mk);
    end

    % --- Plots ---
    colors_pos = [0.122 0.467 0.706; 0.839 0.153 0.157];
    model_colors = [0.2 0.7 0.2; 0.8 0.2 0.2; 0.2 0.4 0.8; 0.9 0.6 0.1; 0.5 0.2 0.7; 0.1 0.7 0.7; 0.8 0.4 0.6];

    % M1 weights
    figure('Position',[50 50 1400 500],'Visible','off');
    for p=1:n_pos; subplot(1,2,p);
        w=wMAP_m1(p,:); ws=Ws_m1(p,:);
        fill([trials;flipud(trials)],[w'-ws';flipud(w'+ws')],colors_pos(p,:),'FaceAlpha',0.3,'EdgeColor','none'); hold on;
        plot(trials,w,'Color',colors_pos(p,:),'LineWidth',2); yline(0,'--','Color',[.5 .5 .5]);
        xlabel('Trial'); ylabel('Weight');
        title(sprintf('Pos %d (n=%d, acc=%.1f%%, \\sigma=%.4f)', positions(p), pos_counts(p), pos_accuracy(p)*100, s1(p)), 'FontWeight','bold');
        grid on; set(gca,'GridAlpha',0.3);
    end
    sgtitle(sprintf('%s - M1 Spatial Weights',fish_id),'FontSize',16,'FontWeight','bold');
    saveas(gcf,fullfile(output_dir,[fish_id '_M1_weights.png'])); close(gcf);

    % M3 spatial bias weights
    figure('Position',[50 50 1400 500],'Visible','off');
    for p=1:n_pos; subplot(1,2,p);
        w=wMAP_m3(p,:); ws=Ws_m3(p,:);
        fill([trials;flipud(trials)],[w'-1.96*ws';flipud(w'+1.96*ws')],colors_pos(p,:),'FaceAlpha',0.3,'EdgeColor','none'); hold on;
        plot(trials,w,'Color',colors_pos(p,:),'LineWidth',2); yline(0,'--','Color',[.5 .5 .5]);
        xlabel('Trial'); ylabel('Weight');
        title(sprintf('Pos %d Bias (\\sigma=%.4f)',positions(p),s3(p)),'FontWeight','bold');
        grid on; set(gca,'GridAlpha',0.3);
    end
    sgtitle(sprintf('%s - M3 Spatial Bias Weights',fish_id),'FontSize',16,'FontWeight','bold');
    saveas(gcf,fullfile(output_dir,[fish_id '_M3_spatbias_weights.png'])); close(gcf);

    % Win-Stay / Lose-Stay (M6 and M7)
    figure('Position',[50 50 1600 900],'Visible','off');
    ws6=5; ls6=6; ws7=6; ls7=7;
    titles_ws = {sprintf('M6 Win-Stay (\\sigma=%.4f)',s6(ws6)), sprintf('M6 Lose-Stay (\\sigma=%.4f)',s6(ls6)), ...
                 sprintf('M7 Win-Stay (\\sigma=%.4f)',s7(ws7)), sprintf('M7 Lose-Stay (\\sigma=%.4f)',s7(ls7))};
    wts = {wMAP_m6(ws6,:), wMAP_m6(ls6,:), wMAP_m7(ws7,:), wMAP_m7(ls7,:)};
    stds = {Ws_m6(ws6,:), Ws_m6(ls6,:), Ws_m7(ws7,:), Ws_m7(ls7,:)};
    cols = {[0.1 0.7 0.7],[0.8 0.4 0.6],[0.1 0.7 0.7],[0.8 0.4 0.6]};
    for sp=1:4; subplot(2,2,sp);
        w=wts{sp}; ws=stds{sp};
        fill([trials;flipud(trials)],[w'-1.96*ws';flipud(w'+1.96*ws')],cols{sp},'FaceAlpha',0.3,'EdgeColor','none'); hold on;
        plot(trials,w,'Color',cols{sp},'LineWidth',2); yline(0,'--','Color',[.5 .5 .5]);
        xlabel('Trial'); ylabel('Weight');
        title(sprintf('%s (mean=%.3f)',titles_ws{sp},mean(w)),'FontWeight','bold');
        grid on; set(gca,'GridAlpha',0.3);
    end
    sgtitle(sprintf('%s - Win-Stay / Lose-Stay',fish_id),'FontSize',16,'FontWeight','bold');
    saveas(gcf,fullfile(output_dir,[fish_id '_winstay_losestay.png'])); close(gcf);

    % Summary
    figure('Position',[50 50 1600 800],'Visible','off');
    subplot(2,3,1); b=bar(pos_accuracy,'FaceColor','flat'); b.CData=colors_pos;
    yline(0.5,'--','Color',[.5 .5 .5]);
    set(gca,'XTickLabel',arrayfun(@(x) sprintf('Pos %d',x), positions,'UniformOutput',false));
    ylabel('Accuracy'); ylim([0 1]); title('Position Accuracy','FontWeight','bold'); grid on; set(gca,'GridAlpha',0.3);
    subplot(2,3,2); b=bar(all_bic,'FaceColor','flat','EdgeColor','k','LineWidth',1.5); b.CData=model_colors;
    set(gca,'XTickLabel',MODEL_SHORT,'FontSize',7); ylabel('BIC');
    title(sprintf('BIC (best: %s)',MODEL_SHORT{best_model}),'FontWeight','bold'); grid on; set(gca,'GridAlpha',0.3);
    subplot(2,3,3);
    for m=1:N_MODELS; [f,t]=compute_roc(y01,all_pred{m}); plot(f,t,'-','Color',model_colors(m,:),'LineWidth',1.5); hold on; end
    plot([0 1],[0 1],'k--'); xlabel('FPR'); ylabel('TPR'); title('ROC','FontWeight','bold');
    legend(arrayfun(@(m) sprintf('%s (%.3f)',MODEL_SHORT{m},all_auc(m)),1:N_MODELS,'UniformOutput',false),'Location','southeast','FontSize',6);
    grid on; set(gca,'GridAlpha',0.3);
    subplot(2,3,4); win=20;
    plot(trials,movmean(y01,win,'omitnan'),'k-','LineWidth',2); hold on;
    plot(trials,movmean(all_pred{best_model},win,'omitnan'),'--','Color',model_colors(best_model,:),'LineWidth',2);
    yline(0.5,'--','Color',[.5 .5 .5]); xlabel('Trial'); ylabel('P(Correct)'); ylim([0 1]);
    title(sprintf('Best Fit (%s)',MODEL_SHORT{best_model}),'FontWeight','bold');
    legend({'Actual','Predicted'},'Location','best'); grid on; set(gca,'GridAlpha',0.3);
    subplot(2,3,5); for p=1:n_pos; plot(trials,pos_running{p},'Color',colors_pos(p,:),'LineWidth',2); hold on; end
    yline(0.5,'--','Color',[.5 .5 .5]); xlabel('Trial'); ylabel('Running Acc');
    title('Per-Position Accuracy','FontWeight','bold');
    legend(arrayfun(@(x) sprintf('Pos %d',x),positions,'UniformOutput',false),'Location','best'); grid on; set(gca,'GridAlpha',0.3);
    subplot(2,3,6); for m=1:N_MODELS; sh=all_infos{m}.sigma_history;
        plot(1:size(sh,1),mean(sh,2),'-o','Color',model_colors(m,:),'LineWidth',1.5,'MarkerSize',4); hold on; end
    xlabel('Iteration'); ylabel('Mean \\sigma'); title('\\sigma Convergence','FontWeight','bold');
    legend(MODEL_SHORT,'Location','best','FontSize',6); grid on; set(gca,'GridAlpha',0.3);
    sgtitle(sprintf('%s - Summary',fish_id),'FontSize',16,'FontWeight','bold');
    saveas(gcf,fullfile(output_dir,[fish_id '_summary.png'])); close(gcf);

    % --- Save Excel ---
    trial_table = table(trials,sessions,target,non_target,y01,prev_outcome,win_stay,lose_stay,overall_running, ...
        p1,p2,p3,p4,p5,p6,p7, 'VariableNames', {'trial','session','target','non_target','outcome', ...
        'prev_outcome','win_stay','lose_stay','overall_running_acc', ...
        'M1_pred','M2_pred','M3_pred','M4_pred','M5_pred','M6_pred','M7_pred'});
    for p=1:n_pos; trial_table.(sprintf('Pos%d_running_acc',positions(p)))=pos_running{p}; end
    wt_names = {{'P1','P2'},{'Persist','P1','P2'},{'SB1','SB2'},{'SB1','SB2','P1','P2'}, ...
        {'Persist','SB1','SB2','P1','P2'},{'SB1','SB2','P1','P2','WinStay','LoseStay'}, ...
        {'Persist','SB1','SB2','P1','P2','WinStay','LoseStay'}};
    for m=1:N_MODELS; wM=all_wMAP{m};
        for k=1:size(wM,1); trial_table.(sprintf('%s_%s_wt',MODEL_SHORT{m},wt_names{m}{k}))=wM(k,:)'; end
    end
    mn={'N_trials';'Overall_accuracy'}; mv={N;mean(y01)};
    for m=1:N_MODELS
        mn=[mn;{sprintf('%s_AUC',MODEL_SHORT{m});sprintf('%s_BIC',MODEL_SHORT{m});sprintf('%s_Evd',MODEL_SHORT{m})}]; %#ok<AGROW>
        mv=[mv;{all_met{m}.auc;all_met{m}.bic;all_evd(m)}]; %#ok<AGROW>
    end
    mn{end+1}='Best_Model'; mv{end+1}=MODEL_SHORT{best_model};
    stbl=table(mn,mv,'VariableNames',{'Metric','Value'});
    sn={}; sv=[];
    for m=1:N_MODELS; sg=all_sigs{m};
        for k=1:length(sg); sn{end+1}=sprintf('%s_sig_%s',MODEL_SHORT{m},wt_names{m}{k}); sv(end+1)=sg(k); end %#ok<AGROW>
    end
    sigtbl=table(sn(:),sv(:),'VariableNames',{'Parameter','Sigma'});
    ep=fullfile(output_dir,[fish_id '_analysis.xlsx']);
    writetable(trial_table,ep,'Sheet','Trial_Data');
    writetable(stbl,ep,'Sheet','Summary');
    writetable(sigtbl,ep,'Sheet','Optimized_Sigmas');
    fprintf('\n  Saved Excel: %s\n', ep);

    % --- Save .mat ---
    md=struct(); md.fish_number=fish_number; md.fish_id=fish_id; md.fish_name=fish_name;
    md.n_trials=N; md.trials=trials; md.sessions=sessions;
    md.target=target; md.non_target=non_target; md.outcome=y01; md.positions=positions;
    md.prev_outcome=prev_outcome; md.win_stay_regressor=win_stay; md.lose_stay_regressor=lose_stay;
    md.pos_counts=pos_counts; md.pos_accuracy=pos_accuracy; md.overall_running_acc=overall_running;
    md.sb_regressors=[sb1,sb2];
    for m=1:N_MODELS; ml=MODEL_SHORT{m};
        md.([ml '_weights'])=all_wMAP{m}; md.([ml '_weights_std'])=all_Wstd{m};
        md.([ml '_predictions'])=all_pred{m}; md.([ml '_sigmas'])=all_sigs{m};
        md.([ml '_sigma_history'])=all_infos{m}.sigma_history;
        md.([ml '_evidence'])=all_evd(m); md.([ml '_auc'])=all_auc(m);
        md.([ml '_bic'])=all_bic(m); md.([ml '_log_likelihood'])=all_met{m}.log_likelihood;
    end
    md.best_model=best_model; md.all_auc=all_auc; md.all_bic=all_bic; md.all_evidence=all_evd;
    for p=1:n_pos; md.(sprintf('Pos%d_running_acc',positions(p)))=pos_running{p}; end
    mp=fullfile(output_dir,[fish_id '_analysis.mat']); save(mp,'-struct','md');
    fprintf('  Saved MATLAB: %s\n', mp);

    result.fish_number=fish_number; result.fish_id=fish_id; result.n_trials=N;
    result.accuracy=mean(y01); result.AUC=all_auc; result.BIC=all_bic;
    result.Evidence=all_evd; result.best_model=best_model;
end


%% ========================================================================
% EB ENGINE (Algorithm 1: decoupled Laplace)
% =========================================================================
function [wMAP, W_std, logEvidence, sigmas, optim_info] = fit_dynamic_glm_eb(y, X, OPT)
    [N,K]=size(X); y01=(y(:)==2);
    sigInit=OPT.sigInit; inv_sigInit2=1/sigInit^2;
    sigmas=OPT.sigma0*ones(K,1);
    sigma_history=zeros(OPT.max_outer,K); evidence_history=zeros(OPT.max_outer,1);
    W=zeros(K,N); best_evidence=-Inf; best_sigmas=sigmas; best_W=W;

    for outer=1:OPT.max_outer
        inv_sig2=1./(sigmas.^2);
        % STEP 2: Joint Newton MAP
        for map_iter=1:OPT.map_max_iter
            g=sum(X'.*W,1)'; p=sigmoid_fn(g); res=y01-p; lam=p.*(1-p);
            A=zeros(K,K,N); rhs=zeros(K,N);
            for t=1:N
                if t==1; pd=inv_sigInit2+inv_sig2; elseif t==N; pd=inv_sig2; else; pd=2*inv_sig2; end
                xt=X(t,:)'; A(:,:,t)=diag(pd)+(xt*xt')*lam(t);
                gl=xt*res(t); gp=zeros(K,1);
                for k=1:K
                    if t==1; gp(k)=-(inv_sigInit2+inv_sig2(k))*W(k,1);
                        if N>1; gp(k)=gp(k)+inv_sig2(k)*W(k,2); end
                    elseif t==N; gp(k)=inv_sig2(k)*W(k,t-1)-inv_sig2(k)*W(k,t);
                    else; gp(k)=inv_sig2(k)*W(k,t-1)-2*inv_sig2(k)*W(k,t)+inv_sig2(k)*W(k,t+1); end
                end
                Hw=A(:,:,t)*W(:,t);
                if t>1; Hw=Hw-diag(inv_sig2)*W(:,t-1); end
                if t<N; Hw=Hw-diag(inv_sig2)*W(:,t+1); end
                rhs(:,t)=Hw+gl+gp;
            end
            Wn=block_tridiag_solve(A,inv_sig2,rhs);
            if max(abs(Wn(:)-W(:)))<OPT.map_tol; W=Wn; break; end; W=Wn;
        end
        g=sum(X'.*W,1)'; p=sigmoid_fn(g); lam=p.*(1-p);

        % STEPS 3-4: Fixed Gaussian likelihood
        lhd=zeros(N,K); frhs=zeros(K,N);
        for k=1:K
            xk=X(:,k); hld=xk.^2.*lam; lhd(:,k)=hld;
            [pd,pe]=build_rw_prior_hess(N,inv_sig2(k),inv_sigInit2);
            frhs(k,:)=tridiag_multiply(pd+hld,pe,W(k,:)')';
        end

        % STEP 5: Inner loop
        for inner=1:OPT.max_inner
            sp=sigmas; inv_sig2=1./(sigmas.^2);
            for k=1:K
                [pd,pe]=build_rw_prior_hess(N,inv_sig2(k),inv_sigInit2); md=pd+lhd(:,k);
                W(k,:)=tridiag_solve_vec(md,pe,frhs(k,:)')';
                [cd,co,~]=tridiag_inv_diag_offdiag(md,pe);
                dw=diff(W(k,:)'); dt=sum(dw.^2);
                tt=cd(1)+cd(N); if N>2; tt=tt+2*sum(cd(2:N-1)); end; tt=tt-2*sum(co);
                sigmas(k)=min(max(sqrt(max((dt+tt)/(N-1),OPT.sigma_min^2)),OPT.sigma_min),OPT.sigma_max);
            end
            if max(abs(sigmas-sp)./max(sp,1e-10))<OPT.sigma_tol; break; end
        end

        % STEP 6: Evidence
        inv_sig2=1./(sigmas.^2); g=sum(X'.*W,1)'; p=sigmoid_fn(g);
        pc=max(min(p,1-1e-10),1e-10);
        ll=sum(y01.*log(pc)+(1-y01).*log(1-pc));
        lp=0; ldp=0; lf=p.*(1-p);
        for k=1:K
            wk=W(k,:)'; dw=diff(wk);
            lp=lp-0.5*inv_sig2(k)*sum(dw.^2)-0.5*inv_sigInit2*wk(1)^2;
            lp=lp-0.5*(N-1)*log(2*pi*sigmas(k)^2)-0.5*log(2*pi*sigInit^2);
            [pd,pe]=build_rw_prior_hess(N,inv_sig2(k),inv_sigInit2);
            [~,~,ld]=tridiag_inv_diag_offdiag(pd+X(:,k).^2.*lf,pe); ldp=ldp+ld;
        end
        logEvd=ll+lp+0.5*K*N*log(2*pi)-0.5*ldp;
        sigma_history(outer,:)=sigmas'; evidence_history(outer)=logEvd;
        if logEvd>best_evidence; best_evidence=logEvd; best_sigmas=sigmas; best_W=W; end
        if outer>1 && max(abs(sigma_history(outer,:)-sigma_history(outer-1,:))./max(sigma_history(outer-1,:),1e-10))<OPT.sigma_tol; break; end
    end
    n_outer=outer; sigmas=best_sigmas; wMAP=best_W;
    inv_sig2=1./(sigmas.^2); g=sum(X'.*wMAP,1)'; p=sigmoid_fn(g); lam=p.*(1-p);
    W_std=zeros(K,N); ldt=0;
    for k=1:K
        [pd,pe]=build_rw_prior_hess(N,inv_sig2(k),inv_sigInit2); md=pd+X(:,k).^2.*lam;
        [iv,~,ld]=tridiag_inv_diag_offdiag(md,pe); W_std(k,:)=sqrt(max(iv,1e-10))'; ldt=ldt+ld;
    end
    pc=max(min(p,1-1e-10),1e-10); ll=sum(y01.*log(pc)+(1-y01).*log(1-pc)); lp=0;
    for k=1:K; wk=wMAP(k,:)'; dw=diff(wk);
        lp=lp-0.5*inv_sig2(k)*sum(dw.^2)-0.5*inv_sigInit2*wk(1)^2;
        lp=lp-0.5*(N-1)*log(2*pi*sigmas(k)^2)-0.5*log(2*pi*sigInit^2);
    end
    logEvidence=ll+lp+0.5*K*N*log(2*pi)-0.5*ldt;
    optim_info.n_outer=n_outer; optim_info.sigma_history=sigma_history(1:n_outer,:);
    optim_info.evidence_history=evidence_history(1:n_outer); optim_info.final_evidence=logEvidence;
end

%% BLOCK-TRIDIAGONAL SOLVER
function W_out = block_tridiag_solve(A, inv_sig2, rhs)
    K=size(A,1); N=size(A,3); B=-diag(inv_sig2);
    Di=zeros(K,K,N); rm=zeros(K,N);
    Di(:,:,1)=inv(A(:,:,1)); rm(:,1)=rhs(:,1);
    for t=2:N; M=B*(Di(:,:,t-1)*B); Di(:,:,t)=inv(A(:,:,t)-M);
        rm(:,t)=rhs(:,t)-B*(Di(:,:,t-1)*rm(:,t-1)); end
    W_out=zeros(K,N); W_out(:,N)=Di(:,:,N)*rm(:,N);
    for t=N-1:-1:1; W_out(:,t)=Di(:,:,t)*(rm(:,t)-B*W_out(:,t+1)); end
end

%% TRIDIAGONAL UTILITIES
function [d,e]=build_rw_prior_hess(N,is2,isI2)
    d=zeros(N,1); e=zeros(max(N-1,0),1);
    if N==1; d(1)=isI2; return; end
    d(1)=isI2+is2; d(2:N-1)=2*is2; d(N)=is2; e(:)=-is2;
end
function y=tridiag_multiply(d,e,x)
    N=length(d); y=d.*x;
    if N>1; y(1:N-1)=y(1:N-1)+e.*x(2:N); y(2:N)=y(2:N)+e.*x(1:N-1); end
end
function x=tridiag_solve_vec(d,e,b)
    N=length(d); dm=d; bm=b;
    for i=2:N; m=e(i-1)/dm(i-1); dm(i)=dm(i)-m*e(i-1); bm(i)=bm(i)-m*bm(i-1); end
    x=zeros(N,1); x(N)=bm(N)/dm(N);
    for i=N-1:-1:1; x(i)=(bm(i)-e(i)*x(i+1))/dm(i); end
end
function [iv,io,ld]=tridiag_inv_diag_offdiag(d,e)
    N=length(d);
    if N==1; iv=1/d(1); io=[]; ld=log(abs(d(1))); return; end
    df=zeros(N,1); ls=zeros(N-1,1); df(1)=d(1);
    for i=2:N; ls(i-1)=e(i-1)/df(i-1); df(i)=d(i)-ls(i-1)*e(i-1); end
    ld=sum(log(abs(df)));
    iv=zeros(N,1); iv(N)=1/df(N);
    for i=N-1:-1:1; iv(i)=1/df(i)+ls(i)^2*iv(i+1); end
    io=zeros(N-1,1); for i=1:N-1; io(i)=-ls(i)*iv(i+1); end
    iv=abs(iv);
end

%% HELPERS
function p=sigmoid_fn(x); x=max(min(x,500),-500); p=1./(1+exp(-x)); end

function m=compute_metrics(yt,yp,np,nt)
    yc=max(min(yp,1-1e-10),1e-10);
    ll=sum(yt.*log(yc)+(1-yt).*log(1-yc));
    pn=mean(yt); lln=nt*(pn*log(pn+1e-10)+(1-pn)*log(1-pn+1e-10));
    if lln~=0; pr2=1-(ll/lln); else; pr2=0; end
    try; [~,~,~,auc]=perfcurve(yt,yp,1); catch; auc=0.5; end
    m.log_likelihood=ll; m.pseudo_r2=pr2; m.auc=auc;
    m.accuracy=mean((yp>0.5)==yt); m.bic=-2*ll+np*log(nt);
    m.aic=-2*ll+2*np; m.n_params=np;
end

function [pr,or]=compute_running_accuracy(out,targ,pos,win)
    N=length(out); np=length(pos); pr=cell(np,1);
    for p=1:np; pr{p}=nan(N,1); end; or=nan(N,1);
    for t=1:N; s=max(1,t-win); e=min(N,t+win);
        if (e-s+1)>=3; or(t)=mean(out(s:e)); end
        for p=1:np; mk=targ(s:e)==pos(p);
            if sum(mk)>=2; ch=out(s:e); pr{p}(t)=mean(ch(mk)); end; end
    end
end

function [fpr,tpr]=compute_roc(yt,yp)
    th=sort(unique(yp),'descend'); th=[1+eps;th;-eps];
    fpr=zeros(length(th),1); tpr=fpr;
    P=sum(yt==1); Nn=sum(yt==0);
    for i=1:length(th); pp=yp>=th(i);
        tpr(i)=sum(pp&yt==1)/max(P,1); fpr(i)=sum(pp&yt==0)/max(Nn,1); end
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
