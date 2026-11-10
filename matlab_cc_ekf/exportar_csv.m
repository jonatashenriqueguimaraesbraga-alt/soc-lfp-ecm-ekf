% EXPORTAR CSV PARA A LSTM (Python/Colab) - rodado pelo gerar_dados_lstm.m (ou à mão, depois do main), usa as variáveis do workspace
% Exporta a camada de MEDIÇÃO (as mesmas amostras que a CC e o EKF recebem), no período passo_csv_s (configuracao.m)
% Colunas: t_min (min), I_medido (A, com bias + ruído), Vt_medido (V, com ruído), Soc (fração 0-1, referência Soc_ref)
% Nome do arquivo: dados_lstm_<papel>_<perfil>_<cenario_sensor>_r<semente dos sensores>_1s.csv (ex.: dados_lstm_teste_val100_p3_ref_bias_r7_1s.csv)

if ~exist('papel_csv', 'var'), papel_csv = 'avulso'; end           % Se rodar à mão (fora do gerar_dados_lstm), o arquivo sai como "avulso"
passo_csv = max(1, round(passo_csv_s / Ts_med));                    % Medições por período do .csv (com Ts_med = 1 s e passo_csv_s = 1 s, todas)
idx_csv = 1:passo_csv:N_med;                                        % Índices das medições que vão para o arquivo
tabela_csv = table(t_med(idx_csv)', I_medido(idx_csv)', Vt_medido(idx_csv)', Soc_ref(idx_csv)', ...
    'VariableNames', {'t_min', 'I_medido', 'Vt_medido', 'Soc'});   % Monta a tabela; o ' transforma cada vetor linha em coluna
if ~exist('subpasta_csv', 'var'), subpasta_csv = 'dados_lstm'; end   % Subpasta de destino (o gerar_dados_lstm_extra.m usa 'dados_lstm_extra')
pasta_csv = fullfile(pwd, 'resultados ekf', subpasta_csv);          % Subpasta só para os dados da LSTM (é ela que vai para o Colab)
if ~exist(pasta_csv, 'dir'), mkdir(pasta_csv); end                  % Cria a pasta se ela não existir
nome_csv = fullfile(pasta_csv, sprintf('dados_lstm_%s_%s_%s_r%d_%gs.csv', papel_csv, rotulo_perfil, cenario_sensor, semente_rng, passo_csv_s));   % Caminho completo do arquivo
writetable(tabela_csv, nome_csv);                                   % Grava o CSV (separador vírgula, ponto decimal: lê direto no pandas)
fprintf('CSV salvo em: %s (%d linhas)\n', nome_csv, height(tabela_csv));   % Confirma no Command Window
