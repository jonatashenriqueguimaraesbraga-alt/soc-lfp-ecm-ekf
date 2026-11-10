clear; clc; close all;   % Limpa variáveis, Command Window e figuras de execuções anteriores

% ===== ESCOLHA DOS DADOS (mudar só aqui) =====
fonte_dados = 'simulacao';   % 'simulacao' (ECM + sensores simulados) ou 'real' (ensaio do laboratório, fase do artigo)
perfil = 'val60';           % Só na simulação: 'hppc' (AP), 'val100' e 'val60' (validação da dissertação = teste) ou 'aleatorio' (treino da LSTM)
semente_perfil = 11;         % Só vale para 'aleatorio': cada semente gera um perfil diferente

% ===== CONFIGURAÇÃO GERAL =====
configuracao;                % Todos os outros ajustes: modo (AF/AP), passos, sensores, erro de modelo, erro inicial, P0/Q/R (configuracao.m)

% ===== DADOS (bateria) =====
if strcmp(fonte_dados, 'real')            % Ensaio de laboratório
    carregar_dados_reais;                 % Entrega t_med, I_medido, Vt_medido e Soc_ref no mesmo formato da simulação
else                                      % Simulação
    simulacao_dados;                      % Planta + sensores no perfil escolhido
end
lista_Soc0_est = Soc0 + lista_erro_Soc0;  % SoC inicial ASSUMIDO pelos estimadores: real + erro (ex.: 1 + [0 -0.1] = [1 0.9]; 0.6 + [0 -0.1] = [0.6 0.5])

% ===== ESTIMADORES =====
cc_bat;                  % Contagem de Coulomb, uma por SoC inicial da lista
ekf_bat;                 % EKF, uma por combinação (SoC inicial × Q11)

% ===== RESULTADOS =====
resultados_ekf;          % Métricas (tela + arquivo metricas_<modo>_<perfil>.csv) e gráficos

% ===== SALVAR FIGURAS =====
salvar_figuras;          % Salva todas as figuras em PDF (vetorial) e PNG. Comente esta linha (%) se não quiser salvar
% figuras_artigo;        % Figuras do artigo da AP: só com modo_config = 'AP' e perfil = 'hppc'
