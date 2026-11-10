function [a_rc, b_rc] = coef_rc(R1_atual, C1_atual, Ts, discretizacao_rc)
% coef_rc: coeficientes da equação discreta do ramo RC  ->  V1(k+1) = a_rc*V1(k) + b_rc*I(k)
% Usada pela planta (ecm_passo.m) e pelo EKF (ekf_passo.m): a fórmula fica num lugar só
% Entradas: R1_atual (Ω), C1_atual (F), Ts (s), discretizacao_rc ('euler' ou 'exata'; no configuracao.m: discretizacao_planta e discretizacao_est)
% Saídas: a_rc = quanto de V1 "sobra" de um passo para o outro; b_rc = quanto a corrente carrega o capacitor em um passo
% No EKF, a_rc também é o elemento A(2,2) do Jacobiano (derivada de V1(k+1) em relação a V1(k))

tau = R1_atual * C1_atual;                 % Constante de tempo do ramo RC (s)
if strcmp(discretizacao_rc, 'exata')       % Forma exata (solução da EDO com corrente constante no passo): estável para qualquer Ts
    a_rc = exp(-Ts / tau);                 % Decaimento exponencial de V1 em um passo
    b_rc = R1_atual * (1 - a_rc);          % Ganho da corrente: com I constante, V1 tende a R1·I
else                                       % Forma de Euler (Equação 2 do resumo estendido): exige Ts < 2·tau
    a_rc = 1 - Ts / tau;                   % Aproximação de primeira ordem do exp(-Ts/tau)
    b_rc = Ts / C1_atual;                  % Carga entregue ao capacitor em um passo, dividida por C1
end
end
