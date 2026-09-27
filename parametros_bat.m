Ts = 0.02; % Passo de amostragem da simulação (s)
Cn = 1.462 * 3600; % Capacidade medida a 20°C (1,462 Ah, Tabela 6 - não o nominal de fábrica), convertida de Ah para Coulombs (A.s)
eta = 1;  % Eficiência coulombiana (descarga = 1)
Soc_tab = [100, 95, 90, 85, 80, 70, 60, 50, 40, 30, 20, 15, 10, 5, 0] / 100; % Vetor de SoC da Tabela 7 (20°C), tirado da porcentagem
R0 = [0.225, 0.081, 0.086, 0.092, 0.098, 0.090, 0.082, 0.075, 0.084, 0.090, 0.099, 0.104, 0.102, 0.087, 0.013]; % Resistência interna R0 (Ω) para cada SoC da tabela
R1 = [0.083, 0.015, 0.015, 0.036, 0.015, 0.016, 0.017, 0.041, 0.038, 0.019, 0.025, 0.021, 0.038, 0.011, 0.338]; % Resistência de polarização R1 (Ω) para cada SoC da tabela
C1 = [30.23, 15.88, 108.20, 126.60, 158.10, 135.10, 15.09, 20.26, 29.72, 148.20, 100.50, 120.80, 33.16, 153.70, 159.90]; % Capacitância de polarização C1 (F) para cada SoC da tabela
OCV = [3.612, 3.326, 3.327, 3.326, 3.325, 3.313, 3.289, 3.287, 3.286, 3.277, 3.240, 3.212, 3.204, 3.140, 2.814]; % Tensão de circuito aberto (V) para cada SoC da tabela
Soc_tab = fliplr(Soc_tab); % Inverte para ordem crescente (exigência do interp1)
R0 = fliplr(R0); % Inverte R0 na mesma ordem de Soc_tab
R1 = fliplr(R1); % Inverte R1 na mesma ordem de Soc_tab
C1 = fliplr(C1); % Inverte C1 na mesma ordem de Soc_tab
OCV = fliplr(OCV); % Inverte OCV na mesma ordem de Soc_tab
dOCV = gradient(OCV, Soc_tab); % Derivada dOCV/dSoC, usada no H do EKF (Bug 2)
