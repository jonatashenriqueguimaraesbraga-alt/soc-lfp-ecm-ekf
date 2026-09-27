% SALVAR FIGURAS - salva todas as figuras abertas em PDF vetorial (artigo) e PNG (visualização)
% Nome do arquivo = número da figura + título do gráfico (do subplot de cima, quando houver vários)

pasta = fullfile(pwd, 'resultados ekf');                    % Pasta de destino relativa à pasta atual (funciona em qualquer PC)
if ~exist(pasta, 'dir'), mkdir(pasta); end                  % Cria a pasta se ela não existir

figs = findobj('Type', 'figure');                           % Pega todas as figuras abertas
[~, ordem] = sort([figs.Number]);                           % Ordena pelo número da figura (1, 2, 3...)
figs = figs(ordem);                                         % Aplica a ordenação

for f = 1:numel(figs)                                       % Loop por todas as figuras
    eixos = flipud(findobj(figs(f), 'Type', 'axes'));       % Eixos na ordem de criação (o 1º é o subplot de cima)
    if isempty(eixos), titulo = ''; else, titulo = eixos(1).Title.String; end   % Título do primeiro gráfico da figura
    if iscell(titulo), titulo = strjoin(titulo, ' '); end   % Títulos de várias linhas viram uma linha só
    titulo = strrep(titulo, ':', ' -');                     % ':' não é permitido em nome de arquivo no Windows
    titulo = regexprep(titulo, '[\\/*?"<>|{}_^]', '');      % Remove outros caracteres proibidos e os de formatação TeX (ex.: Q_{11} -> Q11)
    titulo = strtrim(regexprep(titulo, '\s+', ' '));        % Remove espaços duplicados
    if isempty(titulo), titulo = 'sem titulo'; end          % Segurança: figura sem título
    nome = fullfile(pasta, sprintf('%02d - %s', figs(f).Number, titulo));   % Caminho + "01 - Título"
    exportgraphics(figs(f), [nome '.pdf'], 'ContentType', 'vector');       % PDF vetorial (para o artigo)
    exportgraphics(figs(f), [nome '.png'], 'Resolution', 200);             % PNG (para visualizar/mandar)
end
fprintf('%d figuras salvas em: %s\n', numel(figs), pasta);  % Confirma no Command Window
