function aplicar_estilo_artigo(titulo_str, xlabel_str, ylabel_str)
% aplicar_estilo_artigo: aplica o padrão visual de gráficos do projeto (estilo artigo/journal)
% Uso: chame essa função logo depois do plot(...), passando título e rótulos dos eixos
% Ex: aplicar_estilo_artigo('Meu título', 'Tempo (min)', 'Tensão (V)')
set(gcf, 'Color', 'w');                                   % Fundo da figura (janela): branco
set(gca, 'Color', 'w');                                   % Fundo da área do gráfico: branco
set(gca, 'XColor', 'k', 'YColor', 'k');                    % Cor dos eixos e números: preto
set(gca, 'LineWidth', 1);                                  % Espessura da moldura/eixos (padrão de impressão)
set(gca, 'FontName', 'Times New Roman', 'FontSize', 10);   % Fonte dos números dos eixos
title(titulo_str, 'FontName', 'Times New Roman', 'FontSize', 12, 'Color', 'k');    % Título, forçado em preto
xlabel(xlabel_str, 'FontName', 'Times New Roman', 'FontSize', 11, 'Color', 'k');   % Rótulo eixo x, preto
ylabel(ylabel_str, 'FontName', 'Times New Roman', 'FontSize', 11, 'Color', 'k');   % Rótulo eixo y, preto
grid on;                                                    % Ativa grade
box on;                                                     % Moldura fechada nos 4 lados (padrão IEEE/journal)
end
