% EKF - rodar pelo main.m
% Roda todas as combinações de:
%   - SoC inicial assumido (lista_Soc0_est, montada no main.m a partir do lista_erro_Soc0 do configuracao.m)
%   - Q(1,1): 1) Tabela 11 da dissertação (resultado principal); 2) alternativo (análise de sensibilidade)
% Cada combinação é um "cenário" e ocupa uma linha nas matrizes de resultado
% Valores de P0, Q e R no configuracao.m (seção 4); o passo do filtro em si está no ekf_passo.m (mesma função que vai para o Simulink)
%
% Convenção de índices (a cada volta do loop, o filtro vai de k para k+1, com k contando as medições a cada Ts_med):
%   Predição: parte de x_est(:,k) com I_medido(k)                 -> estimativa de x(k+1) antes da medição
%   Correção: compara Vt_medido(k+1) com h(x_pred, I_medido(k+1)) -> x_est(:,k+1)

% --- Valores de Q(1,1) testados (definidos no configuracao.m, em fração² por segundo) ---
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
Soc_ekf  = zeros(n_cen, N_med);   % SoC estimado em cada cenário
P11_hist = zeros(n_cen, N_med);   % Histórico de P(1,1): incerteza do SoC a cada passo (diagnóstico)
K1_hist  = zeros(n_cen, N_med);   % Histórico de K(1): ganho de Kalman do SoC a cada passo (diagnóstico)
tempo_ekf = zeros(n_cen, 1);      % Tempo de execução de cada cenário (s)
Vt_ekf = NaN(n_cen, N_med);       % Tensão terminal prevista pelo modelo do EKF antes de cada correção (V); no passo 1 não há previsão (NaN)
R = R_ekf;                        % Covariância do ruído de medição (V²): valor da Tabela 11 (configuracao.m)

for s = 1:n_cen   % Loop dos cenários
    tic;                                         % Dispara o cronômetro
    % --- Inicialização do EKF (reinicia a cada cenário) ---
    x_est = zeros(2, N_med);                     % Pré-aloca os estados estimados [SoC; V1]
    x_est(:,1) = [cen_Soc0(s); V1_0];            % Estado inicial: SoC assumido do cenário (pode diferir do real), V1 inicial
    P = [P0_Soc 0; 0 P0_V1];                     % Covariância inicial (Tabela 11, já convertida no configuracao.m)
    Q = [cen_Q11(s) 0; 0 Q22] * Ts_med;          % Ruído de processo: de "por segundo" para "por passo" (com Ts_med = 1 s, é a própria Tabela 11)
    P11_hist(s,1) = P(1,1);                      % Histórico no passo 1 = P inicial (ainda sem correção)
    K1_hist(s,1)  = 0;                           % Sem correção no passo 1, então sem ganho

    for k = 1:N_med-1   % Loop do EKF: cada volta leva a estimativa de k para k+1
        [x_est(:,k+1), P, K, Vt_ekf(s,k+1)] = ekf_passo(x_est(:,k), P, I_medido(k), I_medido(k+1), Vt_medido(k+1), ...   % 4ª saída: tensão prevista (validação do modelo, como o RMSE-Tensão da referência)
                                         Q, R, bat, Ts_med, discretizacao_est);   % Predição + correção (ekf_passo.m)
        P11_hist(s,k+1) = P(1,1);                % Guarda a incerteza do SoC em k+1
        K1_hist(s,k+1)  = K(1);                  % Guarda o ganho do SoC usado para chegar em k+1
    end

    Soc_ekf(s,:) = x_est(1,:);                   % Guarda o SoC estimado deste cenário (linha s)
    tempo_ekf(s) = toc;                          % Para o cronômetro e guarda o tempo deste cenário
    if imprimir_resultados, fprintf('EKF: cenário %d de %d concluído (%.2f s)\n', s, n_cen, tempo_ekf(s)); end   % Progresso (desligado no rodar_cenarios.m)
end
