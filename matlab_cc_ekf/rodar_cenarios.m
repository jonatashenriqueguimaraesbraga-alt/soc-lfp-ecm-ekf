% RODAR CENÁRIOS - bateria completa de testes da CC e do EKF (base da tabela do trabalho)
% Combinações: perfis de teste × cenários de erro de corrente (configuracao.m, seção 7b), na planta da Tabela 7 completa
% Cada combinação roda n_monte_carlo sorteios de ruído (sementes 1 a n_monte_carlo) e testa o SoC inicial correto e com erro de 10%
% Saídas em 'resultados ekf':
%   metricas_MC_todos.csv  = uma linha por método × SoC inicial × sorteio (todos os números, para conferência e gráficos)
%   metricas_MC_resumo.csv = média e desvio padrão sobre os sorteios (é a tabela que vai para o trabalho)
% A LSTM (Colab) vai ser avaliada nos MESMOS sorteios (arquivos de teste do gerar_dados_lstm.m), com as mesmas colunas

clear; clc; close all;            % Começa limpo
fonte_dados = 'simulacao';        % Bateria de testes com dados simulados
configuracao;                     % Carrega todos os ajustes
plotar_dados = false;             % Sem gráficos dos dados
plotar_resultados = false;        % Sem gráficos de resultado; para ver um caso, use o main.m
imprimir_resultados = false;      % Sem tabela a cada rodada (seriam 160); no fim sai o resumo
salvar_metricas_individuais = false;   % Grava tudo junto no fim
semente_perfil = 0;               % Perfis de teste não usam semente

tabela_mc = table();              % Vai juntando as métricas de todas as rodadas
n_total = length(lista_perfis_teste) * length(lista_cenarios_sensor);   % Número de combinações (versão 10: 3 perfis × 3 cenários = 9)
n_feito = 0;                                                      % Contador de progresso
for i_perfil = 1:length(lista_perfis_teste)                       % Perfil de teste
    for i_sensor = 1:length(lista_cenarios_sensor)                % Cenário de erro de corrente
        perfil = lista_perfis_teste{i_perfil};                    % Perfil desta combinação
        cenario_sensor = lista_cenarios_sensor{i_sensor};         % Erros de sensor desta combinação
        n_feito = n_feito + 1;                                    % Atualiza o contador
        fprintf('\n##### %d/%d: %s | %s | %d sorteios #####\n', n_feito, n_total, perfil, cenario_sensor, n_monte_carlo);   % Progresso
        simulacao_dados;                                          % Planta (uma vez por combinação: ela não tem nada aleatório)
        lista_Soc0_est = Soc0 + lista_erro_Soc0;                  % SoC inicial assumido (correto e com erro de 10%)
        for i_mc = 1:n_monte_carlo                                % Um sorteio de ruído por volta
            semente_rng = i_mc;                                   % Sementes 1 a n_monte_carlo (a semente 1 é a mesma do main.m)
            sensores_simulados;                                   % Sorteia de novo só os erros de sensor
            cc_bat;                                               % Contagem de Coulomb
            ekf_bat;                                              % EKF (Q11 da Tabela 11 e alternativo)
            resultados_ekf;                                       % Monta tabela_rmse desta rodada
            tabela_rmse.semente = repmat(semente_rng, height(tabela_rmse), 1);   % Anota o sorteio em cada linha
            tabela_mc = [tabela_mc; tabela_rmse];                 % Junta com as rodadas anteriores
        end
        fprintf('concluído\n');                                   % Fim da combinação
    end
end

% --- Resumo: média e desvio padrão sobre os sorteios ---
tabela_mc.convergiu = ~isnan(tabela_mc.t_conv_min);               % 1 = terminou dentro de ±2 p.p.; 0 = não convergiu
resumo_mc = groupsummary(tabela_mc, {'perfil', 'cenario_sensor', 'Soc0_est_pct', 'metodo'}, {'mean', 'std'}, ...
    {'rmse_pct', 'mae_pct', 'erro_max_pct', 'tempo_exec_s', 'convergiu', 'frac_dentro_3sigma'});   % Agrupa por combinação e calcula média e desvio
marca_tempo = datestr(now, 'yyyymmdd_HHMM');                    % Data e hora, para a cópia de segurança
for nome_arq = {'metricas_MC_todos.csv', 'metricas_MC_resumo.csv'}   % As duas tabelas
    arq_antigo = fullfile(pasta_res, nome_arq{1});                % Caminho do arquivo da rodada anterior
    if exist(arq_antigo, 'file')                                  % Se já existe (ex.: a bateria com o val60, de 31/10)...
        copyfile(arq_antigo, strrep(arq_antigo, '.csv', ['_antes_' marca_tempo '.csv']));   % ...guarda uma cópia antes de sobrescrever
    end
end
writetable(tabela_mc, fullfile(pasta_res, 'metricas_MC_todos.csv'));     % Todos os números
writetable(resumo_mc, fullfile(pasta_res, 'metricas_MC_resumo.csv'));    % Tabela do trabalho

% --- Resumo no Command Window (RMSE: média ± desvio padrão; fração de sorteios que convergiram) ---
fprintf('\n%-8s %-18s %6s %-24s %16s %8s %8s\n', 'Perfil', 'Sensor', 'SoC0', 'Método', 'RMSE (%)', 'Conv.', 'em ±3σ');
for j = 1:height(resumo_mc)                                       % Uma linha por combinação × método × SoC inicial
    fprintf('%-8s %-18s %6.0f %-24s %7.3f ± %6.3f %8.2f %8.2f\n', resumo_mc.perfil{j}, resumo_mc.cenario_sensor{j}, ...
        resumo_mc.Soc0_est_pct(j), resumo_mc.metodo{j}, resumo_mc.mean_rmse_pct(j), resumo_mc.std_rmse_pct(j), resumo_mc.mean_convergiu(j), ...
        resumo_mc.mean_frac_dentro_3sigma(j));
end
fprintf('\nBateria de testes concluída: %d combinações × %d sorteios. Arquivos em %s\n', n_total, n_monte_carlo, pasta_res);   % Confirma
