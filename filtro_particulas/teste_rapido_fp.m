% TESTE RAPIDO DO FP - um perfil de validacao, um sorteio, com figuras
% Serve para ver o filtro funcionando e medir o tempo por amostra antes da validacao completa
% Usa so perfil de VALIDACAO (os de teste ficam para a rodada final)

% comeca limpo
clear; clc; close all;

% ===================== CONFIGURACOES =====================
% pasta dos .csv a 1 s gerados no trabalho de controle
pasta_dados = 'C:\Users\misys\Downloads\Mestrado automacao\SISTEMAS DE CONTROLE AUTOMOTIVO\resultados ekf\dados_lstm_v10';
% pasta onde as figuras e os resultados ficam
pasta_res = fullfile(pwd, 'resultados');
% perfil de validacao (207 a 212)
perfil = 207;
% cenario de erro de corrente: 'nominal', 'ref_bias' ou 'ref_ruido'
cenario = 'nominal';
% SoC inicial assumido pelos estimadores (fracao); o verdadeiro e 100%
Soc0_est = 0.90;
% numero de particulas
N_particulas = 500;
% desvio padrao da nuvem inicial (p.p.); Inf = uniforme entre 0 e 100%
sigma0_pp = 5;
% sorteio (semente do FP)
sorteio = 1;
% =========================================================

% cria a pasta de resultados se nao existir
if ~exist(pasta_res, 'dir'), mkdir(pasta_res); end
% parametros da celula (Tabelas 6 e 7 da referencia) -> struct bat
parametros_bat;
% passo dos sensores e dos estimadores (s)
Ts = 1;

% --- EKF: valores da Tabela 11, sem ajuste ---
% covariancia inicial: 0,95 %^2 e 8 mV^2
cfg_ekf.P0 = diag([0.95/100^2, 8/1000^2]);
% ruido de processo por segundo: 9,99e-10 %^2 e 10 mV^2
cfg_ekf.Q = diag([9.99e-10/100^2, 10/1000^2]);
% ruido de medicao: 8 mV^2
cfg_ekf.R = 8/1000^2;
% V1 inicial (celula em repouso)
cfg_ekf.V1_0 = 0;
% ramo RC na forma exata
cfg_ekf.discretizacao = 'exata';

% --- FP: mesmo modelo, mesmo Q e R do EKF ---
% numero de particulas
cfg_fp.N = N_particulas;
% desvio da nuvem inicial (fracao)
cfg_fp.sigma0 = sigma0_pp / 100;
% desvio do ruido de processo do SoC por passo (raiz de Q11)
cfg_fp.dp_Soc_proc = sqrt(cfg_ekf.Q(1,1) * Ts);
% desvio do ruido de processo de V1 por passo (raiz de Q22)
cfg_fp.dp_V1_proc = sqrt(cfg_ekf.Q(2,2) * Ts);
% variancia da medicao de tensao no peso (V^2)
cfg_fp.R = cfg_ekf.R;
% reamostra quando Neff < frac_Neff * N
cfg_fp.frac_Neff = 0.5;
% ruido de Cauchy na corrente (A); 0 = desligado
cfg_fp.escala_I_cauchy = 0;
% espalhamento do SoC apos reamostrar (fracao); 0 = desligado
cfg_fp.dp_espalhamento = 0;
% V1 inicial das particulas
cfg_fp.V1_0 = 0;

% --- Erros de corrente dos cenarios (mesmos do trabalho de controle) ---
% bias de 0,15 A
cfg_sensor.bias_A = 0.15;
% bias a partir da metade do ensaio
cfg_sensor.inicio_bias = 0.5;
% ruido extra de variancia 0,2 A^2
cfg_sensor.var_ruido = 0.2;

% --- Dados do perfil ---
% nome do arquivo de validacao (o sorteio do sensor do .csv e o perfil + 1)
arquivo = fullfile(pasta_dados, sprintf('dados_lstm_validacao_aleatorio_s%d_p3_nominal_r%d_1s.csv', perfil, perfil+1));
% le o perfil e aplica o cenario
[t_min, I_med, Vt_med, Soc_ref] = carregar_validacao(arquivo, cenario, 1000 + sorteio, cfg_sensor);
% numero de amostras
N_med = length(I_med);

% --- Estimadores sobre as MESMAS medicoes ---
% contagem de Coulomb
[Soc_cc, tempo_cc] = cc_perfil(I_med, Soc0_est, bat, Ts);
% EKF
[Soc_ekf, P11_hist, tempo_ekf] = ekf_perfil(I_med, Vt_med, Soc0_est, cfg_ekf, bat, Ts);
% filtro de particulas
[Soc_fp, Neff_hist, dp_hist, n_reamost, tempo_fp] = fp_bat(I_med, Vt_med, Soc0_est, cfg_fp, bat, Ts, sorteio);

% --- Metricas (mesma funcao do trabalho de controle) ---
% CC
[rmse_cc, ~, emax_cc] = metricas_erro(Soc_cc, Soc_ref, t_min, 0.02);
% EKF
[rmse_ekf, ~, emax_ekf] = metricas_erro(Soc_ekf, Soc_ref, t_min, 0.02);
% FP
[rmse_fp, ~, emax_fp] = metricas_erro(Soc_fp, Soc_ref, t_min, 0.02);

% --- Resumo no Command Window ---
% cabecalho
fprintf('\nPerfil s%d | %s | SoC0 assumido %.0f%% | N = %d | sigma0 = %g p.p.\n', perfil, cenario, 100*Soc0_est, cfg_fp.N, sigma0_pp);
% tabela
fprintf('%-6s %10s %12s %16s\n', 'Metodo', 'RMSE (pp)', 'Erro max (pp)', 'Tempo/amostra (ms)');
% linha da CC
fprintf('%-6s %10.2f %12.2f %16.4f\n', 'CC', rmse_cc, emax_cc, 1000*tempo_cc/N_med);
% linha do EKF
fprintf('%-6s %10.2f %12.2f %16.4f\n', 'EKF', rmse_ekf, emax_ekf, 1000*tempo_ekf/N_med);
% linha do FP
fprintf('%-6s %10.2f %12.2f %16.4f\n', 'FP', rmse_fp, emax_fp, 1000*tempo_fp/N_med);
% diagnostico da nuvem
fprintf('FP: Neff mediano = %.1f de %d | reamostrou em %.0f%% dos passos\n', median(Neff_hist(2:end)), cfg_fp.N, 100*n_reamost/(N_med-1));

% --- Figura 1: SoC e erro ---
% so para exibir: ~600 pontos por curva (os dados do calculo nao mudam)
ip = unique(round(linspace(1, N_med, 600)));
% ~10 marcadores por curva, deslocados entre as curvas para nao se tamparem
im = @(desl) unique(round(linspace(1 + desl, length(ip) - 30 + desl, 10)));
% cores: SoC verdadeiro, CC, EKF, FP
cor_ref = [0.45 0.80 0.50]; cor_cc = [0.45 0.45 0.45]; cor_ekf = [0.00 0.45 0.74]; cor_fp = [0.85 0.33 0.10];
% abre a figura
fig1 = figure('Name', 'SoC - FP');
% painel de cima: SoC
subplot(2,1,1); hold on;
% SoC verdadeiro como faixa larga e clara, desenhado primeiro
plot(t_min(ip), 100*Soc_ref(ip), '-', 'Color', cor_ref, 'LineWidth', 2.0);
% CC: tracejado com quadrados
plot(t_min(ip), 100*Soc_cc(ip), '--', 'Color', cor_cc, 'LineWidth', 0.8, 'Marker', 's', 'MarkerSize', 4, 'MarkerFaceColor', cor_cc, 'MarkerIndices', im(0));
% EKF: traco-ponto com circulos
plot(t_min(ip), 100*Soc_ekf(ip), '-.', 'Color', cor_ekf, 'LineWidth', 0.8, 'Marker', 'o', 'MarkerSize', 4, 'MarkerFaceColor', cor_ekf, 'MarkerIndices', im(10));
% FP: continua com triangulos, desenhado por ultimo
plot(t_min(ip), 100*Soc_fp(ip), '-', 'Color', cor_fp, 'LineWidth', 0.7, 'Marker', '^', 'MarkerSize', 4, 'MarkerFaceColor', cor_fp, 'MarkerIndices', im(20));
% legenda criada antes do estilo, com o RMSE de cada metodo
lg = legend('SoC verdadeiro', sprintf('CC (RMSE %.2f p.p.)', rmse_cc), sprintf('EKF (RMSE %.2f p.p.)', rmse_ekf), sprintf('FP (RMSE %.2f p.p.)', rmse_fp), 'Location', 'southwest');
% estilo do projeto
aplicar_estilo_artigo(sprintf('SoC - validacao s%d, %s, SoC0 assumido %.0f%%', perfil, strrep(cenario, '_', ' '), 100*Soc0_est), 'Tempo (min)', 'SoC (%)');
% legenda com texto preto e fundo branco
set(lg, 'TextColor', 'k', 'Color', 'w', 'FontName', 'Times New Roman');
% folga de 5% no eixo y
yl = ylim; ylim(yl + [-1 1]*0.05*diff(yl));
% painel de baixo: erro
subplot(2,1,2); hold on;
% erro da CC
plot(t_min(ip), 100*(Soc_cc(ip) - Soc_ref(ip)), '--', 'Color', cor_cc, 'LineWidth', 0.8, 'Marker', 's', 'MarkerSize', 4, 'MarkerFaceColor', cor_cc, 'MarkerIndices', im(0));
% erro do EKF
plot(t_min(ip), 100*(Soc_ekf(ip) - Soc_ref(ip)), '-.', 'Color', cor_ekf, 'LineWidth', 0.8, 'Marker', 'o', 'MarkerSize', 4, 'MarkerFaceColor', cor_ekf, 'MarkerIndices', im(10));
% erro do FP
plot(t_min(ip), 100*(Soc_fp(ip) - Soc_ref(ip)), '-', 'Color', cor_fp, 'LineWidth', 0.7, 'Marker', '^', 'MarkerSize', 4, 'MarkerFaceColor', cor_fp, 'MarkerIndices', im(20));
% linhas de +-2 p.p.
yline([-2 2], ':k');
% estilo do projeto
aplicar_estilo_artigo('Erro do SoC (estimado - verdadeiro)', 'Tempo (min)', 'Erro (p.p.)');
% folga de 8% no eixo y
yl = ylim; ylim(yl + [-1 1]*0.08*diff(yl));

% --- Figura 2: diagnostico da nuvem ---
% abre a figura
fig2 = figure('Name', 'Diagnostico do FP');
% painel de cima: Neff
subplot(2,1,1);
% Neff a cada passo (antes da reamostragem)
plot(t_min(ip), Neff_hist(ip), '-', 'Color', cor_fp, 'LineWidth', 0.7);
% estilo do projeto
aplicar_estilo_artigo('Numero efetivo de particulas (N_{eff})', 'Tempo (min)', 'N_{eff}');
% escala log: Neff vai de N ate perto de 1
set(gca, 'YScale', 'log');
% painel de baixo: espalhamento da nuvem
subplot(2,1,2);
% desvio padrao ponderado do SoC das particulas
plot(t_min(ip), 100*dp_hist(ip), '-', 'Color', cor_fp, 'LineWidth', 0.7);
% estilo do projeto
aplicar_estilo_artigo('Desvio padrao ponderado do SoC das particulas', 'Tempo (min)', 'Desvio (p.p.)');

% --- Salva figuras e numeros ---
% nome com a configuracao
nome = sprintf('teste_rapido_s%d_%s_SoC0_%.0f_N%d_sig%g', perfil, cenario, 100*Soc0_est, cfg_fp.N, sigma0_pp);
% figura do SoC
exportgraphics(fig1, fullfile(pasta_res, [nome '_soc.png']), 'Resolution', 200);
% figura do diagnostico
exportgraphics(fig2, fullfile(pasta_res, [nome '_diag.png']), 'Resolution', 200);
% series e configuracao em .mat
save(fullfile(pasta_res, [nome '.mat']), 't_min', 'Soc_ref', 'Soc_cc', 'Soc_ekf', 'Soc_fp', 'Neff_hist', 'dp_hist', 'cfg_fp', 'cfg_ekf', ...
     'rmse_cc', 'rmse_ekf', 'rmse_fp', 'tempo_cc', 'tempo_ekf', 'tempo_fp', 'N_med');
% confirma
fprintf('Figuras e .mat salvos em %s\n', pasta_res);
