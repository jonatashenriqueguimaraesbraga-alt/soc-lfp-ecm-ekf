function [Soc_cc, tempo] = cc_perfil(I_med, Soc0_est, bat, Ts)
% cc_perfil: contagem de Coulomb (cc_passo.m) em um perfil inteiro
% Entradas: I_med = corrente medida (1 x N_med), Soc0_est = SoC inicial assumido (fracao),
%           bat = parametros_bat.m, Ts = passo (s)
% Saidas: SoC da contagem de Coulomb e tempo total (s)

% numero de medicoes
N_med = length(I_med);
% dispara o cronometro
tic;
% pre-aloca o SoC
Soc_cc = zeros(1, N_med);
% parte do SoC assumido
Soc_cc(1) = Soc0_est;
% integra a corrente medida passo a passo
for k = 1:N_med-1
    % retira a carga medida no passo
    Soc_cc(k+1) = cc_passo(Soc_cc(k), I_med(k), bat, Ts);
end
% para o cronometro
tempo = toc;
end
