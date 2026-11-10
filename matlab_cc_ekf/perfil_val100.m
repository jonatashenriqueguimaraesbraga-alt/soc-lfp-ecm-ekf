% PERFIL DE VALIDAÇÃO "SoC INICIAL 100%" - dissertação (Villarraga Solís, 2025), Fig. 26a (p. 75) e Fig. 35 (p. 94)
% Correntes do texto (p. 93): 1,5; 0,8; 1,8; 0,9 e 1,7 A, a 20 °C, partindo de 100% de SoC
% Durações NÃO estão escritas na dissertação: foram lidas por digitalização da Fig. 26a (incerteza de ~±5 s)
% Resultado da referência neste perfil: RMSE-SoC 0,809% sem erro inicial e 2,439% com erro inicial de 10% (Tabs. 12 e 14)
% Usado como perfil de TESTE (nunca entra no treino da LSTM)

Soc0 = 1;                                                     % SoC REAL inicial da bateria (100%)
nome_perfil = 'Validação SoC_0 = 100%';                       % Nome usado nos títulos dos gráficos
correntes_degraus = [0,   1.5, 0,   0.8, 0,  1.8, 0.9, 1.7, 0  ];   % Corrente de cada degrau (A); 0 = repouso
duracoes_degraus  = [310, 285, 205, 100, 80, 225, 255, 365, 310];   % Duração de cada degrau (s) - total ≈ 36 min
perfil_degraus;                                               % Monta I, N e t a partir dos degraus
