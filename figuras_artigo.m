% FIGURAS DO ARTIGO (Figs. 2 e 3) - rodar DEPOIS do main.m (usa as variaveis do workspace)
% Fig. 2: SoC verdadeiro x CC x EKF (dois Q11), SoC inicial assumido de 90%
% Fig. 3: erro do SoC (estimado - verdadeiro) da CC e dos dois EKF, mesmo caso
% Formato IEEE: largura de uma coluna (8,8 cm), sem titulo interno, PDF vetorial

pasta_artigo = fullfile(pwd, 'resultados ekf', 'artigo');  % Pasta de saida relativa a pasta atual (funciona em qualquer PC)
if ~exist(pasta_artigo, 'dir'), mkdir(pasta_artigo); end   % Cria a pasta se ela nao existir

i90 = find(abs(lista_Soc0_est - 0.9) < 1e-9);              % Linha da condicao inicial de 90% (erro de 10%)
s1  = (i90-1)*n_q + 1;                                     % Cenario EKF com Q11 da Tabela 11
s2  = (i90-1)*n_q + 2;                                     % Cenario EKF com Q11 alternativo
verde = [0 0.6 0];                                         % Verde escuro (o verde puro some na impressao)
larg = 8.8; alt = 6.0;                                     % Tamanho da figura em cm (largura de uma coluna IEEE)

% ===================== FIG. 2: SoC =====================
fig2 = figure('Units', 'centimeters', 'Position', [2 2 larg alt]);         % Figura no tamanho final do artigo
plot(t(idx_plot), Soc(idx_plot)*100, 'k-', 'LineWidth', 1.2);              % SoC verdadeiro, em %
hold on;                                                                   % Sobrepoe as proximas curvas
plot(t(idx_plot), Soc_cc(i90,idx_plot)*100, 'r--', 'LineWidth', 1);        % CC, em %
plot(t(idx_plot), Soc_ekf(s1,idx_plot)*100, 'b-', 'LineWidth', 1);         % EKF com Q11 da Tabela 11, em %
plot(t(idx_plot), Soc_ekf(s2,idx_plot)*100, '-', 'Color', verde, 'LineWidth', 1);  % EKF com Q11 alternativo, em %
hold off;                                                                  % Libera o grafico
aplicar_estilo_artigo('', 'Tempo (min)', 'SoC (%)');                       % Padrao visual do projeto, sem titulo
set(gca, 'FontSize', 8);                                                   % Numeros dos eixos em 8 pt (legivel em uma coluna)
set(get(gca, 'XLabel'), 'FontSize', 9);                                    % Rotulo do eixo x em 9 pt
set(get(gca, 'YLabel'), 'FontSize', 9);                                    % Rotulo do eixo y em 9 pt
xlim([0 max(t)]);                                                          % Eixo x do inicio ao fim do ensaio
lgd = legend('SoC verdadeiro', 'CC', 'EKF (Q_{11} da ref.)', 'EKF (Q_{11} alternativo)', 'Location', 'southwest');  % Legenda
set(lgd, 'FontName', 'Times New Roman', 'FontSize', 7, 'TextColor', 'k', 'Color', 'w', 'EdgeColor', 'k');          % Estilo da legenda
exportgraphics(fig2, fullfile(pasta_artigo, 'fig2_soc_90.pdf'), 'ContentType', 'vector');   % PDF vetorial para o artigo
exportgraphics(fig2, fullfile(pasta_artigo, 'fig2_soc_90.png'), 'Resolution', 300);         % PNG para conferir/mandar

% ===================== FIG. 3: erro do SoC =====================
fig3 = figure('Units', 'centimeters', 'Position', [12 2 larg alt]);        % Figura no tamanho final do artigo
plot(t(idx_plot), (Soc_cc(i90,idx_plot) - Soc(idx_plot))*100, 'r--', 'LineWidth', 1);            % Erro da CC, em pontos percentuais
hold on;                                                                                           % Sobrepoe as proximas curvas
plot(t(idx_plot), (Soc_ekf(s1,idx_plot) - Soc(idx_plot))*100, 'b-', 'LineWidth', 1);              % Erro do EKF com Q11 da Tabela 11
plot(t(idx_plot), (Soc_ekf(s2,idx_plot) - Soc(idx_plot))*100, '-', 'Color', verde, 'LineWidth', 1);  % Erro do EKF com Q11 alternativo
yline(0, 'k-', 'LineWidth', 0.5, 'HandleVisibility', 'off');                                       % Linha de erro zero (fora da legenda)
xline(t(round(N/2)), 'k:', 'início do bias', 'LineWidth', 1, 'HandleVisibility', 'off', ...                  % Inicio do bias (metade do ensaio, 450 min), com rotulo proprio
      'LabelVerticalAlignment', 'bottom', 'LabelHorizontalAlignment', 'right', 'LabelOrientation', 'horizontal', ... % Rotulo embaixo, a direita da linha (area vazia, longe da CC e da legenda)
      'FontName', 'Times New Roman', 'FontSize', 7);                                                   % Mesma fonte da legenda (o rotulo herda a cor preta da linha)
hold off;                                                                                          % Libera o grafico
aplicar_estilo_artigo('', 'Tempo (min)', 'Erro do SoC (%)');               % Padrao visual do projeto, sem titulo
set(gca, 'FontSize', 8);                                                   % Numeros dos eixos em 8 pt
set(get(gca, 'XLabel'), 'FontSize', 9);                                    % Rotulo do eixo x em 9 pt
set(get(gca, 'YLabel'), 'FontSize', 9);                                    % Rotulo do eixo y em 9 pt
xlim([0 max(t)]);                                                          % Eixo x do inicio ao fim do ensaio
lgd = legend('CC', 'EKF (Q_{11} da ref.)', 'EKF (Q_{11} alternativo)', 'Location', 'southwest');   % Legenda
set(lgd, 'FontName', 'Times New Roman', 'FontSize', 7, 'TextColor', 'k', 'Color', 'w', 'EdgeColor', 'k');  % Estilo da legenda
exportgraphics(fig3, fullfile(pasta_artigo, 'fig3_erro_90.pdf'), 'ContentType', 'vector');   % PDF vetorial para o artigo
exportgraphics(fig3, fullfile(pasta_artigo, 'fig3_erro_90.png'), 'Resolution', 300);         % PNG para conferir/mandar

fprintf('Figuras do artigo salvas em: %s\n', pasta_artigo);               % Confirma no Command Window
