function [Soc_fp, Neff_hist, dp_hist, n_reamost, tempo] = fp_bat(I_med, Vt_med, Soc0_est, cfg, bat, Ts, semente)
% fp_bat: roda o filtro de particulas em um perfil inteiro
% Entradas: I_med e Vt_med = medicoes (1 x N_med), Soc0_est = SoC inicial assumido (fracao),
%           cfg = struct do FP, bat = parametros_bat.m, Ts = passo (s), semente = sorteio
% Saidas: SoC estimado, Neff e desvio padrao do SoC a cada passo,
%         numero de reamostragens e tempo total (s)

% fixa a semente: mesmo sorteio sempre da o mesmo resultado
rng(semente);
% numero de medicoes
N_med = length(I_med);
% numero de particulas
N = cfg.N;
% dispara o cronometro (inclui a inicializacao)
tic;
% --- Inicializacao da nuvem ---
if isinf(cfg.sigma0)
    % sigma0 = Inf: uniforme entre 0 e 100% (nao usa o SoC assumido)
    s = rand(N,1);
else
    % normal centrada no SoC assumido, desvio sigma0
    s = Soc0_est + cfg.sigma0 * randn(N,1);
end
% SoC das particulas limitado entre 0 e 100%
s = min(max(s, 0), 1);
% V1 inicial igual em todas (celula em repouso)
v = cfg.V1_0 * ones(N,1);
% pesos iguais no inicio
w = ones(N,1) / N;

% --- Pre-alocacao das saidas ---
% SoC estimado a cada passo
Soc_fp = zeros(1, N_med);
% Neff a cada passo
Neff_hist = zeros(1, N_med);
% desvio padrao ponderado do SoC a cada passo
dp_hist = zeros(1, N_med);
% estimativa no passo 1 = media da nuvem inicial
Soc_fp(1) = mean(s);
% no passo 1 todas as particulas valem o mesmo
Neff_hist(1) = N;
% espalhamento da nuvem inicial
dp_hist(1) = std(s, 1);
% contador de reamostragens
n_reamost = 0;

% --- Laco do filtro: cada volta leva a nuvem de k para k+1 ---
for k = 1:N_med-1
    % predicao + correcao + reamostragem (fp_passo.m)
    [s, v, w, Soc_fp(k+1), Neff_hist(k+1), dp_hist(k+1), reamostrou] = ...
        fp_passo(s, v, w, I_med(k), I_med(k+1), Vt_med(k+1), cfg, bat, Ts);
    % conta as reamostragens
    n_reamost = n_reamost + reamostrou;
end
% para o cronometro
tempo = toc;
end
