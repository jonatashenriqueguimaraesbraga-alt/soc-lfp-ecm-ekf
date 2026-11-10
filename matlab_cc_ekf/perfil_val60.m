% PERFIL DE VALIDAÇÃO "SoC INICIAL 60%" - dissertação (Villarraga Solís, 2025), Fig. 26b (p. 75) e Fig. 36 (p. 95)
% Correntes do texto (p. 94): 1; 1,8; 0,6; 2; 0,8 e 1,2 A, a 20 °C, partindo de 60% de SoC
% Durações NÃO estão escritas na dissertação: foram lidas por digitalização da Fig. 26b (incerteza de ~±5 s)
% Resultado da referência neste perfil: RMSE-SoC 0,368% sem erro inicial e 7,391% com erro inicial de 10% (Tabs. 12 e 15)
% Usado como perfil de TESTE (nunca entra no treino da LSTM)

Soc0 = 0.6;                                                   % SoC REAL inicial da bateria (60%)
nome_perfil = 'Validação SoC_0 = 60%';                        % Nome usado nos títulos dos gráficos
correntes_degraus = [1.0, 1.8, 0.6, 2.0, 0,   0.8, 1.2, 0  ];      % Corrente de cada degrau (A); 0 = repouso
duracoes_degraus  = [120, 70,  315, 180, 215, 235, 65,  195];      % Duração de cada degrau (s) - total ≈ 23 min
perfil_degraus;                                               % Monta I, N e t a partir dos degraus
