% EKF - rodar pelo main.m
% Roda todas as combinações de:
%   - SoC inicial assumido (lista_Soc0_est, definida no main.m)
%   - Q(1,1): 1) Tabela 11 da dissertação (resultado principal); 2) alternativo (análise de sensibilidade)
% Cada combinação é um "cenário" e ocupa uma linha nas matrizes de resultado
%
% Convenção de índices (a cada volta do loop, o filtro vai de k para k+1):
%   Predição: parte de x_est(:,k) com I_medido(k)                 -> x_pred = estimativa de x(k+1) antes da medição
%   Correção: compara Vt_medido(k+1) com h(x_pred, I_medido(k+1)) -> x_est(:,k+1)
%   (mesma convenção da simulação: Vt(k) = OCV(Soc(k)) - V1(k) - R0*I(k))

% --- Valores de Q(1,1), em fração² por segundo (depois multiplicados por Ts) ---
Q11_tab = 9.99e-10/100^2;         % Tabela 11 (dissertação, 20°C), convertido de %² para fração²
Q11_alt = 1e-10;                  % Alternativo: varredura de 1e-12 a 1e-6 com o critério da Eq. 3.15 da dissertação (0,2·RMSE_V + 0,8·RMSE_SoC)
lista_Q11 = [Q11_tab, Q11_alt];   % Vetor com os valores de Q(1,1)
nomes_Q11 = {'Tabela 11', 'Q11 alternativo'};   % Rótulos, na mesma ordem de lista_Q11 (usados nos resultados)
n_q = length(lista_Q11);          % Número de valores de Q(1,1) (2)
n_ini = length(lista_Soc0_est);   % Número de condições iniciais (vem do main.m)

% --- Tabela de cenários: todas as combinações (SoC inicial × Q11) ---
% Ordem: para cada SoC inicial, todos os Q11. Com [1 0.9] e [tab alt]:
%   cenário 1 = (1, tab) | 2 = (1, alt) | 3 = (0.9, tab) | 4 = (0.9, alt)
cen_Soc0 = repelem(lista_Soc0_est, n_q);   % SoC inicial de cada cenário: [1 1 0.9 0.9]
cen_Q11  = repmat(lista_Q11, 1, n_ini);    % Q(1,1) de cada cenário: [tab alt tab alt]
n_cen = length(cen_Q11);                   % Número total de cenários (4)

% --- Pré-alocação dos resultados (uma linha por cenário) ---
Soc_ekf  = zeros(n_cen, N);       % SoC estimado em cada cenário
P11_hist = zeros(n_cen, N);       % Histórico de P(1,1): incerteza do SoC a cada passo (diagnóstico)
K1_hist  = zeros(n_cen, N);       % Histórico de K(1): ganho de Kalman do SoC a cada passo (diagnóstico)
R = sigma_v^2;                    % Covariância do ruído de medição (V²), mesmo sigma_v usado pra gerar Vt_medido

for s = 1:n_cen   % Loop dos cenários
    % --- Inicialização do EKF (reinicia a cada cenário) ---
    x_est = zeros(2, N);                         % Pré-aloca os estados estimados [SoC; V1]
    x_est(:,1) = [cen_Soc0(s); 0];               % Estado inicial: SoC assumido do cenário (pode diferir do real), V1 = 0 V
    P = [0.95/100^2 0; 0 8/1000^2];              % Covariância inicial (Tabela 11), convertida: SoC %→fração (÷100²), V1 mV→V (÷1000²)
    Q = [cen_Q11(s) 0; 0 10/1000^2] * Ts;        % Ruído de processo do cenário s, convertido para passo de Ts
    P11_hist(s,1) = P(1,1);                      % Histórico no passo 1 = P inicial (ainda sem correção)
    K1_hist(s,1)  = 0;                           % Sem correção no passo 1, então sem ganho

    for k = 1:N-1   % Loop do EKF: cada volta leva a estimativa de k para k+1
        % --- Parâmetros da PREDIÇÃO: consultados no estado atual x_est(:,k) ---
        Soc_q = min(max(x_est(1,k), 0), 1);                 % SoC estimado atual limitado a [0,1] SÓ para consultar as tabelas (evita NaN)
        R1_atual = interp1(Soc_tab, R1, Soc_q);             % R1 interpolado no SoC atual
        C1_atual = interp1(Soc_tab, C1, Soc_q);             % C1 interpolado no SoC atual
        A = [1 0; 0 (1 - Ts/(R1_atual*C1_atual))];          % Jacobiano do modelo, linearizado no ponto x_est(:,k)

        % --- Etapa de Predição (de k para k+1) ---
        % Usa I_medido(k) (corrente COM erro de sensor) - o filtro nunca tem acesso à corrente real I
        x_pred(1,1) = x_est(1,k) - (Ts*eta/Cn) * I_medido(k);                                   % Predição de SoC em k+1
        x_pred(2,1) = (1 - Ts/(R1_atual*C1_atual)) * x_est(2,k) + (Ts/C1_atual) * I_medido(k); % Predição de V1 em k+1
        P_pred = A*P*A' + Q;                                % Propaga a covariância do erro através do modelo linearizado

        % --- Parâmetros da MEDIÇÃO: consultados no estado PREVISTO x_pred (instante k+1) ---
        Soc_q_pred = min(max(x_pred(1), 0), 1);             % SoC previsto limitado a [0,1] SÓ para consultar as tabelas
        OCV_pred  = interp1(Soc_tab, OCV, Soc_q_pred);      % OCV no SoC previsto
        R0_pred   = interp1(Soc_tab, R0, Soc_q_pred);       % R0 no SoC previsto
        dOCV_pred = interp1(Soc_tab, dOCV, Soc_q_pred);     % dOCV/dSoC no SoC previsto (mesmo ponto onde h é avaliada)
        H = [dOCV_pred, -1];                                % Jacobiano da medição: dVt/d[Soc, V1], linearizado em x_pred

        % --- Etapa de Correção (com a medição de k+1) ---
        K = P_pred*H' / (H*P_pred*H' + R);                  % Ganho de Kalman: quanto confiar na medição vs. na predição
        Vt_pred = OCV_pred - x_pred(2,1) - R0_pred*I_medido(k+1);   % Tensão prevista em k+1 (estado previsto + corrente de k+1)
        residuo = Vt_medido(k+1) - Vt_pred;                 % Diferença entre a medição de k+1 e a previsão de k+1
        x_est(:,k+1) = x_pred + K*residuo;                  % Ajusta a predição usando o Kalman Gain e o resíduo
        P = (eye(2) - K*H)*P_pred;                          % Atualiza a covariância do erro para o próximo passo
        P11_hist(s,k+1) = P(1,1);                           % Guarda a incerteza do SoC em k+1 (alinhada com x_est(:,k+1))
        K1_hist(s,k+1)  = K(1);                             % Guarda o ganho do SoC usado para chegar em k+1
    end

    Soc_ekf(s,:) = x_est(1,:);                              % Guarda o SoC estimado deste cenário (linha s)
    fprintf('EKF: cenário %d de %d concluído\n', s, n_cen); % Mostra o progresso (o loop é demorado)
end
