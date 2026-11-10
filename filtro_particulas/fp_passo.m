function [s, v, w, Soc_est, Neff, dp_Soc, reamostrou] = fp_passo(s, v, w, I_k, I_k1, Vt_k1, cfg, bat, Ts)
% fp_passo: UM passo do filtro de particulas (de k para k+1)
% Mesmo modelo de 1 ramo RC e mesma convencao de indices do ekf_passo
% Entradas: s e v = SoC e V1 das N particulas (Nx1), w = pesos (Nx1),
%           I_k e I_k1 = corrente medida em k e k+1 (A), Vt_k1 = tensao medida em k+1 (V),
%           cfg = struct do FP (montada no script principal), bat = parametros_bat.m, Ts = passo (s)
% Saidas: particulas e pesos em k+1, SoC estimado (media ponderada), Neff,
%         desvio padrao ponderado do SoC e se houve reamostragem neste passo

% numero de particulas
N = length(s);

% --- PREDICAO: cada particula anda pelo modelo da bateria ---
% SoC limitado a [0,1] so para consultar as tabelas
Soc_q = min(max(s, 0), 1);
% R1 e C1 no SoC de cada particula (uma coluna para cada parametro)
rc = interp1(bat.Soc_tab, [bat.R1(:) bat.C1(:)], Soc_q);
% constante de tempo do ramo RC de cada particula (s)
tau = rc(:,1) .* rc(:,2);
% quanto de V1 sobra de um passo para o outro (forma exata, como no coef_rc)
a_rc = exp(-Ts ./ tau);
% ganho da corrente no ramo RC (forma exata, como no coef_rc)
b_rc = rc(:,1) .* (1 - a_rc);
% ruido de Cauchy na corrente de cada particula (opcional, 0 = desligado)
if cfg.escala_I_cauchy > 0
    % sorteia Cauchy pela inversa da distribuicao acumulada
    e_I = cfg.escala_I_cauchy * tan(pi * (rand(N,1) - 0.5));
    % corta valores extremos (cauda muito longa da Cauchy)
    e_I = min(max(e_I, -20*cfg.escala_I_cauchy), 20*cfg.escala_I_cauchy);
else
    % sem ruido extra na corrente
    e_I = 0;
end
% corrente que cada particula enxerga
I_p = I_k + e_I;
% SoC previsto: contagem de carga + ruido de processo (Q11)
s = s - (Ts*bat.eta/bat.Cn) * I_p + cfg.dp_Soc_proc * randn(N,1);
% V1 previsto: dinamica do ramo RC + ruido de processo (Q22)
v = a_rc .* v + b_rc .* I_p + cfg.dp_V1_proc * randn(N,1);
% SoC das particulas limitado entre 0 e 100%
s = min(max(s, 0), 1);

% --- CORRECAO: peso de cada particula pela tensao medida ---
% OCV e R0 no SoC previsto de cada particula
med = interp1(bat.Soc_tab, [bat.OCV(:) bat.R0(:)], s);
% tensao que cada particula espera medir em k+1
Vt_pred = med(:,1) - v - med(:,2) * I_k1;
% diferenca entre a tensao medida e a esperada
residuo = Vt_k1 - Vt_pred;
% peso novo = peso antigo x verossimilhanca gaussiana (em log, para nao zerar)
logw = log(w) - 0.5 * residuo.^2 / cfg.R;
% subtrai o maior valor para o exp nao dar zero em todas
logw = logw - max(logw);
% volta do log para o peso
w = exp(logw);
% normaliza para os pesos somarem 1
w = w / sum(w);

% --- ESTIMATIVA E DIAGNOSTICO ---
% numero efetivo de particulas
Neff = 1 / sum(w.^2);
% SoC estimado = media ponderada das particulas
Soc_est = sum(w .* s);
% espalhamento da nuvem: desvio padrao ponderado do SoC
dp_Soc = sqrt(sum(w .* (s - Soc_est).^2));

% --- REAMOSTRAGEM (low variance) quando a nuvem degenera ---
% reamostra so se Neff ficou abaixo da fracao escolhida de N
reamostrou = Neff < cfg.frac_Neff * N;
if reamostrou
    % indices das particulas sorteadas
    idx = low_variance(w);
    % copia o SoC das particulas sorteadas
    s = s(idx);
    % copia o V1 das particulas sorteadas
    v = v(idx);
    % pesos voltam a ser iguais
    w = ones(N,1) / N;
    % espalhamento apos a reamostragem (FP regularizado, opcional)
    if cfg.dp_espalhamento > 0
        % soma um ruido pequeno ao SoC e mantem entre 0 e 1
        s = min(max(s + cfg.dp_espalhamento * randn(N,1), 0), 1);
    end
end
end
