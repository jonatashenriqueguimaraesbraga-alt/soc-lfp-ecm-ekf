function [Soc_prox, V1_prox, Vt_atual] = ecm_passo(Soc_k, V1_k, I_k, bat, Ts, discretizacao)
% ecm_passo: UM passo do modelo de circuito equivalente de 1ª ordem (a "bateria")
% Equações do resumo estendido:
%   (1) SoC(k+1) = SoC(k) - (Ts·eta/Cn)·I(k)
%   (2) V1(k+1)  = a_rc·V1(k) + b_rc·I(k)            (a_rc e b_rc vêm do coef_rc: Euler ou exata)
%   (3) Vt(k)    = OCV(SoC(k)) - V1(k) - R0(SoC(k))·I(k)
% Entradas: estado atual (Soc_k, V1_k), corrente I_k (A, descarga positiva), struct bat (parametros_bat.m), Ts (s), discretizacao
% Saídas: próximo estado (Soc_prox, V1_prox) e tensão terminal ATUAL (Vt_atual)
% Simulink: cabe direto num bloco MATLAB Function; Soc e V1 voltam pela entrada através de dois Unit Delay

Soc_q = min(max(Soc_k, 0), 1);                          % SoC limitado a [0,1] SÓ para consultar as tabelas (interp1 dá NaN fora da faixa)
R0_atual = interp1(bat.Soc_tab, bat.R0, Soc_q);         % R0 interpolado no SoC atual
R1_atual = interp1(bat.Soc_tab, bat.R1, Soc_q);         % R1 interpolado no SoC atual
C1_atual = interp1(bat.Soc_tab, bat.C1, Soc_q);         % C1 interpolado no SoC atual
OCV_atual = interp1(bat.Soc_tab, bat.OCV, Soc_q);       % OCV interpolada no SoC atual
[a_rc, b_rc] = coef_rc(R1_atual, C1_atual, Ts, discretizacao);   % Coeficientes do ramo RC

Soc_prox = Soc_k - (Ts*bat.eta/bat.Cn) * I_k;           % Equação 1 (contagem da carga que saiu)
V1_prox  = a_rc * V1_k + b_rc * I_k;                    % Equação 2 (dinâmica do ramo RC)
Vt_atual = OCV_atual - V1_k - R0_atual * I_k;           % Equação 3 (o que o voltímetro mede)
end
