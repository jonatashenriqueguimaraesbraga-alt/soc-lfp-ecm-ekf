% FIGURAS DO ARTIGO - padrao dos artigos de comparacao de estimadores (Jost 2024, Yang 2016)
% Fig. A: corrente, SoC e erro no tempo (FUDS, nominal, SoC0 assumido 90%, sorteio 1), com zoom no inicio
% Fig. B: SoC e erro no tempo com bias (FUDS, SoC0 assumido 100%, sorteio 1): efeito do limite de 0%
% Fig. C: RMSE e tempo por amostra x numero de particulas (validacao, 20 sorteios)
% Rodar depois do teste_final_fp.m e do validacao_fp.m (etapa 'N'): le os .mat e .csv da pasta resultados

% comeca limpo
clear; clc; close all;

% ===================== CONFIGURACOES =====================
% pasta dos resultados
pasta_res = fullfile(pwd, 'resultados');
% pasta das figuras do artigo
pasta_fig = fullfile(pasta_res, 'figuras_artigo');
% largura de uma coluna IEEE (cm)
largura_cm = 8.9;
% caso da Fig. A: perfil, cenario e SoC inicial assumido (%)
casoA = {'fuds', 'nominal', 90};
% caso da Fig. B
casoB = {'fuds', 'ref_bias', 100};
% janela do zoom da Fig. A (min)
zoom_min = 10;
% pontos por curva so para exibir (os dados nao mudam)
n_exib = 600;
% =========================================================

% cria a pasta das figuras se nao existir
if ~exist(pasta_fig, 'dir'), mkdir(pasta_fig); end
% series do sorteio 1 do teste final
load(fullfile(pasta_res, 'fp_teste.mat'), 'series');
% cores fixas em todas as figuras: SoC verdadeiro, CC, EKF, FP
cor.ref = [0.45 0.80 0.50]; cor.cc = [0.45 0.45 0.45]; cor.ekf = [0.00 0.45 0.74]; cor.fp = [0.85 0.33 0.10];

% ================= Fig. A: nominal, SoC0 assumido 90% =================
% posicao do caso na lista de series
iA = find(strcmp({series.perfil}, casoA{1}) & strcmp({series.cenario}, casoA{2}) & [series.Soc0_est_pct] == casoA{3});
% dados do caso
s = series(iA);
% indices para exibir (~600 pontos)
ip = unique(round(linspace(1, length(s.t_min), n_exib)));
% abre a figura no tamanho da coluna
figA = figure('WindowStyle', 'normal', 'Units', 'centimeters', 'Position', [2 2 largura_cm 14]);
% 4 paineis empilhados com pouco espaco
tiledlayout(4, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
% (a) corrente medida: todos os pontos, linha fina (reduzir apagaria os picos)
ax1 = nexttile; plot(s.t_min, s.I_med, '-', 'Color', cor.cc, 'LineWidth', 0.3);
% estilo do projeto, sem titulo grande
estilo_painel('(a) Corrente medida', '', 'Corrente (A)');
% (b) SoC
ax2 = nexttile; hold on;
% curvas de SoC (funcao local)
h = plotar_soc(s, ip, cor, false);
% legenda criada antes do estilo
lg = legend(h, {'SoC verdadeiro', 'CC', 'EKF', 'FP'}, 'FontSize', 7, 'NumColumns', 4);
% legenda no topo da figura inteira (fora dos paineis, sem encolher nenhum)
lg.Layout.Tile = 'north';
% estilo do projeto
estilo_painel('(b) SoC', '', 'SoC (%)');
% legenda preta com fundo branco
set(lg, 'TextColor', 'k', 'Color', 'w');
% folga de 5% no eixo y
folga_y(0.05);
% (c) erro no perfil inteiro
ax3 = nexttile; hold on;
% curvas de erro com faixa de +-2 p.p.
plotar_erro(s, ip, cor);
% estilo do projeto
estilo_painel('(c) Erro do SoC', 'Tempo (min)', 'Erro (p.p.)');
% folga de 8% no eixo y
folga_y(0.08);
% (d) zoom nos primeiros minutos: todos os pontos da janela
nexttile; hold on;
% indices da janela do zoom
iz = find(s.t_min <= zoom_min);
% curvas de erro na janela
plotar_erro(s, iz, cor);
% estilo do projeto
estilo_painel(sprintf('(d) Erro do SoC nos primeiros %d min', zoom_min), 'Tempo (min)', 'Erro (p.p.)');
% limite do eixo x na janela
xlim([0 zoom_min]);
% folga de 8% no eixo y
folga_y(0.08);
% eixos de tempo iguais nos 3 primeiros paineis
linkaxes([ax1 ax2 ax3], 'x');
% salva em PDF vetorial (artigo) e PNG 300 dpi (slides)
salvar_fig(figA, pasta_fig, sprintf('figA_soc_%s_%s_SoC0_%d', casoA{:}), [largura_cm 14]);

% ================= Fig. B: bias, SoC0 assumido 100% =================
% posicao do caso na lista de series
iB = find(strcmp({series.perfil}, casoB{1}) & strcmp({series.cenario}, casoB{2}) & [series.Soc0_est_pct] == casoB{3});
% dados do caso
s = series(iB);
% indices para exibir (~600 pontos)
ip = unique(round(linspace(1, length(s.t_min), n_exib)));
% abre a figura no tamanho da coluna
figB = figure('WindowStyle', 'normal', 'Units', 'centimeters', 'Position', [2 2 largura_cm 8]);
% 2 paineis empilhados
tiledlayout(2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
% (a) SoC
nexttile; hold on;
% curvas de SoC
h = plotar_soc(s, ip, cor, false);
% linha do limite de 0%
yline(0, ':k');
% legenda criada antes do estilo
lg = legend(h, {'SoC verdadeiro', 'CC', 'EKF', 'FP'}, 'Location', 'northeast', 'FontSize', 7);
% estilo do projeto
estilo_painel('(a) SoC', '', 'SoC (%)');
% legenda preta com fundo branco
set(lg, 'TextColor', 'k', 'Color', 'w');
% folga de 5% no eixo y
folga_y(0.05);
% (b) erro
nexttile; hold on;
% curvas de erro com faixa de +-2 p.p.
plotar_erro(s, ip, cor);
% marca o inicio do bias (metade do perfil)
xline(s.t_min(round(0.5*length(s.t_min))), '--k', 'Início do bias', 'FontSize', 7, 'LabelVerticalAlignment', 'bottom');
% estilo do projeto
estilo_painel('(b) Erro do SoC', 'Tempo (min)', 'Erro (p.p.)');
% folga de 8% no eixo y
folga_y(0.08);
% salva
salvar_fig(figB, pasta_fig, sprintf('figB_soc_%s_%s_SoC0_%d', casoB{:}), [largura_cm 8]);

% ================= Fig. C: varredura do numero de particulas =================
% todas as rodadas da etapa N da validacao
tabN = readtable(fullfile(pasta_res, 'fp_val_N_todos.csv'), 'TextType', 'string');
% numeros de particulas testados
lista_N = unique(tabN.N(~isnan(tabN.N)))';
% RMSE medio, desvio e tempo medio de cada N
rmse_m = zeros(size(lista_N)); rmse_d = rmse_m; t_m = rmse_m;
% um N por vez
for j = 1:length(lista_N)
    % linhas do FP com este N
    sel = tabN.N == lista_N(j);
    % media do RMSE
    rmse_m(j) = mean(tabN.rmse_pct(sel));
    % desvio do RMSE
    rmse_d(j) = std(tabN.rmse_pct(sel));
    % tempo medio por amostra
    t_m(j) = mean(tabN.t_amostra_ms(sel));
end
% RMSE medio do EKF na mesma validacao
rmse_ekf = mean(tabN.rmse_pct(tabN.metodo == "EKF"));
% RMSE medio da CC
rmse_cc = mean(tabN.rmse_pct(tabN.metodo == "CC"));
% tempo medio do EKF na mesma rodada
t_ekf = mean(tabN.t_amostra_ms(tabN.metodo == "EKF"));
% abre a figura no tamanho da coluna
figC = figure('WindowStyle', 'normal', 'Units', 'centimeters', 'Position', [2 2 largura_cm 8]);
% 2 paineis empilhados
tiledlayout(2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
% (a) RMSE x N
nexttile; hold on;
% FP: media com barra de desvio, marcador losango
hf = errorbar(lista_N, rmse_m, rmse_d, '-d', 'Color', cor.fp, 'LineWidth', 0.8, 'MarkerSize', 5, 'MarkerFaceColor', cor.fp, 'CapSize', 4);
% EKF: linha horizontal (nao depende de N)
he = yline(rmse_ekf, '-.', 'Color', cor.ekf, 'LineWidth', 0.8);
% CC: linha horizontal
hc = yline(rmse_cc, '--', 'Color', cor.cc, 'LineWidth', 0.8);
% legenda criada antes do estilo
lg = legend([hc he hf], {'CC', 'EKF', 'FP'}, 'Location', 'northeast', 'FontSize', 7);
% estilo do projeto
estilo_painel('(a) RMSE médio na validação', '', 'RMSE (p.p.)');
% legenda preta com fundo branco
set(lg, 'TextColor', 'k', 'Color', 'w');
% eixo x em escala log (100 a 5000)
set(gca, 'XScale', 'log', 'XTick', lista_N, 'XMinorGrid', 'off', 'XMinorTick', 'off'); xlim([0.8*lista_N(1) 1.25*lista_N(end)]);
% eixo y a partir de zero
ylim([0 1.1*max([rmse_ekf, rmse_m + rmse_d])]);
% (b) tempo x N
nexttile; hold on;
% FP: tempo medio por amostra
hf = plot(lista_N, t_m, '-d', 'Color', cor.fp, 'LineWidth', 0.8, 'MarkerSize', 5, 'MarkerFaceColor', cor.fp);
% EKF: linha horizontal
he = yline(t_ekf, '-.', 'Color', cor.ekf, 'LineWidth', 0.8);
% legenda criada antes do estilo
lg = legend([he hf], {'EKF', 'FP'}, 'Location', 'northwest', 'FontSize', 7);
% estilo do projeto
estilo_painel('(b) Tempo de cálculo por amostra', 'Número de partículas N', 'Tempo (ms)');
% legenda preta com fundo branco
set(lg, 'TextColor', 'k', 'Color', 'w');
% mesmo eixo x do painel (a)
set(gca, 'XScale', 'log', 'XTick', lista_N, 'XMinorGrid', 'off', 'XMinorTick', 'off'); xlim([0.8*lista_N(1) 1.25*lista_N(end)]);
% eixo y a partir de zero
ylim([0 1.1*max(t_m)]);
% salva
salvar_fig(figC, pasta_fig, 'figC_varredura_N_validacao', [largura_cm 8]);

% mostra os numeros usados na Fig. C (para conferir com o texto)
fprintf('Fig. C: N = %s | RMSE = %s | tempo (ms) = %s | EKF %.2f p.p. e %.4f ms | CC %.2f p.p.\n', ...
    mat2str(lista_N), mat2str(round(rmse_m, 2)), mat2str(round(t_m, 4)), rmse_ekf, t_ekf, rmse_cc);
% confirma
fprintf('Figuras salvas em %s\n', pasta_fig);

% ================= Funcoes locais =================
function h = plotar_soc(s, ip, cor, ~)
% desenha SoC verdadeiro (faixa clara por baixo), CC, EKF e FP; devolve as linhas para a legenda
% marcadores: ~10 por curva, deslocados entre as curvas
im = @(d) unique(max(1, min(length(ip), round(linspace(1 + d, length(ip) - 30 + d, 10)))));
% SoC verdadeiro: faixa larga e clara, desenhada primeiro
h(1) = plot(s.t_min(ip), 100*s.Soc_ref(ip), '-', 'Color', cor.ref, 'LineWidth', 2.0);
% CC: tracejada com quadrados
h(2) = plot(s.t_min(ip), 100*s.Soc_cc(ip), '--', 'Color', cor.cc, 'LineWidth', 0.8, 'Marker', 's', 'MarkerSize', 3, 'MarkerFaceColor', cor.cc, 'MarkerIndices', im(0));
% EKF: traco-ponto com circulos
h(3) = plot(s.t_min(ip), 100*s.Soc_ekf(ip), '-.', 'Color', cor.ekf, 'LineWidth', 0.8, 'Marker', 'o', 'MarkerSize', 3, 'MarkerFaceColor', cor.ekf, 'MarkerIndices', im(10));
% FP: continua com triangulos, desenhada por ultimo (a mais fina)
h(4) = plot(s.t_min(ip), 100*s.Soc_fp(ip), '-', 'Color', cor.fp, 'LineWidth', 0.6, 'Marker', '^', 'MarkerSize', 3, 'MarkerFaceColor', cor.fp, 'MarkerIndices', im(20));
end

function plotar_erro(s, ip, cor)
% desenha o erro (estimado - verdadeiro) de CC, EKF e FP com a faixa de +-2 p.p.
% marcadores: ~10 por curva, deslocados entre as curvas
im = @(d) unique(max(1, min(length(ip), round(linspace(1 + d, length(ip) - 30 + d, 10)))));
% faixa de +-2 p.p. (criterio de convergencia)
yline([-2 2], ':k', 'LineWidth', 0.6);
% erro da CC
plot(s.t_min(ip), 100*(s.Soc_cc(ip) - s.Soc_ref(ip)), '--', 'Color', cor.cc, 'LineWidth', 0.8, 'Marker', 's', 'MarkerSize', 3, 'MarkerFaceColor', cor.cc, 'MarkerIndices', im(0));
% erro do EKF
plot(s.t_min(ip), 100*(s.Soc_ekf(ip) - s.Soc_ref(ip)), '-.', 'Color', cor.ekf, 'LineWidth', 0.8, 'Marker', 'o', 'MarkerSize', 3, 'MarkerFaceColor', cor.ekf, 'MarkerIndices', im(10));
% erro do FP, por ultimo
plot(s.t_min(ip), 100*(s.Soc_fp(ip) - s.Soc_ref(ip)), '-', 'Color', cor.fp, 'LineWidth', 0.6, 'Marker', '^', 'MarkerSize', 3, 'MarkerFaceColor', cor.fp, 'MarkerIndices', im(20));
end

function estilo_painel(titulo, rotulo_x, rotulo_y)
% aplica o estilo do projeto e deixa o titulo do painel pequeno, como nos artigos
aplicar_estilo_artigo(titulo, rotulo_x, rotulo_y);
% titulo do painel em 9 pt, sem negrito, alinhado a esquerda
title(titulo, 'FontName', 'Times New Roman', 'FontSize', 9, 'FontWeight', 'normal', 'Color', 'k');
% alinha o titulo a esquerda
set(gca, 'TitleHorizontalAlignment', 'left');
% numeros dos eixos em 8 pt (cabem na coluna)
set(gca, 'FontSize', 8);
% rotulos dos eixos em 9 pt
set(get(gca, 'XLabel'), 'FontSize', 9); set(get(gca, 'YLabel'), 'FontSize', 9);
end

function folga_y(f)
% abre o eixo y em uma fracao f para nenhuma curva encostar na moldura
yl = ylim; ylim(yl + [-1 1]*f*diff(yl));
end

function salvar_fig(fig, pasta, nome, tam_cm)
% janela solta (nao encaixada no MATLAB), senao o tamanho nao vale
set(fig, 'WindowStyle', 'normal');
% volta ao tamanho da coluna antes de salvar (se a janela foi mexida)
set(fig, 'Units', 'centimeters', 'Position', [2 2 tam_cm]);
% atualiza a figura com o tamanho novo
drawnow;
% fundo branco na figura
set(fig, 'Color', 'w');
% PDF vetorial para o artigo
exportgraphics(fig, fullfile(pasta, [nome '.pdf']), 'ContentType', 'vector', 'BackgroundColor', 'white');
% PNG 300 dpi para os slides
exportgraphics(fig, fullfile(pasta, [nome '.png']), 'Resolution', 300, 'BackgroundColor', 'white');
end
