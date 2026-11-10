% PARÂMETROS DA BATERIA - dissertação (Villarraga Solís, 2025): Tabela 5 (célula), Tabela 6 (capacidade) e Tabela 7 (ECM, 20 °C)
% O passo de simulação saiu daqui e foi para o configuracao.m (é escolha de simulação, não da bateria)
% No fim, tudo é agrupado na struct "bat": é ela que as funções de um passo (ecm_passo, cc_passo, ekf_passo) recebem,
% e é o formato que um bloco MATLAB Function do Simulink aceita como parâmetro

Cn = 1.462 * 3600; % Capacidade medida a 20°C (1,462 Ah, Tabela 6 - não o nominal de fábrica), convertida de Ah para Coulombs (A.s)
eta = 1;  % Eficiência coulombiana (descarga = 1)
Soc_tab = [100, 95, 90, 85, 80, 70, 60, 50, 40, 30, 20, 15, 10, 5, 0] / 100; % Vetor de SoC da Tabela 7 (20°C), tirado da porcentagem
R0 = [0.225, 0.081, 0.086, 0.092, 0.098, 0.090, 0.082, 0.075, 0.084, 0.090, 0.099, 0.104, 0.102, 0.087, 0.013]; % Resistência interna R0 (Ω) para cada SoC da tabela
R1 = [0.083, 0.015, 0.015, 0.036, 0.015, 0.016, 0.017, 0.041, 0.038, 0.019, 0.025, 0.021, 0.038, 0.011, 0.338]; % Resistência de polarização R1 (Ω) para cada SoC da tabela
C1 = [30.23, 15.88, 108.20, 126.60, 158.10, 135.10, 15.09, 20.26, 29.72, 148.20, 100.50, 120.80, 33.16, 153.70, 159.90];  % Capacitância de polarização C1 (F) para cada SoC da tabela
OCV = [3.612, 3.326, 3.327, 3.326, 3.325, 3.313, 3.289, 3.287, 3.286, 3.277, 3.240, 3.212, 3.204, 3.140, 2.814]; % Tensão de circuito aberto (V) para cada SoC da tabela
Soc_tab = fliplr(Soc_tab); % Inverte para ordem crescente (exigência do interp1)
R0 = fliplr(R0); % Inverte R0 na mesma ordem de Soc_tab
R1 = fliplr(R1); % Inverte R1 na mesma ordem de Soc_tab
C1 = fliplr(C1); % Inverte C1 na mesma ordem de Soc_tab
OCV = fliplr(OCV); % Inverte OCV na mesma ordem de Soc_tab
dOCV = gradient(OCV, Soc_tab); % Derivada dOCV/dSoC, usada no H do EKF

% --- Ramos 2 e 3 da Tabela 7 (o modelo identificado pela referência tem 3 ramos RC) ---
% Usados SÓ pela planta de 3ª ordem (ordem_planta = 3). O EKF deste trabalho continua com 1 ramo (resumo estendido)
R2 = fliplr([0.014, 0.026, 0.026, 0.010, 0.017, 0.020, 0.013, 1.6e-7, 0.008, 0.025, 0.009, 0.015, 0.010, 0.051, 0.068]); % R2 (Ω), já em ordem crescente de SoC
R3 = fliplr([0.017, 0.046, 0.052, 0.065, 0.061, 0.055, 0.032, 0.035, 0.043, 0.046, 0.053, 0.060, 0.061, 0.090, 0.089]); % R3 (Ω)
C2 = fliplr([196.10, 160.90, 15.13, 29.73, 19.50, 19.62, 40.81, 122.00, 252.60, 19.98, 25.58, 39.87, 206.80, 26.65, 416.80]); % C2 (F)
C3 = fliplr([493.4, 932.5, 1.0e5, 697.5, 679.7, 2.0e5, 1.2e5, 1.0e5, 886.0, 1.5e5, 1.1e5, 1.2e5, 1.3e5, 165.1, 1.7e5]); % C3 (F)

% --- Limites de operação da célula (Tabela 5) - usados só para checar se os perfis são fisicamente possíveis ---
V_corte_desc = 2.5;            % Tensão de corte de descarga (V)
V_corte_carga = 3.6;           % Tensão de corte de carga (V)
I_max_desc = 2.0 * 1.4;        % Corrente máxima de descarga: 2,0C sobre a capacidade nominal de 1400 mAh = 2,8 A

% --- Struct com tudo o que o modelo precisa (um "pacote" de parâmetros) ---
bat.Cn = Cn;                   % Capacidade (C)
bat.eta = eta;                 % Eficiência coulombiana
bat.Soc_tab = Soc_tab;         % Pontos de SoC das tabelas (crescente)
bat.R0 = R0;                   % R0 (Ω) em cada ponto
bat.R1 = R1;                   % R1 (Ω) em cada ponto
bat.C1 = C1;                   % C1 (F) em cada ponto
bat.OCV = OCV;                 % OCV (V) em cada ponto
bat.dOCV = dOCV;               % dOCV/dSoC (V por fração de SoC) em cada ponto
bat.R2 = R2;                   % R2 (Ω) - só a planta de 3ª ordem usa
bat.R3 = R3;                   % R3 (Ω) - só a planta de 3ª ordem usa
bat.C2 = C2;                   % C2 (F) - só a planta de 3ª ordem usa
bat.C3 = C3;                   % C3 (F) - só a planta de 3ª ordem usa
