% FIGURAS DOS SLIDES - rodar DEPOIS do main.m (usa as variaveis do workspace)
% Slide 6: (cima) corrente do perfil HPPC; (baixo) erros do sensor de corrente, separados (ruido e bias)
% Slide 9: mesmos graficos do artigo (SoC e erro do SoC, caso 90%), com fonte para projetor
% Tamanho e fontes pensados para projecao (metade do slide)

pasta_slides = fullfile(pwd, 'resultados ekf', 'slides');     % Pasta de saida relativa a pasta atual
if ~exist(pasta_slides, 'dir'), mkdir(pasta_slides); end      % Cria a pasta se ela nao existir

% ===================== FIG. DO SLIDE 6: perfil HPPC e erros do sensor de corrente =====================
passo_plot_erro = 9000;                                        % Plota 1 a cada 9000 pontos (300 pontos: ruido visivel sem poluir)
idx_plot_erro = 1:passo_plot_erro:N;                           % Indices espacados para os pontos do ruido
larg_s = 15; alt_s = 13;                                       % Tamanho da figura em cm (metade do slide)

fig_hppc = figure('WindowStyle', 'normal', 'Units', 'centimeters', 'Position', [2 2 larg_s alt_s]);  % Janela solta (nao encaixada), no tamanho final
theme(fig_hppc, 'light');                                      % Forca o tema claro (o MATLAB com tema escuro deixa o fundo preto)

% --- Painel de cima: corrente do perfil HPPC ---
subplot(2,1,1);                                                % Painel de cima
plot(t(idx_plot), I(idx_plot), 'k-', 'LineWidth', 1.5);        % Corrente real (sem erro), preto
aplicar_estilo_artigo('', 'Tempo (min)', 'Corrente (A)');      % Padrao visual do projeto, sem titulo
set(gca, 'FontSize', 14);                                      % Numeros dos eixos em 14 pt (legivel no projetor)
set(get(gca, 'XLabel'), 'FontSize', 16);                       % Rotulo do eixo x em 16 pt
set(get(gca, 'YLabel'), 'FontSize', 16);                       % Rotulo do eixo y em 16 pt
xlim([0 max(t)]);                                              % Eixo x do inicio ao fim do ensaio
ylim([-0.2 1.8]);                                              % Folga acima do pulso de 1,462 A

% --- Painel de baixo: erros do sensor de corrente ---
subplot(2,1,2);                                                % Painel de baixo
plot(t(idx_plot_erro), ruido_corrente(idx_plot_erro) * 1000, 'r.', 'MarkerSize', 6);  % Ruido gaussiano sozinho (mA), pontos vermelhos
hold on;                                                       % Sobrepoe a proxima curva
plot(t(idx_plot), I_bias(idx_plot) * 1000, 'k-', 'LineWidth', 3);            % Bias sozinho (mA), linha preta grossa
xline(t(round(N/2)), 'k:', 'LineWidth', 1.5, 'HandleVisibility', 'off');     % Inicio do bias (450 min), fora da legenda
hold off;                                                      % Libera o grafico
aplicar_estilo_artigo('', 'Tempo (min)', 'Erro da corrente (mA)');           % Padrao visual do projeto, sem titulo
set(gca, 'FontSize', 14);                                      % Numeros dos eixos em 14 pt
set(get(gca, 'XLabel'), 'FontSize', 16);                       % Rotulo do eixo x em 16 pt
set(get(gca, 'YLabel'), 'FontSize', 16);                       % Rotulo do eixo y em 16 pt
xlim([0 max(t)]);                                              % Mesmo eixo x do painel de cima
ylim([-60 80]);                                                % Espaco livre em cima para a legenda
lgd = legend('Ruído gaussiano', 'Bias', 'Location', 'north', 'Orientation', 'horizontal');  % Legenda em uma linha, no topo
set(lgd, 'FontName', 'Times New Roman', 'FontSize', 14, 'TextColor', 'k', 'Color', 'w', 'EdgeColor', 'k');  % Estilo da legenda

exportgraphics(fig_hppc, fullfile(pasta_slides, 'slide6_hppc_erro.pdf'), 'ContentType', 'vector');  % PDF vetorial
exportgraphics(fig_hppc, fullfile(pasta_slides, 'slide6_hppc_erro.png'), 'Resolution', 300);        % PNG em alta resolucao (vai para o slide)

% ===================== FIGS. DO SLIDE 9: mesmos graficos do artigo, com fonte para projetor =====================
i90 = find(abs(lista_Soc0_est - 0.9) < 1e-9);              % Linha da condicao inicial de 90% (erro de 10%)
s1  = (i90-1)*n_q + 1;                                     % Cenario EKF com Q11 da Tabela 11
s2  = (i90-1)*n_q + 2;                                     % Cenario EKF com Q11 alternativo
verde = [0 0.6 0];                                         % Verde escuro (mesma cor do artigo)
larg_r = 15; alt_r = 11;                                   % Tamanho de cada figura em cm (metade do slide)

% --- SoC: verdadeiro x CC x EKF (caso 90%) ---
fig_soc_s = figure('WindowStyle', 'normal', 'Units', 'centimeters', 'Position', [2 2 larg_r alt_r]);  % Janela solta, tamanho final
theme(fig_soc_s, 'light');                                                   % Forca o tema claro (fundo branco)
plot(t(idx_plot), Soc(idx_plot)*100, 'k-', 'LineWidth', 2);                  % SoC verdadeiro, em %
hold on;                                                                     % Sobrepoe as proximas curvas
plot(t(idx_plot), Soc_cc(i90,idx_plot)*100, 'r--', 'LineWidth', 2);          % CC, em %
plot(t(idx_plot), Soc_ekf(s1,idx_plot)*100, 'b-', 'LineWidth', 2);           % EKF com Q11 da Tabela 11, em %
plot(t(idx_plot), Soc_ekf(s2,idx_plot)*100, '-', 'Color', verde, 'LineWidth', 2);  % EKF com Q11 alternativo, em %
hold off;                                                                    % Libera o grafico
aplicar_estilo_artigo('', 'Tempo (min)', 'SoC (%)');                         % Padrao visual do projeto, sem titulo
set(gca, 'FontSize', 14);                                                    % Numeros dos eixos em 14 pt
set(get(gca, 'XLabel'), 'FontSize', 16);                                     % Rotulo do eixo x em 16 pt
set(get(gca, 'YLabel'), 'FontSize', 16);                                     % Rotulo do eixo y em 16 pt
xlim([0 max(t)]);                                                            % Eixo x do inicio ao fim do ensaio
lgd = legend('SoC verdadeiro', 'CC', 'EKF (Q_{11} da ref.)', 'EKF (Q_{11} alternativo)', 'Location', 'southwest');  % Legenda
set(lgd, 'FontName', 'Times New Roman', 'FontSize', 13, 'TextColor', 'k', 'Color', 'w', 'EdgeColor', 'k');          % Estilo da legenda
exportgraphics(fig_soc_s, fullfile(pasta_slides, 'slide9_soc_90.png'), 'Resolution', 300);   % PNG em alta resolucao

% --- Erro do SoC (caso 90%) ---
fig_erro_s = figure('WindowStyle', 'normal', 'Units', 'centimeters', 'Position', [18 2 larg_r alt_r]);  % Janela solta, tamanho final
theme(fig_erro_s, 'light');                                                  % Forca o tema claro (fundo branco)
plot(t(idx_plot), (Soc_cc(i90,idx_plot) - Soc(idx_plot))*100, 'r--', 'LineWidth', 2);             % Erro da CC
hold on;                                                                                           % Sobrepoe as proximas curvas
plot(t(idx_plot), (Soc_ekf(s1,idx_plot) - Soc(idx_plot))*100, 'b-', 'LineWidth', 2);              % Erro do EKF (Q11 da Tabela 11)
plot(t(idx_plot), (Soc_ekf(s2,idx_plot) - Soc(idx_plot))*100, '-', 'Color', verde, 'LineWidth', 2);  % Erro do EKF (Q11 alternativo)
yline(0, 'k-', 'LineWidth', 0.8, 'HandleVisibility', 'off');                                       % Linha de erro zero, fora da legenda
xline(t(round(N/2)), 'k:', 'LineWidth', 1.5, 'HandleVisibility', 'off');                           % Inicio do bias (450 min), sem rotulo proprio
text(t(round(N/2)) + 10, -7, 'início do bias', 'FontName', 'Times New Roman', 'FontSize', 13, 'Color', 'k');  % Rotulo na area livre (x = 460 min, y = -7%)
hold off;                                                                                          % Libera o grafico
aplicar_estilo_artigo('', 'Tempo (min)', 'Erro do SoC (%)');                % Padrao visual do projeto, sem titulo
set(gca, 'FontSize', 14);                                                    % Numeros dos eixos em 14 pt
set(get(gca, 'XLabel'), 'FontSize', 16);                                     % Rotulo do eixo x em 16 pt
set(get(gca, 'YLabel'), 'FontSize', 16);                                     % Rotulo do eixo y em 16 pt
xlim([0 max(t)]);                                                            % Eixo x do inicio ao fim do ensaio
lgd = legend('CC', 'EKF (Q_{11} da ref.)', 'EKF (Q_{11} alternativo)', 'Location', 'southwest');   % Legenda
set(lgd, 'FontName', 'Times New Roman', 'FontSize', 13, 'TextColor', 'k', 'Color', 'w', 'EdgeColor', 'k');  % Estilo da legenda
exportgraphics(fig_erro_s, fullfile(pasta_slides, 'slide9_erro_90.png'), 'Resolution', 300);   % PNG em alta resolucao

fprintf('Figuras dos slides 6 e 9 salvas em: %s\n', pasta_slides);          % Confirma no Command Window
