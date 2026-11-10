function [Soc_prox, V_prox, Vt_atual] = ecm3_passo(Soc_k, V_k, I_k, bat, Ts, discretizacao)
% ecm3_passo: UM passo do modelo de circuito equivalente de 3ª ordem (Tabela 7 completa, modelo identificado pela referência)
% Usado SÓ como planta (a "bateria verdadeira") quando ordem_planta = 3. O EKF continua com 1 ramo (ecm_passo/ekf_passo)
%   SoC(k+1)  = SoC(k) - (Ts·eta/Cn)·I(k)
%   Vj(k+1)   = a_j·Vj(k) + b_j·I(k),  j = 1, 2, 3   (um ramo RC por linha de V_k)
%   Vt(k)     = OCV(SoC(k)) - V1(k) - V2(k) - V3(k) - R0(SoC(k))·I(k)
% Entradas: Soc_k, V_k (3x1: [V1; V2; V3]), I_k (A), bat (com R2, R3, C2, C3), Ts (s), discretizacao (precisa ser 'exata':
%           o ramo 2 em 50% de SoC tem constante de tempo de ~2e-5 s, e Euler explodiria)
% Simulink: bloco MATLAB Function; Soc e V voltam pela entrada através de Unit Delay

Soc_q = min(max(Soc_k, 0), 1);                          % SoC limitado a [0,1] SÓ para consultar as tabelas
R0_atual = interp1(bat.Soc_tab, bat.R0, Soc_q);         % R0 no SoC atual
OCV_atual = interp1(bat.Soc_tab, bat.OCV, Soc_q);       % OCV no SoC atual
R_ramos = [interp1(bat.Soc_tab, bat.R1, Soc_q); interp1(bat.Soc_tab, bat.R2, Soc_q); interp1(bat.Soc_tab, bat.R3, Soc_q)];   % R1, R2, R3 no SoC atual (coluna)
C_ramos = [interp1(bat.Soc_tab, bat.C1, Soc_q); interp1(bat.Soc_tab, bat.C2, Soc_q); interp1(bat.Soc_tab, bat.C3, Soc_q)];   % C1, C2, C3 no SoC atual (coluna)

V_prox = zeros(3, 1);                                   % Pré-aloca o próximo estado dos três ramos
for j = 1:3                                             % Um ramo RC por vez (mesma equação, parâmetros diferentes)
    [a_rc, b_rc] = coef_rc(R_ramos(j), C_ramos(j), Ts, discretizacao);   % Coeficientes do ramo j
    V_prox(j) = a_rc * V_k(j) + b_rc * I_k;             % Equação 2 aplicada ao ramo j
end
Soc_prox = Soc_k - (Ts*bat.eta/bat.Cn) * I_k;           % Equação 1
Vt_atual = OCV_atual - sum(V_k) - R0_atual * I_k;       % Equação 3 com as três quedas RC somadas
end
