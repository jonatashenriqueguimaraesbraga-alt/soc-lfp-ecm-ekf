% SIMULAÇÃO ECM COM PERFIL HPPC
% Carrega parâmetros e perfil de corrente
parametros_bat;                           % Executa script: gera Ts, Cn, eta, R0, R1, C1, OCV, Soc_tab
perfil_hppc;                              % Executa script: gera I, N, t (perfil de corrente HPPC)

% Condições iniciais
Soc0 = 1;                                 % SoC REAL inicial da bateria (100% = bateria cheia). O chute dos estimadores fica em lista_Soc0_est (main.m)
V1_0 = 0;                                 % Tensão inicial no capacitor C1 (zero, repouso)

% Pré-alocar vetores de estado e saída
Soc = zeros(1, N);                        % Pré-aloca vetor SoC (evita aviso de MATLAB, mais rápido)
V1 = zeros(1, N);                         % Pré-aloca vetor V1 (tensão no capacitor)
Vt = zeros(1, N);                         % Pré-aloca vetor Vt (tensão terminal, saída do modelo)

% Condições iniciais nos vetores
Soc(1) = Soc0;                            % Define o primeiro valor de Soc como Soc0
V1(1) = V1_0;                             % Define o primeiro valor de V1 como V1_0

% Loop de simulação ECM (gera a "verdade física" da bateria, usando a corrente LIMPA I)
% Esse loop NÃO muda: ele representa o que a bateria realmente faz, sem erro de sensor nenhum
for k = 1:N-1                             % Loop que roda o modelo passo a passo até N-1
    % Interpolar parâmetros no SoC atual
    Soc_q = min(max(Soc(k), 0), 1);               % SoC limitado a [0,1] SÓ para consultar as tabelas (interp1 dá NaN fora da faixa)
    R0_atual = interp1(Soc_tab, R0, Soc_q);       % Interpola R0 para o SoC atual (k)
    R1_atual = interp1(Soc_tab, R1, Soc_q);       % Interpola R1 para o SoC atual (k)
    C1_atual = interp1(Soc_tab, C1, Soc_q);       % Interpola C1 para o SoC atual (k)
    OCV_atual = interp1(Soc_tab, OCV, Soc_q);     % Interpola OCV para o SoC atual (k)

    % Equações do modelo ECM
    Soc(k+1) = Soc(k) - (Ts*eta/Cn) * I(k);                              % Atualiza SoC (Equação 1)
    V1(k+1)  = (1 - Ts/(R1_atual*C1_atual)) * V1(k) + (Ts/C1_atual) * I(k);  % Atualiza V1 (Equação 2)
    Vt(k)    = OCV_atual - V1(k) - R0_atual*I(k);                        % Calcula Vt no instante k (Equação 3)
end

% Calcular último Vt fora do loop
Soc_qN = min(max(Soc(N), 0), 1);                               % SoC final limitado a [0,1] só para a consulta às tabelas
R0_final = interp1(Soc_tab, R0, Soc_qN);                       % Interpola R0 para o último SoC (N)
Vt(N) = interp1(Soc_tab, OCV, Soc_qN) - V1(N) - R0_final*I(N);  % Calcula o último ponto de Vt (fora do for)

% =====================================================================
% ERRO DE SENSOR NA CORRENTE (bias + ruído gaussiano)
% Escalado como % do pico de corrente (fundo de escala), não como valor
% absoluto fixo - padrão de datasheet de sensor de corrente comercial
% Isso é DIFERENTE do ruído de Vt lá embaixo: aqui é o sensor de
% CORRENTE, que alimenta o CC e também entra no EKF como entrada de
% controle. O ruído de Vt é o sensor de TENSÃO, que só entra no EKF
% como medição de correção.
% =====================================================================
rng(1);                              % Fixa a semente do gerador aleatório UMA VEZ SÓ, aqui no início
                                      % (todo randn deste arquivo, de corrente e de tensão, vem dessa mesma semente)

I_pico = max(abs(I));                % Amplitude de pico da corrente real (referência de escala, ~1C)

% --- Erro tipo 1: BIAS (erro sistemático, constante, não é aleatório) ---
percentual_bias = 0.01;              % 1% do pico - erro sistemático típico de sensor de corrente comercial
I_bias = zeros(1, N);                % Vetor de bias começa zerado (sem erro na 1ª metade)
I_bias(round(N/2):N) = percentual_bias * I_pico;   % Soma bias proporcional na 2ª metade do sinal

% --- Erro tipo 2: RUÍDO GAUSSIANO (erro aleatório, variável a cada instante) ---
percentual_ruido = 0.01;             % 1% do pico - ruído típico de sensor de corrente
sigma_i = percentual_ruido * I_pico; % Desvio padrão do ruído, proporcional ao pico
ruido_corrente = sigma_i * randn(1, N);  % Gera ruído aleatório do tamanho de I, distribuição normal

% --- Corrente "medida": a que qualquer sensor/algoritmo realmente enxerga ---
I_medido = I + I_bias + ruido_corrente;   % Soma os dois erros na corrente real (I limpo continua intacto)

% (A Contagem de Coulomb saiu daqui e foi para o cc_bat.m, junto com os outros estimadores)

% =====================================================================
% ERRO DE SENSOR NA TENSÃO (ruído gaussiano) - entrada de medição do EKF
% =====================================================================
sigma_v = sqrt(8) / 1000;       % Desvio padrão do ruído, convertido de mV para V (Rk=8, Tabela 11)

% Gera ruído gaussiano (média zero, desvio sigma_v), mesmo tamanho de Vt
% (NÃO chama rng(1) de novo aqui - já foi fixado uma vez lá em cima,
% então esse randn continua a MESMA sequência fixa, só numa posição diferente)
ruido = sigma_v * randn(1, N);  % randn: números aleatórios com distribuição normal

% "Medição simulada": Vt real do modelo + ruído do sensor de tensão
Vt_medido = Vt + ruido;         %  entrada de MEDIÇÃO do EKF (corrige a estimativa via resíduo)

% Downsample apenas para plotagem (linhas conectadas: SoC, V1, Vt real, I real)
passo_plot = 100;                          % Plota 1 a cada 100 pontos
idx_plot = 1:passo_plot:N;                 % Índices espaçados para plotagem

% Downsample dos sinais "medidos" (só para os marcadores soltos - pontos vermelhos)
% Calibrado para resolução de impressão IEEE
passo_plot_ruido = 600;                    % N/600
idx_plot_ruido = 1:passo_plot_ruido:N;     % Índices bem mais espaçados

% Gráfico Corrente (comparação real vs medida, mostrando bias + ruído do sensor)
figure;                                                                     % Abre uma nova janela de figura
plot(t(idx_plot), I(idx_plot), 'k-', 'LineWidth', 1.5);                     % Corrente real: preto, linha sólida
hold on;                                                                    % Mantém o gráfico atual pra sobrepor o próximo plot
plot(t(idx_plot_ruido), I_medido(idx_plot_ruido), 'r.', 'MarkerSize', 3);   % Corrente medida: pontos vermelhos (bias + ruído)
hold off;                                                                   % Libera o gráfico
lgd = legend('I (real)', 'I medido (bias + ruído)', 'Location', 'best');    % Cria legenda
set(lgd, 'FontName', 'Times New Roman', 'TextColor', 'k', 'Color', 'w', 'EdgeColor', 'k');  % Corrige cores da legenda
aplicar_estilo_artigo('Comparação: Corrente real vs Corrente medida', 'Tempo (min)', 'Corrente (A)');  % Aplica padrão visual

% Gráfico V1
figure;                                                       % Abre uma nova janela de figura
plot(t(idx_plot), V1(idx_plot), 'k-', 'LineWidth', 1.5);      % V1 x tempo, linha preta sólida
aplicar_estilo_artigo('Tensão no capacitor (V1) durante teste HPPC', 'Tempo (min)', 'V1 (V)');     % Aplica padrão visual

% Gráfico Vt (comparação real vs medido)
figure;                                                       % Abre uma nova janela de figura
plot(t(idx_plot), Vt(idx_plot), 'k-', 'LineWidth', 1.5);              % Vt real: preto, linha sólida
hold on;                                                              % Mantém o gráfico atual pra sobrepor o próximo plot
plot(t(idx_plot_ruido), Vt_medido(idx_plot_ruido), 'r.', 'MarkerSize', 3);  % Vt medido: downsample calculado (600)
hold off;                                                             % Libera o gráfico
lgd = legend('Vt (real)', 'Vt medido (com ruído)', 'Location', 'best');  % Cria legenda
set(lgd, 'FontName', 'Times New Roman', 'TextColor', 'k', 'Color', 'w', 'EdgeColor', 'k');  % Corrige cores da legenda
aplicar_estilo_artigo('Comparação: Vt real vs Vt medido (com ruído)', 'Tempo (min)', 'Tensão terminal (V)');  % Aplica padrão visual
