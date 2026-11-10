% GERAR DADOS DA LSTM - VERSÃO 10 (03/11/2026): perfis padrão de condução + mais perfis aleatórios
% Por quê: (1) o professor pediu testar os métodos em mais perfis de corrente além do HPPC; os ciclos DST, US06 e FUDS são os
%          perfis padrão da literatura de SoC (Chen et al., 2023: DST no treino, US06 e FUDS no teste; Yang et al., 2019);
%          (2) na versão 9, a LSTM tinha só 24 perfis de treino e 4 de validação (a validação ficou instável e houve sobreajuste).
% O que gera (ajustes no configuracao.m, seções 6, 6b e 7d), todos começando na carga completa e indo até 5% de SoC:
%   - 40 perfis aleatórios de TREINO (20 com degraus de 30 a 600 s + 20 com degraus rápidos de 2 a 60 s)
%   - 6 perfis aleatórios de VALIDAÇÃO (3 + 3)
%   - DST (só descarga) para o TREINO
%   - TESTE: FUDS e US06 (só descarga) × 3 cenários de sensor × 20 sorteios = 120 arquivos (os MESMOS sorteios do rodar_cenarios.m)
%     Os 60 arquivos de teste do val100 já existem em 'dados_lstm' e não mudam.
%   Treino e validação no caso nominal de sensor (só ruído de base), como os arquivos antigos.
% Saída: pasta 'resultados ekf\dados_lstm_v10' (SÓ os arquivos novos: é o conteúdo dessa pasta que vai para o Drive, junto com os antigos)
% Demora: ~20-40 min (cada ciclo padrão tem ~3 h de ensaio = ~570 mil passos da planta de 3 ramos). Deixe rodando.

clear; clc; close all;                    % Começa limpo
fonte_dados = 'simulacao';                % Dados simulados nesta fase
configuracao;                             % Carrega todos os ajustes
plotar_dados = false;                     % Sem gráficos (seriam 3 figuras por perfil)
subpasta_csv = 'dados_lstm_v10';          % Pasta separada, só com os arquivos novos (exportar_csv.m)
usar_soc0_aleatorio = false;              % Todos começam na carga completa (protocolo dos artigos)
tic;                                      % Marca o tempo

% --- 1) Perfis aleatórios novos (treino e validação, caso nominal) ---
cenario_sensor = 'nominal';               % Só ruído de base
perfil = 'aleatorio';                     % perfil_aleatorio.m
lista_sementes_v10 = [sementes_v10_treino_lento, sementes_v10_treino_rapido, sementes_v10_val_lento, sementes_v10_val_rapido];   % Todas as sementes
lista_rapido_v10 = ismember(lista_sementes_v10, [sementes_v10_treino_rapido, sementes_v10_val_rapido]);   % true = degraus rápidos
lista_papeis_v10 = repmat({'validacao'}, 1, numel(lista_sementes_v10));   % Começa tudo como validação...
lista_papeis_v10(ismember(lista_sementes_v10, [sementes_v10_treino_lento, sementes_v10_treino_rapido])) = {'treino'};   % ...e marca os de treino
for i_v10 = 1:numel(lista_sementes_v10)   % Um perfil por volta (i_v10: nome que nenhum outro script usa)
    semente_perfil = lista_sementes_v10(i_v10);           % Semente deste perfil
    usar_degraus_rapidos = lista_rapido_v10(i_v10);       % Liga os degraus rápidos no perfil_aleatorio.m
    papel_csv = lista_papeis_v10{i_v10};                  % treino ou validacao (vai no nome do arquivo)
    fprintf('\n=== aleatório %d/%d: %s, semente %d, rápido = %d ===\n', i_v10, numel(lista_sementes_v10), papel_csv, semente_perfil, usar_degraus_rapidos);   % Progresso
    simulacao_dados;                                      % Planta (3 ramos) + sensores
    exportar_csv;                                         % Grava o .csv
end
usar_degraus_rapidos = false;             % Desliga (para não afetar o que rodar depois sem 'clear')

% --- 2) Ciclo padrão do treino (DST, só descarga, caso nominal) ---
papel_csv = 'treino';                     % Papel do arquivo
semente_perfil = 0;                       % Perfis padrão não usam semente
for i_v10 = 1:numel(lista_perfis_padrao_treino)           % Só o DST (configuracao.m, seção 7d)
    perfil = lista_perfis_padrao_treino{i_v10};           % Nome do perfil
    fprintf('\n=== treino: %s ===\n', perfil);           % Progresso
    simulacao_dados;                                      % Planta + sensores (semente 1, como os outros perfis não aleatórios)
    exportar_csv;                                         % Grava o .csv
end

% --- 3) Teste: FUDS e US06 × cenários de sensor × sorteios (o val100 já existe em 'dados_lstm') ---
papel_csv = 'teste';                      % Papel dos arquivos deste bloco
for i_perfil = 1:length(lista_perfis_teste)               % val100, fuds, us06
    perfil = lista_perfis_teste{i_perfil};                % Perfil de teste
    if strcmp(perfil, 'val100'), continue; end            % val100: arquivos de teste já prontos (iguais) na pasta 'dados_lstm'
    for i_sensor = 1:length(lista_cenarios_sensor)        % Nominal + cenários da referência
        cenario_sensor = lista_cenarios_sensor{i_sensor}; % Cenário de sensor
        fprintf('\n=== teste: %s | %s (%d sorteios) ===\n', perfil, cenario_sensor, n_monte_carlo);   % Progresso
        simulacao_dados;                                  % Planta (uma vez) + sensores
        for i_mc = 1:n_monte_carlo                        % Um sorteio de ruído por volta
            semente_rng = i_mc;                           % Sementes 1 a n_monte_carlo (iguais às do rodar_cenarios.m)
            sensores_simulados;                           % Sorteia de novo só os erros de sensor (a planta é a mesma)
            exportar_csv;                                 % Grava o .csv deste sorteio
        end
    end
end

arquivos_v10 = dir(fullfile(pasta_csv, '*.csv'));         % Lista o que foi gerado
fprintf('\n%d arquivos gerados em %.1f min. Pasta: %s\n', numel(arquivos_v10), toc/60, pasta_csv);   % Confirma (esperado: 46 + 1 + 120 = 167)
fprintf('Próximo passo: arrastar TODOS os arquivos dessa pasta para Meu Drive/LSTM_SoC/dados_lstm (junto com os antigos).\n');
