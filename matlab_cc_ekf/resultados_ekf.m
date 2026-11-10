% RESULTADOS - métricas e gráficos da CC e do EKF (rodar pelo main.m)
% Cenário s da condição inicial i e do Q11 c: s = (i-1)*n_q + c
% Todas as métricas usam a MESMA régua (metricas_erro.m), nos MESMOS instantes (t_med >= t_inicio_avaliacao_min),
% contra a MESMA referência (Soc_ref). A LSTM, no Colab, vai usar exatamente essa definição.
% Salva a tabela em 'resultados ekf\metricas_<modo>_<perfil>.csv' (base da tabela final CC × EKF × LSTM)

idx_aval = find(t_med >= t_inicio_avaliacao_min);         % Instantes avaliados (iguais para todos os métodos)

% --- Métricas: uma linha por método e SoC inicial assumido ---
metodo_rmse = {};                                         % Nome do método de cada linha
Soc0_est_rmse = [];                                       % SoC inicial assumido de cada linha (%)
valor_rmse = []; valor_mae = []; valor_max = []; valor_tconv = []; valor_tempo = [];   % Métricas de cada linha
valor_3sig = [];                                          % Consistência do EKF: fração do tempo com |erro| <= 3·sqrt(P11) (NaN para a CC, que não tem P)
rmse_cc = zeros(n_ini, 1);                                % RMSE da CC por condição inicial (%), mesmo nome da AP
rmse_ekf = zeros(n_cen, 1);                               % RMSE do EKF por cenário (%), mesmo nome da AP
for i = 1:n_ini                                           % Uma condição inicial por vez
    [rmse_cc(i), mae_i, max_i, tconv_i] = metricas_erro(Soc_cc(i,idx_aval), Soc_ref(idx_aval), t_med(idx_aval), limiar_conv);   % Métricas da CC
    metodo_rmse{end+1} = 'CC';                            % Linha da CC
    Soc0_est_rmse(end+1) = lista_Soc0_est(i)*100;         % SoC inicial assumido (%)
    valor_rmse(end+1) = rmse_cc(i); valor_mae(end+1) = mae_i; valor_max(end+1) = max_i; valor_tconv(end+1) = tconv_i;   % Guarda as métricas
    valor_tempo(end+1) = tempo_cc(i);                     % Tempo de execução (s)
    valor_3sig(end+1) = NaN;                              % A CC não calcula incerteza
    for c = 1:n_q                                         % Uma linha por Q11 do EKF
        s = (i-1)*n_q + c;                                % Linha do cenário (condição i, Q11 c)
        [rmse_ekf(s), mae_s, max_s, tconv_s] = metricas_erro(Soc_ekf(s,idx_aval), Soc_ref(idx_aval), t_med(idx_aval), limiar_conv);   % Métricas do EKF
        metodo_rmse{end+1} = ['EKF (' nomes_Q11{c} ')'];  % Nome do método com o Q11
        Soc0_est_rmse(end+1) = lista_Soc0_est(i)*100;     % SoC inicial assumido (%)
        valor_rmse(end+1) = rmse_ekf(s); valor_mae(end+1) = mae_s; valor_max(end+1) = max_s; valor_tconv(end+1) = tconv_s;   % Guarda as métricas
        valor_tempo(end+1) = tempo_ekf(s);                % Tempo de execução (s)
        erro_s = Soc_ekf(s,idx_aval) - Soc_ref(idx_aval);  % Erro do EKF (fração) nos instantes avaliados
        sigma_s = sqrt(P11_hist(s,idx_aval));             % Incerteza que o próprio filtro calcula (desvio padrão do SoC)
        valor_3sig(end+1) = mean(abs(erro_s) <= 3*sigma_s);   % Filtro consistente: perto de 1 (o erro cabe na incerteza que ele declara)
    end
end

% --- Tabela no Command Window (desligada no rodar_cenarios.m) ---
if imprimir_resultados
fprintf('\nPerfil: %s | modo %s | fonte: %s | planta de ordem %d | sensor: %s | SoC inicial real: %.0f %% | Ts_med = %g s\n', ...
    nome_perfil, modo_config, fonte_dados, ordem_planta, cenario_sensor, Soc0*100, Ts_med);   % Cabeçalho
fprintf('%-24s %8s %8s %8s %8s %10s %9s %9s\n', 'Método', 'SoC0 (%)', 'RMSE(%)', 'MAE(%)', 'Máx(%)', 'tconv(min)', 'tempo(s)', 'em ±3σ');   % Títulos das colunas
for j = 1:length(valor_rmse)                              % Uma linha por método/condição
    fprintf('%-24s %8.0f %8.3f %8.3f %8.3f %10.1f %9.3f %9.2f\n', metodo_rmse{j}, Soc0_est_rmse(j), valor_rmse(j), valor_mae(j), valor_max(j), valor_tconv(j), valor_tempo(j), valor_3sig(j));
end
end

% --- Tabela em arquivo (com as condições do ensaio, para reprodutibilidade) ---
n_linhas_rmse = length(valor_rmse);                       % Número de linhas da tabela
tabela_rmse = table(repmat({rotulo_perfil}, n_linhas_rmse, 1), repmat({fonte_dados}, n_linhas_rmse, 1), ...
    repmat({modo_config}, n_linhas_rmse, 1), repmat(ordem_planta, n_linhas_rmse, 1), repmat({cenario_sensor}, n_linhas_rmse, 1), ...
    repmat(Ts_med, n_linhas_rmse, 1), repmat(Soc0*100, n_linhas_rmse, 1), ...
    Soc0_est_rmse', metodo_rmse', valor_rmse', valor_mae', valor_max', valor_tconv', valor_tempo', valor_3sig', ...
    repmat(t_inicio_avaliacao_min, n_linhas_rmse, 1), ...
    'VariableNames', {'perfil', 'fonte', 'modo', 'ordem_planta', 'cenario_sensor', 'Ts_med_s', 'Soc0_real_pct', 'Soc0_est_pct', 'metodo', ...
                      'rmse_pct', 'mae_pct', 'erro_max_pct', 't_conv_min', 'tempo_exec_s', 'frac_dentro_3sigma', 't_inicio_aval_min'});   % Monta a tabela (o ' transforma linha em coluna)
pasta_res = fullfile(pwd, 'resultados ekf');              % Mesma pasta das figuras
if ~exist(pasta_res, 'dir'), mkdir(pasta_res); end        % Cria a pasta se não existir
if salvar_metricas_individuais                            % No rodar_cenarios.m, quem grava é ele (todos os sorteios juntos)
    nome_res = fullfile(pasta_res, ['metricas_' modo_config '_' rotulo_perfil '_' cenario_sensor '.csv']);   % Ex.: metricas_AF_val100_p3_proprio.csv
    writetable(tabela_rmse, nome_res);                    % Grava a tabela
    fprintf('Métricas salvas em: %s\n', nome_res);        % Confirma no Command Window
end

% --- Gráficos: um par de figuras por condição inicial (desligados no rodar_cenarios.m) ---
for i = 1:n_ini*plotar_resultados                                 % Com plotar_resultados = false, o laço vai de 1 a 0 e não roda
    s1 = (i-1)*n_q + 1;                                           % Cenário com Q11 da Tabela 11
    s2 = (i-1)*n_q + 2;                                           % Cenário com Q11 alternativo
    txt_ini = sprintf(' - %s (%s, planta %d, %s) - SoC inicial assumido: %.0f%%', nome_perfil, modo_config, ordem_planta, cenario_sensor, lista_Soc0_est(i)*100);   % Complemento do título (evita sobrescrever arquivos)

    % Gráfico 1: SoC de referência vs CC vs EKF
    figure;
    plot(t_med(idx_plot_med), Soc_ref(idx_plot_med), 'k-', 'LineWidth', 1.5);       % SoC de referência (verdadeiro na simulação)
    hold on;
    plot(t_med(idx_plot_med), Soc_cc(i,idx_plot_med), 'r--', 'LineWidth', 1);       % CC
    plot(t_med(idx_plot_med), Soc_ekf(s1,idx_plot_med), 'b-', 'LineWidth', 1);      % EKF Tabela 11
    plot(t_med(idx_plot_med), Soc_ekf(s2,idx_plot_med), 'g-', 'LineWidth', 1);      % EKF Q11 alternativo
    hold off;
    lgd = legend('SoC (referência)', 'SoC (CC)', 'SoC (EKF - Tabela 11)', 'SoC (EKF - Q_{11} alternativo)', 'Location', 'best');
    set(lgd, 'FontName', 'Times New Roman', 'TextColor', 'k', 'Color', 'w', 'EdgeColor', 'k');
    aplicar_estilo_artigo(['SoC: referência vs CC vs EKF' txt_ini], 'Tempo (min)', 'SoC (fração)');

    % Gráfico 2: diagnóstico (erro, P(1,1) e K(1))
    figure;
    subplot(3,1,1);
    plot(t_med(idx_plot_med), (Soc_ekf(s1,idx_plot_med) - Soc_ref(idx_plot_med))*100, 'b-');   % Erro Tabela 11, em %
    hold on;
    plot(t_med(idx_plot_med), (Soc_ekf(s2,idx_plot_med) - Soc_ref(idx_plot_med))*100, 'g-');   % Erro Q11 alternativo, em %
    plot(t_med(idx_plot_med),  3*sqrt(P11_hist(s1,idx_plot_med))*100, 'b:');                  % +3σ que o filtro (Tabela 11) declara
    plot(t_med(idx_plot_med), -3*sqrt(P11_hist(s1,idx_plot_med))*100, 'b:', 'HandleVisibility', 'off');   % -3σ (fora da legenda)
    plot(t_med(idx_plot_med),  3*sqrt(P11_hist(s2,idx_plot_med))*100, 'g:');                  % +3σ do filtro com Q11 alternativo
    plot(t_med(idx_plot_med), -3*sqrt(P11_hist(s2,idx_plot_med))*100, 'g:', 'HandleVisibility', 'off');   % -3σ (fora da legenda)
    yline(0, 'k-', 'HandleVisibility', 'off');                                                % Erro zero
    hold off;
    lgd = legend('Tabela 11', 'Q_{11} alternativo', '±3σ (Tabela 11)', '±3σ (Q_{11} alt.)', 'Location', 'best');   % Erro dentro da faixa = filtro consistente
    set(lgd, 'FontName', 'Times New Roman', 'TextColor', 'k', 'Color', 'w', 'EdgeColor', 'k');
    aplicar_estilo_artigo(['Erro do SoC (EKF - referência)' txt_ini], 'Tempo (min)', 'Erro (%)');

    subplot(3,1,2);
    semilogy(t_med(idx_plot_med), P11_hist(s1,idx_plot_med), 'b-');                % P(1,1) Tabela 11
    hold on;
    semilogy(t_med(idx_plot_med), P11_hist(s2,idx_plot_med), 'g-');                % P(1,1) Q11 alternativo
    hold off;
    aplicar_estilo_artigo('P(1,1)', 'Tempo (min)', 'Variância');

    subplot(3,1,3);
    semilogy(t_med(idx_plot_med), abs(K1_hist(s1,idx_plot_med)), 'b-');           % K(1) Tabela 11
    hold on;
    semilogy(t_med(idx_plot_med), abs(K1_hist(s2,idx_plot_med)), 'g-');           % K(1) Q11 alternativo
    hold off;
    aplicar_estilo_artigo('K(1)', 'Tempo (min)', 'Ganho');
end
