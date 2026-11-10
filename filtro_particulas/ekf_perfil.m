function [Soc_ekf, P11_hist, tempo] = ekf_perfil(I_med, Vt_med, Soc0_est, cfg_ekf, bat, Ts)
% ekf_perfil: roda o EKF (ekf_passo.m, o mesmo do trabalho de controle) em um perfil inteiro
% Entradas: I_med e Vt_med = medicoes (1 x N_med), Soc0_est = SoC inicial assumido (fracao),
%           cfg_ekf = struct com P0, Q (por segundo), R e V1_0, bat = parametros_bat.m, Ts = passo (s)
% Saidas: SoC estimado, P(1,1) a cada passo e tempo total (s)

% numero de medicoes
N_med = length(I_med);
% dispara o cronometro
tic;
% estado estimado [SoC; V1] a cada passo
x_est = zeros(2, N_med);
% estado inicial: SoC assumido e V1 inicial
x_est(:,1) = [Soc0_est; cfg_ekf.V1_0];
% covariancia inicial (Tabela 11)
P = cfg_ekf.P0;
% ruido de processo por passo
Q = cfg_ekf.Q * Ts;
% historico da incerteza do SoC
P11_hist = zeros(1, N_med);
% incerteza no passo 1
P11_hist(1) = P(1,1);
% laco do EKF: cada volta leva a estimativa de k para k+1
for k = 1:N_med-1
    % predicao + correcao (ekf_passo.m)
    [x_est(:,k+1), P] = ekf_passo(x_est(:,k), P, I_med(k), I_med(k+1), Vt_med(k+1), ...
                                  Q, cfg_ekf.R, bat, Ts, cfg_ekf.discretizacao);
    % guarda a incerteza do SoC
    P11_hist(k+1) = P(1,1);
end
% SoC estimado
Soc_ekf = x_est(1,:);
% para o cronometro
tempo = toc;
end
