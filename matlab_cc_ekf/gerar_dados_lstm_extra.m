% GERAR DADOS EXTRA DA LSTM - mais perfis aleatórios de treino e validação (02/11/2026)
% Por quê: com só 3 perfis aleatórios de treino, a LSTM decorou os perfis (RMSE de treino ~6%, validação 13-19%).
%          Com dezenas de perfis diferentes, a única regra que serve para todos é contar a carga e corrigir com a tensão.
% O que gera (ajustes no configuracao.m, seção 7c):
%   - 40 perfis de TREINO: 20 começando em 100% e 20 começando num SoC sorteado (entre 20% e 100%, bateria em repouso)
%   - 6 perfis de VALIDAÇÃO: 3 começando em 100% e 3 num SoC sorteado
%   Todos no caso nominal de sensor (só ruído de base), como os arquivos antigos de treino e validação.
% Saída: pasta 'resultados ekf\dados_lstm_extra' (SÓ os arquivos novos: é o conteúdo dessa pasta que vai para o Drive)
% Não muda nenhum arquivo antigo nem os 120 arquivos de teste.
% Demora: alguns minutos (cada perfil tem ~1 h de ensaio = ~200 mil passos da planta de 3 ramos). Deixe rodando.

clear; clc; close all;                    % Começa limpo
fonte_dados = 'simulacao';                % Dados simulados nesta fase
configuracao;                             % Carrega todos os ajustes (inclusive a seção 7c)
plotar_dados = false;                     % Sem gráficos (seriam 3 figuras por perfil)
cenario_sensor = 'nominal';               % Treino e validação: caso nominal (só ruído de base), igual aos arquivos antigos
perfil = 'aleatorio';                     % Todos os perfis extra são aleatórios (perfil_aleatorio.m)
subpasta_csv = 'dados_lstm_extra';        % Pasta separada, só com os arquivos novos (exportar_csv.m)

lista_sementes_extra = [sementes_extra_treino_100, sementes_extra_treino_soc, sementes_extra_val_100, sementes_extra_val_soc];   % Todas as sementes, em ordem
n_treino_extra = numel(sementes_extra_treino_100) + numel(sementes_extra_treino_soc);   % Quantos são de treino
lista_papeis_extra = [repmat({'treino'}, 1, n_treino_extra), ...
                      repmat({'validacao'}, 1, numel(lista_sementes_extra) - n_treino_extra)];   % Papel de cada perfil (vai no nome do arquivo)
lista_soc_sorteado = ismember(lista_sementes_extra, [sementes_extra_treino_soc, sementes_extra_val_soc]);   % true = começa num SoC sorteado
n_extra = numel(lista_sementes_extra);    % Número total de perfis extra
resumo_extra = zeros(n_extra, 3);         % Uma linha por perfil: semente, SoC inicial (%) e duração (min)

tic;                                      % Marca o tempo
for i_extra = 1:n_extra                   % Um perfil por volta (i_extra: nome que nenhum outro script usa)
    semente_perfil = lista_sementes_extra(i_extra);         % Semente deste perfil (define os degraus e o SoC inicial)
    papel_csv = lista_papeis_extra{i_extra};                % treino ou validacao (vai no nome do arquivo)
    usar_soc0_aleatorio = lista_soc_sorteado(i_extra);      % Liga o sorteio do SoC inicial no perfil_aleatorio.m
    fprintf('\n=== %d/%d: %s, semente %d ===\n', i_extra, n_extra, papel_csv, semente_perfil);   % Progresso
    simulacao_dados;                                        % Planta (3 ramos) + sensores neste perfil
    exportar_csv;                                           % Grava o .csv (dados_lstm_<papel>_aleatorio_s<semente>_p3_nominal_r<...>_1s.csv)
    resumo_extra(i_extra, :) = [semente_perfil, 100*Soc0, t_med(end)];   % Guarda o resumo (t_med em minutos)
end
usar_soc0_aleatorio = false;              % Desliga o sorteio (para não afetar o que rodar depois sem 'clear')

% --- Resumo no Command Window ---
fprintf('\n%-10s %-8s %10s %10s\n', 'Papel', 'Semente', 'SoC0 (%)', 'Dur. (min)');   % Cabeçalho
for i_extra = 1:n_extra                   % Uma linha por perfil
    fprintf('%-10s %-8d %10.1f %10.1f\n', lista_papeis_extra{i_extra}, resumo_extra(i_extra, 1), resumo_extra(i_extra, 2), resumo_extra(i_extra, 3));
end
fprintf('\n%d perfis extra gerados em %.1f min. Arquivos em: %s\n', n_extra, toc/60, pasta_csv);   % Confirma
fprintf('Próximo passo: arrastar TODOS os arquivos dessa pasta para Meu Drive/LSTM_SoC/dados_lstm (junto com os antigos).\n');
