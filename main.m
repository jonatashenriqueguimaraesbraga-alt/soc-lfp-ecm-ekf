clear; clc; close all;   % Limpa variáveis, Command Window e figuras de execuções anteriores

% ===== CONFIGURAÇÃO DOS TESTES (mudar só aqui) =====
lista_Soc0_est = [1, 0.9];   % SoC inicial ASSUMIDO pelos estimadores (CC e EKF). 1ª posição = sem erro inicial (referência); demais = testes de erro inicial (0.9 = Tabela 14)

% ===== DADOS (bateria) =====
simulacao_hppc;   % Gera I_medido, Vt_medido e o SoC verdadeiro (Soc). Com dados reais, trocar por um script que carregue essas mesmas variáveis

% ===== ESTIMADORES =====
cc_bat;           % Contagem de Coulomb, uma por SoC inicial da lista
ekf_bat;          % EKF, uma por combinação (SoC inicial × Q11)

% ===== RESULTADOS =====
resultados_ekf;   % RMSE e gráficos

% ===== SALVAR FIGURAS =====
salvar_figuras;   % Salva todas as figuras em PDF (vetorial) e PNG. Comente esta linha (%) se não quiser salvar
