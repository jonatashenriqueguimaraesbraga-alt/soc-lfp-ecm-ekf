% VIDEO DA NUVEM DE PARTICULAS - para a apresentacao (e Fig. D do artigo)
% Caso: FUDS, nominal, SoC0 assumido 90%, sorteio 1 (o mesmo da Fig. A), FP com a configuracao do teste final
% Em cima: histograma das particulas (peso de cada faixa de SoC), com SoC verdadeiro, CC, EKF e FP
% Embaixo: SoC no tempo ate o instante atual
% Rodar depois do teste_final_fp.m (le o fp_teste.mat)

% comeca limpo
clear; clc; close all;

% ===================== CONFIGURACOES =====================
% pasta 'resultados ekf' do trabalho de controle (onde estao os .csv)
pasta_ekf = 'C:\Users\misys\Downloads\Mestrado automacao\SISTEMAS DE CONTROLE AUTOMOTIVO\resultados ekf';
% pasta dos resultados
pasta_res = fullfile(pwd, 'resultados');
% caso do video
perfil = 'fuds'; cenario = 'nominal'; Soc0_est = 0.90; sorteio = 1;
% primeiros passos com um quadro por passo (convergencia)
k_lento = 30;
% cada quadro lento repetido (deixa o inicio mais devagar)
rep_lento = 4;
% depois, um quadro a cada tantos passos
passo_rapido = 20;
% quadros por segundo do video
fps = 30;
% metade da janela do histograma em torno do SoC verdadeiro (p.p.)
meia_janela_pp = 20;
% largura de cada barra do histograma (p.p.)
larg_bin_pp = 0.5;
% instantes da Fig. D (s)
t_fig_s = [0 1 600];
% janela do eixo x da Fig. D (%)
janela_fig_pp = [75 102];
% largura da Fig. D (cm)
largura_cm = 8.9;
% true = grava o video de novo; false = so refaz a Fig. D (o video ja esta pronto)
gravar_video = false;
% =========================================================

% parametros da celula -> struct bat
parametros_bat;
% passo (s)
Ts = 1;
% mesma configuracao do teste final (FP e EKF) e series para conferir
load(fullfile(pasta_res, 'fp_teste.mat'), 'cfg_fp', 'cfg_ekf', 'series');
% medicoes do caso
[t_min, I_med, Vt_med, Soc_ref] = carregar_teste(pasta_ekf, perfil, cenario, sorteio);
% numero de amostras
N_med = length(I_med);
% contagem de Coulomb
Soc_cc = cc_perfil(I_med, Soc0_est, bat, Ts);
% EKF
Soc_ekf = ekf_perfil(I_med, Vt_med, Soc0_est, cfg_ekf, bat, Ts);

% --- Passos que viram quadro do video ou painel da Fig. D ---
% lentos no inicio, depois espacados, mais os instantes da Fig. D
k_quadros = unique([1:k_lento, k_lento:passo_rapido:N_med, N_med, round(t_fig_s/Ts) + 1]);
% posicao de cada passo na lista de quadros (0 = nao guarda)
pos_q = zeros(1, N_med);
% numera os quadros
pos_q(k_quadros) = 1:length(k_quadros);

% --- FP com gravacao da nuvem (mesmo codigo e mesma semente do fp_bat) ---
% mesma semente do sorteio
rng(sorteio);
% numero de particulas
N = cfg_fp.N;
% inicializacao igual a do fp_bat
if isinf(cfg_fp.sigma0)
    % uniforme entre 0 e 100%
    s = rand(N,1);
else
    % normal em torno do SoC assumido
    s = Soc0_est + cfg_fp.sigma0 * randn(N,1);
end
% SoC das particulas entre 0 e 100%
s = min(max(s, 0), 1);
% V1 inicial
v = cfg_fp.V1_0 * ones(N,1);
% pesos iguais
w = ones(N,1) / N;
% SoC estimado
Soc_fp = zeros(1, N_med);
% Neff
Neff_h = zeros(1, N_med);
% passo 1
Soc_fp(1) = mean(s); Neff_h(1) = N;
% SoC das particulas em cada quadro
nuvem_s = zeros(N, length(k_quadros));
% pesos das particulas em cada quadro
nuvem_w = zeros(N, length(k_quadros));
% guarda a nuvem inicial
nuvem_s(:,1) = s; nuvem_w(:,1) = w;
% laco do filtro
for k = 1:N_med-1
    % um passo do FP (fp_passo.m)
    [s, v, w, Soc_fp(k+1), Neff_h(k+1)] = fp_passo(s, v, w, I_med(k), I_med(k+1), Vt_med(k+1), cfg_fp, bat, Ts);
    % se o passo k+1 e quadro, guarda a nuvem
    if pos_q(k+1) > 0
        % SoC das particulas
        nuvem_s(:, pos_q(k+1)) = s;
        % pesos
        nuvem_w(:, pos_q(k+1)) = w;
    end
end
% confere com o FP do teste final (mesmo caso e semente): diferenca deve ser zero
i_ser = find(strcmp({series.perfil}, perfil) & strcmp({series.cenario}, cenario) & [series.Soc0_est_pct] == 100*Soc0_est);
% mostra a diferenca maxima
fprintf('Diferenca maxima para o FP do teste final: %.2e p.p.\n', 100*max(abs(Soc_fp - series(i_ser).Soc_fp)));

% cores fixas: SoC verdadeiro, CC, EKF, FP
cor.ref = [0.45 0.80 0.50]; cor.cc = [0.45 0.45 0.45]; cor.ekf = [0.00 0.45 0.74]; cor.fp = [0.85 0.33 0.10];

% ================= Video =================
% so grava se pedido nas configuracoes
if gravar_video
% arquivo do video com o nome do caso
arq_video = fullfile(pasta_res, sprintf('video_nuvem_%s_%s_SoC0_%.0f.mp4', perfil, cenario, 100*Soc0_est));
% gravador de video MP4
vid = VideoWriter(arq_video, 'MPEG-4');
% quadros por segundo
vid.FrameRate = fps;
% qualidade alta
vid.Quality = 95;
% abre o arquivo
open(vid);
% figura 16:9 em pixels (slides)
fig = figure('WindowStyle', 'normal', 'Units', 'pixels', 'Position', [50 50 1280 720], 'Color', 'w');
% indices para exibir as curvas (~600 pontos)
ip = unique(round(linspace(1, N_med, 600)));
% so os passos que viram quadro do video (a Fig. D usa os outros)
k_video = unique([1:k_lento, k_lento:passo_rapido:N_med, N_med]);
% um quadro por vez
for k = k_video
    % nuvem deste passo
    q = pos_q(k);
    % limpa a figura
    clf(fig);
    % --- painel de cima: histograma da nuvem ---
    subplot(2, 1, 1); hold on;
    % centro da janela = SoC verdadeiro (%)
    c = 100 * Soc_ref(k);
    % bordas das barras na janela, sem passar de -2% e 102%
    bordas = max(-2, c - meia_janela_pp):larg_bin_pp:min(102, c + meia_janela_pp);
    % peso de cada barra (soma dos pesos das particulas dentro dela, em %)
    peso = histograma_peso(100*nuvem_s(:,q), nuvem_w(:,q), bordas);
    % SoC verdadeiro: faixa clara desenhada antes, para ficar por baixo das barras
    plot([c c], [0 1000], '-', 'Color', cor.ref, 'LineWidth', 4);
    % barras do histograma por cima
    bar(bordas(1:end-1) + larg_bin_pp/2, peso, 1, 'FaceColor', cor.fp, 'EdgeColor', 'none', 'FaceAlpha', 0.8);
    % CC
    xline(100*Soc_cc(k), '--', 'Color', cor.cc, 'LineWidth', 1.5);
    % EKF
    xline(100*Soc_ekf(k), '-.', 'Color', cor.ekf, 'LineWidth', 1.5);
    % FP (media ponderada)
    xline(100*Soc_fp(k), '-', 'Color', cor.fp, 'LineWidth', 1.5);
    % janela do eixo x
    xlim([bordas(1) bordas(end)]);
    % eixo y ajustado a barra mais alta (no minimo 10%, para a nuvem espalhada aparecer)
    ylim([0 max(10, 1.1*max(peso))]);
    % estilo do projeto
    aplicar_estilo_artigo(sprintf('Nuvem de partículas | t = %s | N_{eff} = %.1f de %d', texto_tempo((k-1)*Ts), Neff_h(k), N), 'SoC (%)', 'Peso das partículas (%)');
    % letras maiores para projetar
    fonte_video(gca);
    % valores atuais (aparecem mesmo se a linha sair da janela)
    text(0.01, 0.92, sprintf('Verdadeiro %.1f%%  |  CC %.1f%%  |  EKF %.1f%%  |  FP %.1f%%', c, 100*Soc_cc(k), 100*Soc_ekf(k), 100*Soc_fp(k)), ...
        'Units', 'normalized', 'FontName', 'Times New Roman', 'FontSize', 16, 'Color', 'k', 'BackgroundColor', 'w');
    % --- painel de baixo: SoC no tempo ate agora ---
    subplot(2, 1, 2); hold on;
    % pontos de exibicao ja passados, mais o atual
    ik = [ip(ip < k), k];
    % SoC verdadeiro: faixa clara
    plot(t_min(ik), 100*Soc_ref(ik), '-', 'Color', cor.ref, 'LineWidth', 3);
    % CC
    plot(t_min(ik), 100*Soc_cc(ik), '--', 'Color', cor.cc, 'LineWidth', 1.2);
    % EKF
    plot(t_min(ik), 100*Soc_ekf(ik), '-.', 'Color', cor.ekf, 'LineWidth', 1.2);
    % FP
    plot(t_min(ik), 100*Soc_fp(ik), '-', 'Color', cor.fp, 'LineWidth', 1.2);
    % legenda criada antes do estilo
    lg = legend({'SoC verdadeiro', 'CC', 'EKF', 'FP'}, 'Location', 'northeast', 'NumColumns', 4);
    % eixos fixos (perfil inteiro)
    xlim([0 t_min(end)]); ylim([-5 110]);
    % estilo do projeto
    aplicar_estilo_artigo(sprintf('FUDS, SoC inicial assumido %.0f%% (verdadeiro 100%%)', 100*Soc0_est), 'Tempo (min)', 'SoC (%)');
    % letras maiores para projetar
    fonte_video(gca);
    % legenda preta com fundo branco e letra maior
    set(lg, 'TextColor', 'k', 'Color', 'w', 'FontSize', 14);
    % desenha
    drawnow;
    % captura o quadro
    quadro = getframe(fig);
    % no inicio o quadro e repetido (fica mais devagar)
    if k <= k_lento, n_rep = rep_lento; else, n_rep = 1; end
    % grava o quadro
    for r = 1:n_rep, writeVideo(vid, quadro); end
end
% fecha o video
close(vid);
% confirma
fprintf('Video salvo em %s\n', arq_video);
% fim do if gravar_video
end

% ================= Fig. D: nuvem em 3 instantes (artigo) =================
% abre a figura no tamanho da coluna
figD = figure('WindowStyle', 'normal', 'Units', 'centimeters', 'Position', [2 2 largura_cm 6]);
% 3 paineis lado a lado
tiledlayout(1, length(t_fig_s), 'TileSpacing', 'compact', 'Padding', 'compact');
% bordas fixas das barras
bordas = janela_fig_pp(1):larg_bin_pp:janela_fig_pp(2);
% um instante por painel
for j = 1:length(t_fig_s)
    % passo deste instante
    k = round(t_fig_s(j)/Ts) + 1;
    % nuvem deste passo
    q = pos_q(k);
    % novo painel
    nexttile; hold on;
    % peso de cada barra (%)
    peso = histograma_peso(100*nuvem_s(:,q), nuvem_w(:,q), bordas);
    % SoC verdadeiro: faixa clara desenhada antes, para ficar por baixo das barras
    hr = plot(100*Soc_ref(k)*[1 1], [0 1000], '-', 'Color', cor.ref, 'LineWidth', 2.0);
    % histograma do peso das particulas por cima
    hb = bar(bordas(1:end-1) + larg_bin_pp/2, peso, 1, 'FaceColor', cor.fp, 'EdgeColor', 'none');
    % EKF
    he = xline(100*Soc_ekf(k), '-.', 'Color', cor.ekf, 'LineWidth', 0.8);
    % janela fixa no eixo x
    xlim(janela_fig_pp);
    % eixo y ajustado a barra mais alta (no minimo 5%)
    ylim([0 max(5, 1.1*max(peso))]);
    % estilo do projeto
    aplicar_estilo_artigo(sprintf('(%s) t = %s', char('a' + j - 1), texto_tempo(t_fig_s(j))), 'SoC (%)', '');
    % titulo pequeno, como nos artigos
    title(sprintf('(%s) t = %s', char('a' + j - 1), texto_tempo(t_fig_s(j))), 'FontName', 'Times New Roman', 'FontSize', 9, 'FontWeight', 'normal', 'Color', 'k');
    % numeros em 8 pt
    set(gca, 'FontSize', 8);
    % rotulo do eixo y so no primeiro painel
    if j == 1, ylabel('Peso (%)', 'FontSize', 9); end
    % legenda uma vez so, embaixo dos tres paineis
    if j == 1
        % legenda das tres marcas, em uma linha
        lg = legend([hb hr he], {'Partículas (FP)', 'SoC verdadeiro', 'EKF'}, 'Orientation', 'horizontal', 'FontSize', 7);
        % posicao: faixa de baixo do tiledlayout
        lg.Layout.Tile = 'south';
        % legenda preta com fundo branco
        set(lg, 'TextColor', 'k', 'Color', 'w');
    end
end
% fundo branco
set(figD, 'Color', 'w');
% tamanho da coluna antes de salvar
set(figD, 'Units', 'centimeters', 'Position', [2 2 largura_cm 6]); drawnow;
% pasta das figuras do artigo
pasta_fig = fullfile(pasta_res, 'figuras_artigo');
% cria se nao existir
if ~exist(pasta_fig, 'dir'), mkdir(pasta_fig); end
% PDF vetorial
exportgraphics(figD, fullfile(pasta_fig, 'figD_nuvem_fuds_nominal_SoC0_90.pdf'), 'ContentType', 'vector', 'BackgroundColor', 'white');
% PNG 300 dpi
exportgraphics(figD, fullfile(pasta_fig, 'figD_nuvem_fuds_nominal_SoC0_90.png'), 'Resolution', 300, 'BackgroundColor', 'white');
% confirma
fprintf('Fig. D salva em %s\n', pasta_fig);

% ================= Funcoes locais =================
function peso = histograma_peso(x, w, bordas)
% soma o peso das particulas em cada faixa de SoC (em %)
% faixa de cada particula (0 = fora da janela)
[~, ~, faixa] = histcounts(x, bordas);
% so as particulas dentro da janela
dentro = faixa > 0;
% soma dos pesos por faixa
peso = 100 * accumarray(faixa(dentro), w(dentro), [length(bordas)-1, 1])';
end

function fonte_video(ax)
% aumenta as letras do painel para o video (projecao)
% numeros dos eixos
set(ax, 'FontSize', 14);
% titulo
set(get(ax, 'Title'), 'FontSize', 18);
% rotulos dos eixos
set(get(ax, 'XLabel'), 'FontSize', 16); set(get(ax, 'YLabel'), 'FontSize', 16);
end

function txt = texto_tempo(t_s)
% escreve o tempo em s (ate 1 min) ou em min
if t_s < 60
    % segundos
    txt = sprintf('%d s', round(t_s));
else
    % minutos
    txt = sprintf('%.0f min', t_s/60);
end
end
