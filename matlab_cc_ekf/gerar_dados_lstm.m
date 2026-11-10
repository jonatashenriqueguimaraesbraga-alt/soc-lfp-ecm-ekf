% GERAR DADOS DA LSTM - simula todos os perfis da lista e grava um .csv para cada um
% Lista de perfis, sementes e papéis (treino / validacao / teste): seção 7 do configuracao.m
% Saída: pasta 'resultados ekf\dados_lstm' (é essa pasta que vai para o Google Drive/Colab)
% Treino e validação: caso nominal (só ruído de base). Teste: os dois perfis da referência em TODOS os cenários de sensor (robustez, como as Tabs. 14 e 15),
% cada um com n_monte_carlo sorteios de ruído (os MESMOS sorteios do rodar_cenarios.m: a LSTM é avaliada exatamente nas medições da CC e do EKF)
% Demora: a planta de 3 ramos no HPPC tem 2,7 milhões de passos. Deixe rodando

clear; clc; close all;            % Começa limpo
fonte_dados = 'simulacao';        % Os dados da LSTM nesta fase são todos simulados
configuracao;                     % Carrega todos os ajustes (passos, sensores, perfil aleatório, lista de perfis)
plotar_dados = false;             % Sem gráficos aqui (seriam 3 figuras por perfil)

% --- Treino e validação (caso nominal) ---
cenario_sensor = 'nominal';                                 % Sensores do caso nominal (só ruído de base)
for i_perfil = 1:length(lista_perfis_lstm)                  % Um perfil por vez (i_perfil: nome que nenhum outro script usa)
    if strcmp(lista_papeis_lstm{i_perfil}, 'teste'), continue; end   % Os de teste saem no bloco de baixo, em todos os cenários
    perfil = lista_perfis_lstm{i_perfil};                   % Nome do perfil desta volta
    semente_perfil = lista_sementes_lstm(i_perfil);         % Semente (só o 'aleatorio' usa)
    papel_csv = lista_papeis_lstm{i_perfil};                % treino ou validacao (vai no nome do arquivo)
    fprintf('\n=== %s: %s ===\n', papel_csv, perfil);      % Progresso
    simulacao_dados;                                        % Simula a bateria e os sensores neste perfil
    exportar_csv;                                           % Grava o .csv deste perfil
end

% --- Teste: perfis da referência × cenários de sensor ---
papel_csv = 'teste';                                        % Papel dos arquivos deste bloco
semente_perfil = 0;                                         % Perfis de teste não usam semente
for i_perfil = 1:length(lista_perfis_teste)                 % val100 e val60
    for i_sensor = 1:length(lista_cenarios_sensor)          % Nominal + cenários da referência
        perfil = lista_perfis_teste{i_perfil};              % Perfil de teste
        cenario_sensor = lista_cenarios_sensor{i_sensor};   % Cenário de sensor
        fprintf('\n=== teste: %s | %s (%d sorteios) ===\n', perfil, cenario_sensor, n_monte_carlo);   % Progresso
        simulacao_dados;                                    % Planta (uma vez) + sensores
        for i_mc = 1:n_monte_carlo                          % Um sorteio de ruído por volta
            semente_rng = i_mc;                             % Sementes 1 a n_monte_carlo (iguais às do rodar_cenarios.m)
            sensores_simulados;                             % Sorteia de novo só os erros de sensor (a planta é a mesma)
            exportar_csv;                                   % Grava o .csv deste sorteio
        end
    end
end
fprintf('\nDados da LSTM prontos em: %s\n', pasta_csv);   % Confirma no Command Window
