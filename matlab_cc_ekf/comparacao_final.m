% COMPARAÇÃO FINAL (L3) - CC × EKF × LSTM nos mesmos perfis de teste: tabelas e figuras da apresentação final e do artigo
% Antes de rodar:
%   1) rodar_cenarios.m já rodado (resultados ekf\metricas_MC_todos.csv: CC e EKF, 3 perfis × 3 cenários × 20 sorteios)
%   2) resultados da LSTM do Colab (rodada 9: versão 10 com 10 sementes) na pasta da seção 9b do configuracao.m
% O que faz:
%   Parte 1: recalcula as métricas da LSTM no MATLAB com a MESMA função da CC e do EKF (metricas_erro.m), a partir do SoC
%            previsto pelo Colab nos mesmos 180 arquivos de teste, e confere com os números do Colab
%   Parte 2: junta os três métodos numa tabela só (todos os sorteios + resumo com média e desvio padrão),
%            mostra no Command Window e escreve a tabela do artigo em LaTeX (tabela_rmse_artigo.tex, 1 coluna)
%   Parte 3: figuras do artigo (SoC e erro no tempo no perfil/SoC inicial do configuracao.m, seção 9b; perfis de corrente de teste)
%            e, se gerar_figuras_extras = true, as outras figuras de SoC e as barras do RMSE (para os slides)
% O que entra no artigo e por quê: claude/plano_artigo_af.md (04/11)
% Saídas em resultados ekf\comparacao_AF

clear; clc; close all;            % Começa limpo
fonte_dados = 'simulacao';        % Dados simulados (planta da Tabela 7 completa)
configuracao;                     % Carrega todos os ajustes (a seção 9b tem os desta comparação)
plotar_dados = false;             % Sem os gráficos de corrente e tensão de cada simulação
plotar_resultados = false;        % Sem os gráficos do resultados_ekf (as figuras daqui são outras)
imprimir_resultados = false;      % Sem a tabela de cada rodada
salvar_metricas_individuais = false;   % Não grava metricas_*.csv avulsos
semente_perfil = 0;               % Perfis de teste não usam semente

% --- Pastas ---
pasta_res = fullfile(pwd, 'resultados ekf');               % Pasta dos resultados (a mesma do rodar_cenarios.m)
pasta_comp = fullfile(pasta_res, 'comparacao_AF');         % Pasta de saída desta comparação
if ~exist(pasta_comp, 'dir'), mkdir(pasta_comp); end       % Cria a pasta se não existir
pasta_lstm = fullfile(pwd, pasta_lstm_res);                % Pasta dos resultados da LSTM (configuracao.m, seção 9b)
[~, nome_pasta_lstm] = fileparts(pasta_lstm_res);           % Nome da pasta da LSTM (ex.: resultados_lstm_v10_10s)
if exist(fullfile(pasta_lstm, nome_pasta_lstm), 'dir')     % O .zip do Drive cria uma subpasta com o mesmo nome...
    pasta_lstm = fullfile(pasta_lstm, nome_pasta_lstm);    % ...então entra nela
end
pasta_prev = fullfile(pasta_lstm, 'previsoes');            % SoC previsto pela LSTM em cada arquivo de teste
if ~exist(pasta_prev, 'dir')                               % Sem as previsões não dá para recalcular as métricas
    error('Pasta de previsões da LSTM não encontrada: %s', pasta_prev);
end

% --- Métodos e rótulos (mesma ordem nas tabelas e nas figuras) ---
nome_comite = sprintf('LSTM (comitê de %d)', n_redes_lstm);  % Nome do comitê, igual ao do Colab (ex.: LSTM (comitê de 10))
metodos_tab = {'CC', 'EKF (Tabela 11)', 'EKF (Q11 alternativo)', 'LSTM', nome_comite};   % Nomes iguais aos dos .csv
rotulos_tex = {'CC', 'EKF, $Q_{11}$ da referência', 'EKF, $Q_{11}$ alternativo', ...
               sprintf('LSTM, %d redes\\textsuperscript{a}', n_redes_lstm), sprintf('LSTM, comitê de %d\\textsuperscript{a}', n_redes_lstm)};   % Nomes (LaTeX)
usa_Soc0 = [true, true, true, false, false];               % A LSTM não recebe SoC inicial assumido (linha sem Soc0_est_pct)
rotulos_perfis = cell(1, length(lista_perfis_teste));      % Nome de cada perfil nas tabelas e figuras
for i_perfil = 1:length(lista_perfis_teste)                % Um perfil por vez
    if strcmp(lista_perfis_teste{i_perfil}, 'val100')      % Perfil da referência (Fig. 26a)
        rotulos_perfis{i_perfil} = 'val100';               % Mantém o nome usado no trabalho
    else                                                   % Ciclos padrão
        rotulos_perfis{i_perfil} = upper(lista_perfis_teste{i_perfil});   % FUDS, US06
    end
end
rotulos_cenarios = {'Nominal', 'Bias', 'Ruído'};           % Nomes dos cenários de sensor (mesma ordem de lista_cenarios_sensor)

% =====================================================================
% PARTE 1: métricas da LSTM recalculadas com a mesma régua (metricas_erro.m)
% =====================================================================
tab_lstm_colab = readtable(fullfile(pasta_lstm, 'metricas_MC_todos_LSTM.csv'), 'Encoding', 'UTF-8');   % Números do Colab (conferência e tempo de execução)
lin_perfil = {}; lin_sensor = {}; lin_metodo = {};         % Colunas de texto da tabela da LSTM (uma linha por rede × arquivo)
lin_semente = []; lin_sem_treino = []; lin_Soc0_real = []; % Sorteio dos sensores, semente de treino (NaN = comitê) e SoC inicial real (%)
lin_rmse = []; lin_mae = []; lin_max = []; lin_tconv = []; lin_tempo = [];   % Métricas de cada linha
dif_max_colab = 0;                                         % Maior diferença de RMSE entre o MATLAB e o Colab (p.p.)
n_sem_par = 0;                                             % Linhas sem correspondente no arquivo do Colab
n_amostras_perfil = zeros(1, length(lista_perfis_teste));  % Amostras por arquivo de teste (para o tempo por amostra)
fprintf('Parte 1: lendo as previsões da LSTM (%d arquivos)...\n', length(lista_perfis_teste)*length(lista_cenarios_sensor)*n_monte_carlo);
for i_perfil = 1:length(lista_perfis_teste)                % Perfil de teste
    rot_p = sprintf('%s_p%d', lista_perfis_teste{i_perfil}, ordem_planta);   % Rótulo do perfil nos arquivos (ex.: fuds_p3)
    for i_sensor = 1:length(lista_cenarios_sensor)         % Cenário de erro de corrente
        cen = lista_cenarios_sensor{i_sensor};             % Nome do cenário
        for i_mc = 1:n_monte_carlo                         % Sorteio de ruído (mesmas sementes da CC e do EKF)
            arq = fullfile(pasta_prev, sprintf('previsao_dados_lstm_teste_%s_%s_r%d_%gs.csv', rot_p, cen, i_mc, passo_csv_s));   % Arquivo do Colab
            if ~exist(arq, 'file'), error('Arquivo de previsão não encontrado: %s', arq); end   % Para se faltar algum
            prev = readtable(arq);                         % Colunas: t_min, Soc (referência), Soc_lstm_s1 a s5, Soc_lstm_media
            n_amostras_perfil(i_perfil) = height(prev);    % Número de amostras do perfil (igual em todos os sorteios)
            t_l = prev.t_min';                             % Tempo (min), como linha
            Soc_ref_l = prev.Soc';                         % SoC de referência (verdadeiro), como linha
            idx_l = find(t_l >= t_inicio_avaliacao_min);   % Mesmos instantes avaliados da CC e do EKF (desde t = 0)
            nomes_col = prev.Properties.VariableNames;     % Nomes das colunas do arquivo
            col_redes = nomes_col(startsWith(nomes_col, 'Soc_lstm_s'));   % Uma coluna por rede (semente de treino)
            if length(col_redes) ~= n_redes_lstm           % O número de redes do Colab tem de ser o do configuracao.m
                error('A previsão tem %d redes e o configuracao.m espera n_redes_lstm = %d: confira a pasta da LSTM (%s).', length(col_redes), n_redes_lstm, arq);
            end
            for j = 0:length(col_redes)                    % j = 0: comitê; j = 1 a 5: rede j
                if j == 0                                  % Comitê = média das saídas das redes
                    Soc_l = prev.Soc_lstm_media';          % SoC estimado pelo comitê
                    nome_m = nome_comite;                  % Mesmo nome usado no Colab
                    sem_tr = NaN;                          % O comitê não tem semente de treino
                else                                       % Rede individual
                    Soc_l = prev.(col_redes{j})';          % SoC estimado pela rede j
                    nome_m = 'LSTM';                       % Mesmo nome usado no Colab
                    sem_tr = str2double(erase(col_redes{j}, 'Soc_lstm_s'));   % Semente de treino (1 a 5)
                end
                [rmse_l, mae_l, max_l, tconv_l] = metricas_erro(Soc_l(idx_l), Soc_ref_l(idx_l), t_l(idx_l), limiar_conv);   % MESMA régua da CC e do EKF
                linha_colab = strcmp(tab_lstm_colab.perfil, rot_p) & strcmp(tab_lstm_colab.cenario_sensor, cen) & ...
                    tab_lstm_colab.semente == i_mc & strcmp(tab_lstm_colab.metodo, nome_m) & ...
                    (tab_lstm_colab.semente_treino == sem_tr | (isnan(tab_lstm_colab.semente_treino) & isnan(sem_tr)));   % Mesma linha no arquivo do Colab
                if nnz(linha_colab) == 1                   % Achou exatamente uma linha
                    dif_max_colab = max(dif_max_colab, abs(rmse_l - tab_lstm_colab.rmse_pct(linha_colab)));   % Diferença de RMSE
                    tempo_l = tab_lstm_colab.tempo_exec_s(linha_colab);   % Tempo de execução medido no Colab (CPU), s
                else                                       % Não achou (ou achou repetida)
                    n_sem_par = n_sem_par + 1;             % Conta para avisar no fim
                    tempo_l = NaN;                         % Sem tempo para esta linha
                end
                lin_perfil{end+1} = rot_p; lin_sensor{end+1} = cen; lin_metodo{end+1} = nome_m;   % Texto da linha
                lin_semente(end+1) = i_mc; lin_sem_treino(end+1) = sem_tr; lin_Soc0_real(end+1) = Soc_ref_l(1)*100;   % Identificação da linha
                lin_rmse(end+1) = rmse_l; lin_mae(end+1) = mae_l; lin_max(end+1) = max_l; lin_tconv(end+1) = tconv_l;    % Métricas
                lin_tempo(end+1) = tempo_l;                % Tempo de execução (s)
            end
        end
    end
end
n_l = length(lin_rmse);                                    % Número de linhas da LSTM (180 arquivos × 6 = 1080)
tabela_lstm = table(lin_perfil', lin_sensor', lin_Soc0_real', NaN(n_l, 1), lin_metodo', lin_semente', lin_sem_treino', ...
    lin_rmse', lin_mae', lin_max', lin_tconv', double(~isnan(lin_tconv')), lin_tempo', NaN(n_l, 1), ...
    'VariableNames', {'perfil', 'cenario_sensor', 'Soc0_real_pct', 'Soc0_est_pct', 'metodo', 'semente', 'semente_treino', ...
                      'rmse_pct', 'mae_pct', 'erro_max_pct', 't_conv_min', 'convergiu', 'tempo_exec_s', 'frac_dentro_3sigma'});   % Mesmas colunas da tabela da CC e do EKF
fprintf('Conferência com o Colab: maior diferença de RMSE = %.2e p.p. (%d linhas sem correspondente)\n', dif_max_colab, n_sem_par);   % Deve dar ~1e-6 (arredondamento do .csv) e 0
if dif_max_colab > 1e-3 || n_sem_par > 0                   % Diferença acima do arredondamento: régua diferente ou arquivo trocado
    warning('As métricas da LSTM no MATLAB não batem com as do Colab: confira os arquivos antes de usar a tabela.');
end

% =====================================================================
% PARTE 2: tabela única CC × EKF × LSTM
% =====================================================================
tabela_cc_ekf = readtable(fullfile(pasta_res, 'metricas_MC_todos.csv'), 'Encoding', 'UTF-8');   % CC e EKF (rodar_cenarios.m)
tabela_cc_ekf.semente_treino = NaN(height(tabela_cc_ekf), 1);   % CC e EKF não têm semente de treino
cols_comp = tabela_lstm.Properties.VariableNames;          % Colunas da tabela única (as da LSTM, que são as da CC e do EKF + semente_treino)
tabela_comp = [tabela_cc_ekf(:, cols_comp); tabela_lstm];  % Junta os três métodos (uma linha por método × SoC inicial × sorteio × rede)
resumo_comp = groupsummary(tabela_comp, {'perfil', 'cenario_sensor', 'Soc0_est_pct', 'metodo'}, {'mean', 'std'}, ...
    {'rmse_pct', 'mae_pct', 'erro_max_pct', 'tempo_exec_s', 'convergiu'});   % Média e desvio padrão por combinação (LSTM: Soc0_est_pct = NaN)
writetable(tabela_comp, fullfile(pasta_comp, 'metricas_comparacao_todos.csv'));    % Todos os números
writetable(resumo_comp, fullfile(pasta_comp, 'metricas_comparacao_resumo.csv'));   % Tabela do trabalho

% --- Tabela no Command Window: RMSE (média ± desvio padrão), SoC inicial assumido correto e com erro de 10% ---
lista_Soc0_pct = round((1 + lista_erro_Soc0)*100);         % SoC inicial assumido (%): todos os perfis de teste começam em 100% → [100 90]
fprintf('\nRMSE do SoC (%%): média ± desvio padrão em %d sorteios (LSTM, %d redes: %d × %d valores)\n', n_monte_carlo, n_redes_lstm, n_redes_lstm, n_monte_carlo);
for i_sensor = 1:length(lista_cenarios_sensor)             % Um bloco por cenário de sensor
    cen = lista_cenarios_sensor{i_sensor};                 % Nome do cenário
    fprintf('\nCenário: %s\n%-22s', cen, 'Método');        % Cabeçalho do bloco
    for i_perfil = 1:length(lista_perfis_teste)            % Títulos das colunas
        for i_ini = 1:length(lista_Soc0_pct)               % SoC inicial assumido
            fprintf(' | %-15s', sprintf('%s %d%%', rotulos_perfis{i_perfil}, lista_Soc0_pct(i_ini)));
        end
    end
    fprintf('\n');                                         % Fim do cabeçalho
    for m = 1:length(metodos_tab)                          % Uma linha por método
        fprintf('%-22s', metodos_tab{m});                  % Nome do método
        for i_perfil = 1:length(lista_perfis_teste)        % Perfil
            rot_p = sprintf('%s_p%d', lista_perfis_teste{i_perfil}, ordem_planta);   % Rótulo do perfil no .csv
            for i_ini = 1:length(lista_Soc0_pct)           % SoC inicial assumido
                Soc0_busca = lista_Soc0_pct(i_ini);        % SoC inicial procurado na tabela
                if ~usa_Soc0(m), Soc0_busca = NaN; end     % A LSTM não depende do SoC inicial: o mesmo valor nas duas colunas
                [mm, ss] = valor_resumo(resumo_comp, rot_p, cen, Soc0_busca, metodos_tab{m}, 'rmse_pct');   % Média e desvio padrão
                fprintf(' | %6.2f ± %6.2f', mm, ss);       % Valor da célula
            end
        end
        fprintf('\n');                                     % Fim da linha
    end
end

% --- Convergência: fração de sorteios que terminam dentro de ±2 p.p. (ajuda a achar sorteios em que o EKF divergiu) ---
fprintf('\nFração de sorteios que terminam dentro de ±%.0f p.p. (1 = todos):\n', limiar_conv*100);
for i_sensor = 1:length(lista_cenarios_sensor)             % Cenário
    cen = lista_cenarios_sensor{i_sensor};                 % Nome do cenário
    for m = 1:length(metodos_tab)                          % Método
        fprintf('%-10s %-22s', cen, metodos_tab{m});       % Identificação da linha
        for i_perfil = 1:length(lista_perfis_teste)        % Perfil
            rot_p = sprintf('%s_p%d', lista_perfis_teste{i_perfil}, ordem_planta);   % Rótulo do perfil
            for i_ini = 1:length(lista_Soc0_pct)           % SoC inicial assumido
                Soc0_busca = lista_Soc0_pct(i_ini);        % SoC inicial procurado
                if ~usa_Soc0(m), Soc0_busca = NaN; end     % LSTM: sem SoC inicial
                [mm, ~] = valor_resumo(resumo_comp, rot_p, cen, Soc0_busca, metodos_tab{m}, 'convergiu');   % Fração de sorteios convergidos
                fprintf(' | %s %3d%%: %4.2f', rotulos_perfis{i_perfil}, lista_Soc0_pct(i_ini), mm);
            end
        end
        fprintf('\n');                                     % Fim da linha
    end
end

% --- Custo computacional: tempo por perfil e por amostra (cenário nominal, SoC inicial correto) ---
fprintf('\nTempo de execução (cenário nominal). CC e EKF: este PC; LSTM: CPU do Colab (máquinas diferentes, só ordem de grandeza)\n');
for i_perfil = 1:length(lista_perfis_teste)                % Perfil
    rot_p = sprintf('%s_p%d', lista_perfis_teste{i_perfil}, ordem_planta);   % Rótulo do perfil
    for m = 1:length(metodos_tab)                          % Método
        Soc0_busca = 100;                                  % SoC inicial correto
        if ~usa_Soc0(m), Soc0_busca = NaN; end             % LSTM: sem SoC inicial
        [mm, ~] = valor_resumo(resumo_comp, rot_p, 'nominal', Soc0_busca, metodos_tab{m}, 'tempo_exec_s');   % Tempo médio por perfil (s)
        fprintf('%-8s %-22s %8.4f s por perfil | %8.2f µs por amostra\n', rotulos_perfis{i_perfil}, metodos_tab{m}, mm, ...
            mm / n_amostras_perfil(i_perfil) * 1e6);       % Tempo total e por amostra (µs)
    end
end

% --- Tabela do artigo em LaTeX (IEEEtran, 1 coluna, booktabs, vírgula decimal): RMSE média ± desvio padrão ---
% Plano do artigo (plano_artigo_af.md, 04/11): uma tabela só. Colunas = perfis de teste; linhas = métodos, em 4 blocos de cenário
% (nominal com SoC inicial correto, nominal com erro de 10%, bias e ruído com SoC inicial correto) + linha do EKF da referência (val100)
metodos_art = {'CC', 'EKF (Tabela 11)', 'LSTM', nome_comite};   % Métodos do artigo (o Q11 alternativo fica só no Command Window e nos .csv)
rotulos_art = {'CC', 'EKF', sprintf('LSTM, %d redes\\textsuperscript{a}', n_redes_lstm), 'LSTM, comitê\textsuperscript{a}'};   % Nomes dos métodos no artigo (LaTeX)
usa_Soc0_art = [true, true, false, false];                 % A LSTM não recebe SoC inicial assumido (procura a linha sem Soc0_est_pct)
blocos_cen = {'nominal', 'nominal', 'ref_bias', 'ref_ruido'};   % Cenário de sensor de cada bloco (mesma ordem do rmse_ref_val100)
blocos_Soc0 = [lista_Soc0_pct(1), lista_Soc0_pct(2), lista_Soc0_pct(1), lista_Soc0_pct(1)];   % SoC inicial assumido de cada bloco (%): 100, 90, 100, 100
txt_bias = strrep(sprintf('%g', bias_ref_A), '.', ',');    % Bias da referência com vírgula decimal (0,15)
txt_var = strrep(sprintf('%g', var_ruido_ref), '.', ',');  % Variância do ruído da referência com vírgula decimal (0,2)
blocos_titulo = {sprintf('Nominal, SoC inicial assumido de %d\\%%', blocos_Soc0(1)), ...
                 sprintf('Nominal, SoC inicial assumido de %d\\%%', blocos_Soc0(2)), ...
                 sprintf('Bias de %s\\,A na segunda metade, SoC inicial de %d\\%%', txt_bias, blocos_Soc0(3)), ...
                 sprintf('Ruído de variância %s\\,A$^2$, SoC inicial de %d\\%%', txt_var, blocos_Soc0(4))};   % Título de cada bloco (linha em itálico)
n_perf = length(lista_perfis_teste);                       % Número de colunas de valores (uma por perfil)
col_val100 = find(strcmp(lista_perfis_teste, 'val100'));   % Coluna do perfil da referência (única com valor do EKF da referência)
linhas_tex = {'\begin{table}[!t]', ...
    sprintf('\\caption{RMSE do SoC (\\%%) nos perfis de teste: média $\\pm$ desvio padrão em %d sorteios de ruído}', n_monte_carlo), ...
    '\label{tab:rmse}', '\centering', '\footnotesize', '\setlength{\tabcolsep}{4pt}', ...
    ['\begin{tabular}{l' repmat('c', 1, n_perf) '}'], '\toprule'};   % Abertura (largura de uma coluna da página)
linha = 'Método';                                          % Cabeçalho: nome da 1ª coluna
for i_perfil = 1:n_perf                                    % Um título por perfil
    linha = [linha ' & ' rotulos_perfis{i_perfil}];        % val100, FUDS, US06
end
linhas_tex{end+1} = [linha ' \\'];                         % Fecha o cabeçalho
for i_b = 1:length(blocos_cen)                             % Um bloco por cenário
    linhas_tex{end+1} = '\midrule';                        % Traço antes do bloco
    linhas_tex{end+1} = sprintf('\\multicolumn{%d}{l}{\\textit{%s}} \\\\', n_perf+1, blocos_titulo{i_b});   % Título do bloco
    for m = 1:length(metodos_art)                          % Uma linha por método
        linha = rotulos_art{m};                            % Nome do método
        for i_perfil = 1:n_perf                            % Uma célula por perfil
            rot_p = sprintf('%s_p%d', lista_perfis_teste{i_perfil}, ordem_planta);   % Rótulo do perfil no .csv
            Soc0_busca = blocos_Soc0(i_b);                 % SoC inicial do bloco
            if ~usa_Soc0_art(m), Soc0_busca = NaN; end     % LSTM: sem SoC inicial (no bloco de 90%, o mesmo valor do nominal)
            [mm, ss] = valor_resumo(resumo_comp, rot_p, blocos_cen{i_b}, Soc0_busca, metodos_art{m}, 'rmse_pct');   % Média e desvio padrão
            linha = [linha ' & ' strrep(sprintf('%.2f $\\pm$ %.2f', mm, ss), '.', ',')];   % Ex.: 1,51 $\pm$ 0,12 (vírgula decimal)
        end
        linhas_tex{end+1} = [linha ' \\'];                 % Fecha a linha do método
    end
    linha = 'EKF, referência\textsuperscript{b}';          % Linha do EKF da dissertação (só existe no perfil val100)
    for i_perfil = 1:n_perf                                % Uma célula por perfil
        if i_perfil == col_val100                          % Perfil da referência
            linha = [linha ' & ' strrep(sprintf('%.2f', rmse_ref_val100(i_b)), '.', ',')];   % Valor da Tab. 12 ou 14 (configuracao.m, seção 9b)
        else                                               % FUDS e US06: a referência não tem esses perfis
            linha = [linha ' & --'];                       % Traço (sem valor)
        end
    end
    linhas_tex{end+1} = [linha ' \\'];                     % Fecha a linha da referência
end
nota_a = sprintf(['\\textsuperscript{a}\\,A LSTM não recebe SoC inicial assumido: no bloco de %d\\%%, os valores repetem os do nominal. ' ...
    '%d redes: média $\\pm$ desvio padrão das %d sementes de treino nos %d sorteios; comitê: média das saídas das %d redes.'], blocos_Soc0(2), n_redes_lstm, n_redes_lstm, n_monte_carlo, n_redes_lstm);   % Nota a
nota_b = ['\textsuperscript{b}\,EKF da referência \refVS{Tabs.~12 e 14}, em dados experimentais, com o SoC de referência obtido por CC.'];   % Nota b (\refVS = macro do artigo)
linhas_tex = [linhas_tex, {'\bottomrule', '\end{tabular}', '', '\vspace{2pt}', ...
    ['\parbox{\columnwidth}{\footnotesize\raggedright ' nota_a ' \\ ' nota_b '}'], '\end{table}'}];   % Notas e fechamento
fid = fopen(fullfile(pasta_comp, 'tabela_rmse_artigo.tex'), 'w', 'n', 'UTF-8');   % Abre o arquivo em UTF-8 (acentos)
fprintf(fid, '%s\n', linhas_tex{:});                       % Grava uma linha por vez (sem interpretar as barras do LaTeX)
fclose(fid);                                               % Fecha o arquivo
fprintf('\nTabela do artigo (tabela_rmse_artigo.tex) e métricas salvas em: %s\n', pasta_comp);   % Confirma

% =====================================================================
% PARTE 3: figuras
% =====================================================================
cor_lstm = [0.58 0.38 0.74];                               % Roxo médio para a LSTM (o lilás claro ficou apagado; o EKF por cima, mais escuro, continua visível; mesma cor nas barras)
verde = [0 0.6 0];                                         % Verde escuro do EKF com Q11 alternativo (o verde puro some na impressão)
larg = 8.8; alt_fig = 11;                                  % Figura de SoC: largura de uma coluna IEEE (cm) e altura com 2 gráficos + legenda em cima

% --- Figuras de SoC e erro no tempo: um sorteio (semente_figuras), cenário cenario_figuras, cada perfil e SoC inicial ---
fprintf('\nParte 3: figuras de SoC (sorteio %d, cenário %s)\n', semente_figuras, cenario_figuras);
n_fig = 0;                                                 % Contador de figuras (para não abrir uma em cima da outra)
for i_perfil = 1:length(lista_perfis_teste)                % Perfil de teste
    perfil = lista_perfis_teste{i_perfil};                 % Perfil desta volta
    if ~gerar_figuras_extras && ~strcmp(perfil, perfil_figura_artigo)   % Só as figuras do artigo: pula os outros perfis...
        continue;                                          % ...sem gastar tempo simulando
    end
    cenario_sensor = cenario_figuras;                      % Cenário de sensor das figuras
    simulacao_dados;                                       % Planta (gera Soc_ref, t_med, N_med etc.)
    lista_Soc0_est = Soc0 + lista_erro_Soc0;               % SoC inicial assumido (correto e com erro de 10%)
    semente_rng = semente_figuras;                         % Mesmo sorteio do arquivo de teste da LSTM (r1)
    sensores_simulados;                                    % Erros de sensor desse sorteio
    cc_bat;                                                % Contagem de Coulomb
    ekf_bat;                                               % EKF (Q11 da Tabela 11 e alternativo)
    arq = fullfile(pasta_prev, sprintf('previsao_dados_lstm_teste_%s_%s_r%d_%gs.csv', rotulo_perfil, cenario_sensor, semente_rng, passo_csv_s));   % Previsão da LSTM no mesmo arquivo
    prev = readtable(arq);                                 % SoC previsto pelas redes
    if height(prev) ~= N_med || max(abs(prev.Soc' - Soc_ref)) > 1e-6   % Mesmo número de amostras e mesma referência?
        error('A previsão da LSTM não bate com a simulação (%s): confira se os dados da LSTM são da mesma versão.', arq);
    end
    Soc_lstm = prev.Soc_lstm_media';                       % SoC do comitê (média das redes), como linha
    for i = 1:n_ini                                        % Uma figura por SoC inicial assumido
        s1 = (i-1)*n_q + 1;                                % Cenário do EKF com Q11 da Tabela 11
        s2 = (i-1)*n_q + 2;                                % Cenário do EKF com Q11 alternativo
        % --- Validação do modelo do EKF pela tensão (como o RMSE-Tensão das Tabs. 12 a 14 da referência e o erro de modelo de Xing et al., 2014) ---
        res_V = Vt_ekf(s1, 2:end) - Vt_medido(2:end);      % Resíduo: tensão prevista pelo EKF menos a medida (V); o passo 1 não tem previsão
        rmse_V_mV = sqrt(mean(res_V.^2)) * 1000;           % RMSE da tensão contra a MEDIDA (mV): o que dá para calcular com dados reais
        rmse_V_pct = sqrt(mean((res_V ./ Vt_medido(2:end)).^2)) * 100;   % O mesmo, relativo à tensão medida (%), para comparar em ordem de grandeza com a referência
        rmse_V_real_mV = sqrt(mean((Vt_ekf(s1, 2:end) - Vt_amostrado(2:end)).^2)) * 1000;   % Contra a tensão VERDADEIRA da planta (mV): só o erro do modelo de 1 ramo
        fprintf('Tensão prevista pelo EKF - %s, SoC inicial %d%%, sorteio %d: RMSE = %.2f mV (%.3f%%) contra a medida; %.2f mV contra a verdadeira\n', ...
            upper(perfil), round(lista_Soc0_est(i)*100), semente_rng, rmse_V_mV, rmse_V_pct, rmse_V_real_mV);   % Referência (val100): 0,011% (Tabs. 12 e 14)
        e_artigo = strcmp(perfil, perfil_figura_artigo) && round(lista_Soc0_est(i)*100) == Soc0_figura_artigo_pct;   % Esta é a figura do artigo?
        if ~gerar_figuras_extras && ~e_artigo, continue; end   % Só as figuras do artigo: pula o outro SoC inicial
        n_fig = n_fig + 1;                                 % Conta a figura
        fig = figure('Units', 'centimeters', 'Position', [1+n_fig 1+n_fig larg alt_fig]);   % Tamanho final do artigo

        % --- RMSE deste sorteio na legenda (como em Vieira et al., 2025, Fig. 13); a tabela usa a média dos 20 sorteios ---
        rmse_fig_cc = metricas_erro(Soc_cc(i,:), Soc_ref, t_med, limiar_conv);      % RMSE da CC neste sorteio (p.p.)
        rmse_fig_ekf = metricas_erro(Soc_ekf(s1,:), Soc_ref, t_med, limiar_conv);   % RMSE do EKF (Q da Tabela 11) neste sorteio
        rmse_fig_lstm = metricas_erro(Soc_lstm, Soc_ref, t_med, limiar_conv);       % RMSE do comitê da LSTM neste sorteio
        txt_rmse = @(v) strrep(sprintf('%.2f', v), '.', ',');                       % Função curta: número com 2 casas e vírgula decimal
        % --- Estilo das curvas (revisado): referência como faixa larga e clara EMBAIXO; estimativas finas POR CIMA, cada uma com cor, traço e marcador próprios ---
        lw_ref = 2.0; lw_cc = 0.9; lw_ekf = 0.9; lw_lstm = 0.6;   % Espessuras (pt): SoC verdadeiro largo (destaque, mas embaixo); CC e EKF iguais; LSTM fina (oscila: mais grossa vira uma mancha)
        cor_ref = [0.45 0.80 0.50];                        % Verde claro para a faixa do SoC verdadeiro: aparece por trás das estimativas sem cobri-las
        cor_cc = [0.85 0.10 0.10];                         % Vermelho da CC (um pouco mais escuro que o puro)
        cor_ekf = [0 0.25 0.75];                           % Azul escuro do EKF: contrasta com o roxo da LSTM quando as duas se cruzam
        cor_lstm_fig = cor_lstm;                           % Roxo da LSTM (o mesmo das barras)
        n_p = numel(idx_plot_med);                         % Número de pontos desenhados (1 por segundo)
        passo_suave = max(1, round(n_p/600));              % CC e EKF são curvas lisas: ~600 pontos bastam na largura de uma coluna (só no desenho; o RMSE usa todos os pontos)
        idx_s = idx_plot_med(unique([1:min(5,n_p), 1:passo_suave:n_p, n_p]));   % Pontos desenhados da CC e do EKF: os 5 primeiros (salto da 1ª correção do EKF), um a cada passo_suave e o último
        n_s = numel(idx_s);                                % Número de pontos da CC e do EKF no desenho
        % Por que reduzir: com 1 ponto por segundo (~12 mil), o tracejado é aplicado sobre milhares de segmentos minúsculos e os traços saem tortos/irregulares no PNG e no PDF
        passo_mk = max(1, round(n_s/10));                  % Um marcador a cada 1/10 do ensaio (10 por curva): nos artigos os marcadores são espaçados a intervalos regulares, não um por traço (um por traço engrossaria a linha de novo)
        mk = @(f) max(1, round(passo_mk*f)):passo_mk:n_s;  % Posições dos marcadores, deslocadas por método (f) para os marcadores não caírem um em cima do outro
        sty_cc = {'Marker', 's', 'MarkerSize', 2.6, 'MarkerFaceColor', cor_cc, 'MarkerEdgeColor', cor_cc};      % Quadrados pequenos preenchidos com a cor da CC
        sty_ekf = {'Marker', '^', 'MarkerSize', 2.8, 'MarkerFaceColor', cor_ekf, 'MarkerEdgeColor', cor_ekf};  % Triângulos pequenos preenchidos com a cor do EKF

        subplot(2,1,1);                                    % Em cima: SoC
        h_ref = plot(t_med(idx_plot_med), Soc_ref(idx_plot_med)*100, '-', 'Color', cor_ref, 'LineWidth', lw_ref);   % SoC verdadeiro PRIMEIRO: faixa verde larga por baixo (a referência fica visível e as estimativas aparecem sobre ela)
        hold on;                                           % Sobrepõe as próximas curvas
        h_lstm = plot(t_med(idx_plot_med), Soc_lstm(idx_plot_med)*100, '-', 'Color', cor_lstm_fig, 'LineWidth', lw_lstm);   % LSTM: linha cheia fina lilás, sem marcador (já é a única curva que oscila), logo acima do verdadeiro e abaixo da CC e do EKF
        h_cc = plot(t_med(idx_s), Soc_cc(i,idx_s)*100, '--', 'Color', cor_cc, 'LineWidth', lw_cc, 'MarkerIndices', mk(0.25), sty_cc{:});   % CC: tracejada + quadrados preenchidos
        h_ekf = plot(t_med(idx_s), Soc_ekf(s1,idx_s)*100, '-.', 'Color', cor_ekf, 'LineWidth', lw_ekf, 'MarkerIndices', mk(0.6), sty_ekf{:});   % EKF (Q da Tabela 11): traço-ponto + triângulos preenchidos, POR ÚLTIMO (fica por cima da LSTM)
        h_leg = [h_cc, h_ekf];                             % Linhas que entram na legenda (a ordem é montada abaixo)
        nomes_leg = {['CC (RMSE ' txt_rmse(rmse_fig_cc) '%)'], ['EKF (RMSE ' txt_rmse(rmse_fig_ekf) '%)']};   % Nome e RMSE deste sorteio
        if incluir_Q11_alt_figuras                          % EKF com Q11 alternativo, se pedido no configuracao.m
            h_alt = plot(t_med(idx_s), Soc_ekf(s2,idx_s)*100, ':', 'Color', verde, 'LineWidth', lw_cc);   % EKF alternativo (%)
            h_leg(end+1) = h_alt;                          % Entra na legenda
            nomes_leg{2} = ['EKF, Q_{11} da ref. (RMSE ' txt_rmse(rmse_fig_ekf) '%)'];   % Com dois EKF, diferencia pelo Q11
            nomes_leg{end+1} = 'EKF, Q_{11} alternativo';  % Nome do alternativo
        end
        hold off;                                          % Libera o gráfico
        lgd = legend([h_ref, h_leg, h_lstm], [{'SoC verdadeiro'}, nomes_leg, {['LSTM, comitê (RMSE ' txt_rmse(rmse_fig_lstm) '%)']}], ...
            'Location', 'northoutside', 'NumColumns', 2);  % Legenda acima do gráfico, em 2 colunas: não cobre nenhuma curva; ordem: verdadeiro, CC, EKF, LSTM
        set(lgd, 'FontName', 'Times New Roman', 'FontSize', 7, 'TextColor', 'k', 'Color', 'w', 'EdgeColor', 'k');   % Estilo da legenda
        aplicar_estilo_artigo('', '', 'SoC (%)');          % Padrão visual do projeto, sem título; o rótulo do tempo fica só no gráfico de baixo (economiza altura)
        set(gca, 'FontSize', 8);                           % Números dos eixos em 8 pt (legível em uma coluna)
        set(get(gca, 'YLabel'), 'FontSize', 9);            % Rótulo do eixo y em 9 pt
        xlim([0 max(t_med)]);                              % Do início ao fim do ensaio
        lim_y = ylim;                                      % Limites automáticos do eixo y do SoC
        ylim(lim_y + [-1 1] * 0.05 * diff(lim_y));         % Folga de 5%: a CC no fim do ensaio não encosta na moldura

        subplot(2,1,2);                                    % Embaixo: erro (estimado - verdadeiro)
        yline(0, '-', 'Color', cor_ref, 'LineWidth', lw_ref, 'HandleVisibility', 'off');   % Erro zero = SoC verdadeiro: a mesma faixa verde do gráfico de cima (liga os dois gráficos)
        hold on;                                           % Sobrepõe as próximas curvas
        plot(t_med(idx_plot_med), (Soc_lstm(idx_plot_med) - Soc_ref(idx_plot_med))*100, '-', 'Color', cor_lstm_fig, 'LineWidth', lw_lstm);   % Erro da LSTM (oscila; fica embaixo das outras), sem marcador
        plot(t_med(idx_s), (Soc_cc(i,idx_s) - Soc_ref(idx_s))*100, '--', 'Color', cor_cc, 'LineWidth', lw_cc, 'MarkerIndices', mk(0.25), sty_cc{:});   % Erro da CC (p.p.)
        plot(t_med(idx_s), (Soc_ekf(s1,idx_s) - Soc_ref(idx_s))*100, '-.', 'Color', cor_ekf, 'LineWidth', lw_ekf, 'MarkerIndices', mk(0.6), sty_ekf{:});   % Erro do EKF (Tabela 11), por último (por cima)
        if incluir_Q11_alt_figuras                          % EKF alternativo, se pedido
            plot(t_med(idx_s), (Soc_ekf(s2,idx_s) - Soc_ref(idx_s))*100, ':', 'Color', verde, 'LineWidth', lw_cc);   % Erro do EKF alternativo
        end
        hold off;                                          % Libera o gráfico
        aplicar_estilo_artigo('', 'Tempo (min)', 'Erro do SoC (%)');   % Padrão visual do projeto, sem título
        lim_y = ylim;                                      % Limites automáticos do eixo y
        ylim(lim_y + [-1 1] * 0.08 * diff(lim_y));         % Folga de 8% em cima e embaixo: a linha da CC em -10 não fica escondida na moldura
        set(gca, 'FontSize', 8);                           % Números dos eixos em 8 pt
        set(get(gca, 'XLabel'), 'FontSize', 9);            % Rótulo do eixo x em 9 pt
        set(get(gca, 'YLabel'), 'FontSize', 9);            % Rótulo do eixo y em 9 pt
        xlim([0 max(t_med)]);                              % Do início ao fim do ensaio

        nome_fig = sprintf('soc_%s_%s_r%d_SoC0_%d', perfil, cenario_sensor, semente_rng, round(lista_Soc0_est(i)*100));   % Ex.: soc_fuds_nominal_r1_SoC0_90
        exportgraphics(fig, fullfile(pasta_comp, [nome_fig '.pdf']), 'ContentType', 'vector');   % PDF vetorial (artigo)
        exportgraphics(fig, fullfile(pasta_comp, [nome_fig '.png']), 'Resolution', 300);         % PNG (conferir/mandar)
        if e_artigo                                        % Avisa qual é a figura do artigo
            fprintf('Figura salva: %s  <-- FIGURA DO ARTIGO (SoC e erro no tempo)\n', nome_fig);
        else                                               % Demais (slides)
            fprintf('Figura salva: %s (extra, slides)\n', nome_fig);
        end
    end
end

% --- Figuras de barras: RMSE médio ± desvio padrão (20 sorteios) por perfil e cenário, uma figura por SoC inicial ---
metodos_barras = {'CC', 'EKF (Tabela 11)'};                % Métodos nas barras
cores_barras = [0.85 0.10 0.10; 0 0.30 0.80];                           % Mesmas cores das curvas (CC vermelho, EKF azul)
nomes_barras = {'CC', 'EKF'};                              % Legenda (EKF = Q da Tabela 11)
if incluir_Q11_alt_figuras                                 % EKF alternativo, se pedido
    metodos_barras{end+1} = 'EKF (Q11 alternativo)'; cores_barras(end+1,:) = verde; nomes_barras{end+1} = 'EKF (Q_{11} alternativo)';
end
metodos_barras{end+1} = nome_comite; cores_barras(end+1,:) = cor_lstm; nomes_barras{end+1} = 'LSTM (comitê)';   % LSTM
lista_ini_barras = 1:length(lista_Soc0_pct);               % Uma figura de barras por SoC inicial assumido...
if ~gerar_figuras_extras, lista_ini_barras = []; end       % ...só se as figuras extras (slides) foram pedidas: as barras repetem a tabela do artigo
for i_ini = lista_ini_barras                               % Uma figura por SoC inicial assumido
    n_fig = n_fig + 1;                                     % Conta a figura
    fig = figure('Units', 'centimeters', 'Position', [1+n_fig 1+n_fig 18 6.5]);   % Largura da página IEEE (duas colunas)
    for i_perfil = 1:length(lista_perfis_teste)            % Um gráfico por perfil
        rot_p = sprintf('%s_p%d', lista_perfis_teste{i_perfil}, ordem_planta);   % Rótulo do perfil no .csv
        M = zeros(length(lista_cenarios_sensor), length(metodos_barras));   % RMSE médio: linha = cenário, coluna = método
        S = zeros(size(M));                                % Desvio padrão
        for i_sensor = 1:length(lista_cenarios_sensor)     % Cenário
            for m = 1:length(metodos_barras)               % Método
                Soc0_busca = lista_Soc0_pct(i_ini);        % SoC inicial da figura
                if startsWith(metodos_barras{m}, 'LSTM'), Soc0_busca = NaN; end   % LSTM: sem SoC inicial (mesmo valor nas duas figuras)
                [M(i_sensor,m), S(i_sensor,m)] = valor_resumo(resumo_comp, rot_p, lista_cenarios_sensor{i_sensor}, Soc0_busca, metodos_barras{m}, 'rmse_pct');
            end
        end
        subplot(1, length(lista_perfis_teste), i_perfil);  % Gráfico do perfil
        b = bar(M, 'grouped');                             % Barras agrupadas por cenário
        hold on;                                           % Sobrepõe as barras de erro
        for m = 1:length(metodos_barras)                   % Cor e barra de erro de cada método
            b(m).FaceColor = cores_barras(m,:);            % Cor do método
            b(m).EdgeColor = 'k';                          % Contorno preto (impressão)
            errorbar(b(m).XEndPoints, M(:,m)', min(S(:,m), M(:,m))', S(:,m)', 'LineStyle', 'none', 'Color', 'k', 'LineWidth', 0.6, ...   % Barra de baixo cortada em zero (RMSE não é negativo)
                'CapSize', 3, 'HandleVisibility', 'off');  % ± desvio padrão entre os sorteios
        end
        hold off;                                          % Libera o gráfico
        set(gca, 'XTickLabel', rotulos_cenarios);          % Nomes dos cenários no eixo x
        ylim([0, 1.5 * max(M(:) + S(:))]);                 % Começa em zero e deixa folga em cima para a legenda não cobrir as barras
        aplicar_estilo_artigo(rotulos_perfis{i_perfil}, '', 'RMSE (%)');   % Padrão visual; título = perfil
        set(gca, 'FontSize', 8);                           % Números dos eixos em 8 pt
        set(get(gca, 'YLabel'), 'FontSize', 9);            % Rótulo do eixo y em 9 pt
        set(get(gca, 'Title'), 'FontSize', 9);             % Título do gráfico em 9 pt
        if i_perfil == 1                                   % Legenda só no primeiro gráfico
            lgd = legend(b, nomes_barras, 'Location', 'northwest');   % Legenda dos métodos
            set(lgd, 'FontName', 'Times New Roman', 'FontSize', 7, 'TextColor', 'k', 'Color', 'w', 'EdgeColor', 'k');   % Estilo da legenda
        end
    end
    nome_fig = sprintf('rmse_barras_SoC0_%d', lista_Soc0_pct(i_ini));   % Ex.: rmse_barras_SoC0_90
    exportgraphics(fig, fullfile(pasta_comp, [nome_fig '.pdf']), 'ContentType', 'vector');   % PDF vetorial
    exportgraphics(fig, fullfile(pasta_comp, [nome_fig '.png']), 'Resolution', 300);         % PNG (slides)
    fprintf('Figura salva: %s (extra, slides)\n', nome_fig);   % Confirma
end

% --- Figura dos perfis de corrente de teste (artigo): val100 inteiro e 1 ciclo de cada perfil padrão ---
% Os artigos de comparação mostram a corrente dos perfis de teste (Yang et al., 2019; Chen et al., 2023). Só monta os perfis (sem simular a planta)
parametros_bat;                                            % Cn e eta (o perfil_padrao.m usa para saber quantos ciclos repetir)
n_fig = n_fig + 1;                                         % Conta a figura
fig = figure('Units', 'centimeters', 'Position', [1+n_fig 1+n_fig larg 9]);   % Uma coluna IEEE, um gráfico por perfil, empilhados
passo_1s = round(1 / Ts);                                  % Passos da planta em 1 s (a corrente dos perfis muda no máximo a cada 1 s)
for i_perfil = 1:length(lista_perfis_teste)                % Um gráfico por perfil de teste
    perfil = lista_perfis_teste{i_perfil};                 % Perfil desta volta
    switch perfil                                          % Monta a corrente do perfil (gera I, N e t em minutos)
        case 'val100'                                      % Perfil de validação da referência (Fig. 26a)
            perfil_val100;                                 % Degraus da referência
            t_fim_plot = t(end);                           % Mostra o perfil inteiro (~36 min)
            titulo_p = 'val100 (validação da referência)'; % Título do gráfico
        case {'fuds', 'us06', 'dst'}                       % Ciclos padrão (CALCE, só descarga, pico escalado)
            perfil_padrao;                                 % Ciclo repetido até 5% de SoC (deixa I_ciclo e dt_ciclo do 1º ciclo)
            t_fim_plot = length(I_ciclo) * dt_ciclo / 60;  % Mostra só o 1º ciclo (min); o texto diz que ele se repete até 5%
            titulo_p = sprintf('%s (1 ciclo, só descarga)', upper(perfil));   % Título do gráfico
        otherwise                                          % Perfil sem regra de figura
            error('Perfil "%s" sem regra na figura dos perfis.', perfil);
    end
    idx_p = 1:passo_1s:find(t <= t_fim_plot, 1, 'last');   % Uma amostra por segundo até o fim do trecho (PDF leve, sem perder degraus)
    subplot(length(lista_perfis_teste), 1, i_perfil);      % Gráfico do perfil
    stairs(t(idx_p), I(idx_p), 'k-', 'LineWidth', 0.6);    % Corrente em degraus (descarga positiva); linha fina para os picos do FUDS e do US06 não virarem mancha
    if i_perfil == length(lista_perfis_teste)              % Rótulo do tempo só no último gráfico (economiza altura)
        aplicar_estilo_artigo(titulo_p, 'Tempo (min)', 'I (A)');
    else
        aplicar_estilo_artigo(titulo_p, '', 'I (A)');
    end
    set(gca, 'FontSize', 8);                               % Números dos eixos em 8 pt
    set(get(gca, 'XLabel'), 'FontSize', 9);                % Rótulo do eixo x em 9 pt
    set(get(gca, 'YLabel'), 'FontSize', 9);                % Rótulo do eixo y em 9 pt
    set(get(gca, 'Title'), 'FontSize', 9);                 % Título em 9 pt
    xlim([0 t_fim_plot]);                                  % Do início ao fim do trecho
    ylim([0 1.1*I_pico_padrao]);                           % Mesma escala nos três (pico de 2,8 A = 2C, Tab. 5)
end
nome_fig = 'perfis_corrente_teste';                        % Nome do arquivo
exportgraphics(fig, fullfile(pasta_comp, [nome_fig '.pdf']), 'ContentType', 'vector');   % PDF vetorial (artigo)
exportgraphics(fig, fullfile(pasta_comp, [nome_fig '.png']), 'Resolution', 300);         % PNG (conferir/slides)
fprintf('Figura salva: %s  <-- FIGURA DO ARTIGO (perfis de corrente)\n', nome_fig);
fprintf('\nComparação final concluída. Arquivos em: %s\n', pasta_comp);   % Fim

% =====================================================================
% FUNÇÃO LOCAL (fica no fim do script)
% =====================================================================
function [media, desvio] = valor_resumo(resumo, perfil_busca, cenario_busca, Soc0_busca, metodo_busca, metrica)
% valor_resumo: média e desvio padrão de uma métrica no resumo (groupsummary) para um perfil, cenário, SoC inicial e método
% Soc0_busca = NaN procura as linhas sem SoC inicial assumido (LSTM)
if isnan(Soc0_busca)                                       % LSTM
    linha = strcmp(resumo.perfil, perfil_busca) & strcmp(resumo.cenario_sensor, cenario_busca) & ...
        isnan(resumo.Soc0_est_pct) & strcmp(resumo.metodo, metodo_busca);   % Linha sem SoC inicial
else                                                       % CC e EKF
    linha = strcmp(resumo.perfil, perfil_busca) & strcmp(resumo.cenario_sensor, cenario_busca) & ...
        abs(resumo.Soc0_est_pct - Soc0_busca) < 1e-6 & strcmp(resumo.metodo, metodo_busca);   % Linha com o SoC inicial pedido
end
if nnz(linha) ~= 1                                         % Não achou (ou achou mais de uma)
    media = NaN; desvio = NaN;                             % Devolve NaN (aparece na tabela e chama atenção)
    return;                                                % Sai da função
end
media = resumo.(['mean_' metrica])(linha);                 % Média da métrica
desvio = resumo.(['std_' metrica])(linha);                 % Desvio padrão da métrica
end
