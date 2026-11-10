function [x_novo, P_novo, K, Vt_pred] = ekf_passo(x_k, P_k, I_k, I_k1, Vt_k1, Q, R, bat, Ts, discretizacao)
% ekf_passo: UM passo do EKF (predição de k para k+1 e correção com a medição de k+1)
% Estado x = [SoC; V1]. Mesmas equações do ecm_passo, porque o filtro conhece o modelo da bateria
% Entradas: x_k (2x1), P_k (2x2), I_k e I_k1 (corrente medida em k e k+1), Vt_k1 (tensão medida em k+1),
%           Q (2x2, já por passo), R (V²), bat (parametros_bat.m), Ts (s), discretizacao ('exata' ou 'euler')
% Saídas: x_novo = estimativa em k+1, P_novo = covariância em k+1, K = ganho de Kalman (2x1), Vt_pred = tensão prevista em k+1
% Simulink: bloco MATLAB Function; x e P voltam pela entrada através de Unit Delay (ou ficam como variáveis persistent)

% --- Parâmetros da PREDIÇÃO: consultados no estado atual x_k ---
Soc_q = min(max(x_k(1), 0), 1);                         % SoC estimado atual limitado a [0,1] SÓ para consultar as tabelas
R1_atual = interp1(bat.Soc_tab, bat.R1, Soc_q);         % R1 no SoC atual
C1_atual = interp1(bat.Soc_tab, bat.C1, Soc_q);         % C1 no SoC atual
[a_rc, b_rc] = coef_rc(R1_atual, C1_atual, Ts, discretizacao);   % Mesmos coeficientes do modelo da bateria
A = [1 0; 0 a_rc];                                      % Jacobiano do modelo: dx(k+1)/dx(k)

% --- Predição (de k para k+1): usa a corrente MEDIDA, o filtro nunca vê a corrente real ---
x_pred = [x_k(1) - (Ts*bat.eta/bat.Cn) * I_k; ...       % SoC previsto (Equação 1 = a própria CC)
          a_rc * x_k(2) + b_rc * I_k];                  % V1 previsto (Equação 2)
P_pred = A*P_k*A' + Q;                                  % A incerteza cresce: propaga pelo modelo e soma o erro do modelo (Q)

% --- Parâmetros da MEDIÇÃO: consultados no estado PREVISTO (instante k+1) ---
Soc_q_pred = min(max(x_pred(1), 0), 1);                 % SoC previsto limitado a [0,1] SÓ para consultar as tabelas
OCV_pred  = interp1(bat.Soc_tab, bat.OCV, Soc_q_pred);  % OCV no SoC previsto
R0_pred   = interp1(bat.Soc_tab, bat.R0, Soc_q_pred);   % R0 no SoC previsto
dOCV_pred = interp1(bat.Soc_tab, bat.dOCV, Soc_q_pred); % Inclinação da OCV no SoC previsto
H = [dOCV_pred, -1];                                    % Jacobiano da medição: quanto Vt muda se SoC ou V1 mudam

% --- Correção (com a medição de k+1) ---
K = P_pred*H' / (H*P_pred*H' + R);                      % Ganho: confiança na medição vs. na predição
Vt_pred = OCV_pred - x_pred(2) - R0_pred * I_k1;        % Tensão que o modelo espera medir em k+1 (Equação 3)
residuo = Vt_k1 - Vt_pred;                              % Surpresa: o que foi medido menos o que era esperado
x_novo = x_pred + K * residuo;                          % Corrige o estado na direção que explica a surpresa
P_novo = (eye(2) - K*H) * P_pred;                       % A incerteza diminui depois de usar a medição
end
