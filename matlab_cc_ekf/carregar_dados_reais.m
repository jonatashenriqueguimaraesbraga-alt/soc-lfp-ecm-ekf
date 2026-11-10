% CARREGAR DADOS REAIS - substitui o simulacao_dados.m quando o professor passar os ensaios do laboratório (fase do artigo)
% AINDA NÃO TESTADO (não há dados). Ajustes na seção 8 do configuracao.m; no main.m, usar fonte_dados = 'real'
%
% "Contrato": este script entrega EXATAMENTE as mesmas variáveis de MEDIÇÃO que o simulacao_dados.m, então
% cc_bat, ekf_bat, resultados_ekf e exportar_csv (e a LSTM) rodam sem nenhuma mudança:
%   t_med (min), N_med, I_medido (A), Vt_medido (V), Soc_ref (fração), Soc0, nome_perfil, rotulo_perfil, idx_plot_med
%
% Diferenças em relação à simulação (vão para a discussão do artigo):
%   - Não existe SoC verdadeiro: a referência é a CC sobre a corrente do equipamento do laboratório, como na
%     dissertação (p. 100), integrada nos dados brutos (10 ms) a partir de um SoC inicial conhecido (Soc0_dados_reais).
%   - Por isso, se os estimadores recebessem a MESMA corrente da referência, a CC daria RMSE = 0. Para avaliar,
%     somam-se os erros dos cenários 'ref_bias' e 'ref_ruido', como a referência fez (Seç. 3.2.7). No 'nominal', a CC dá RMSE ≈ 0.
%   - Agora existe erro de modelo de verdade (histerese, temperatura, 3 ramos RC na célula real): é aqui que a
%     comparação EKF × LSTM ganha o maior peso científico.

parametros_bat;                                           % Modelo que os estimadores conhecem (Tabela 7) e a struct bat
if isempty(arquivo_dados_reais)                           % Ainda sem arquivo definido no configuracao.m
    error('Defina arquivo_dados_reais no configuracao.m (seção 8).');
end

% --- Leitura dos dados brutos ---
dados_reais = readtable(arquivo_dados_reais);             % Lê o .csv do laboratório
t_bruto_s = dados_reais.(coluna_tempo)';                  % Tempo bruto (s), vetor linha
I_bruto = sinal_descarga_real * dados_reais.(coluna_corrente)';   % Corrente bruta (A), na convenção deste código (descarga positiva)
V_bruto = dados_reais.(coluna_tensao)';                   % Tensão bruta (V)
t_bruto_s = t_bruto_s - t_bruto_s(1);                     % Tempo começando em zero

% --- Referência: CC "de laboratório" sobre os dados brutos (integração trapezoidal da corrente do equipamento) ---
Soc_bruto = Soc0_dados_reais - eta * cumtrapz(t_bruto_s, I_bruto) / Cn;   % SoC de referência a cada amostra bruta

% --- Reamostragem para Ts_med (média em blocos, como uma leitura de sensor; preserva a carga da corrente) ---
bloco = floor(t_bruto_s / Ts_med) + 1;                    % Número do bloco de Ts_med a que cada amostra bruta pertence
I_amostrado = accumarray(bloco', I_bruto', [], @mean)';   % Corrente média em cada bloco
Vt_amostrado = accumarray(bloco', V_bruto', [], @mean)';  % Tensão média em cada bloco
Soc_ref = accumarray(bloco', Soc_bruto', [], @(v) v(1))'; % Referência no início de cada bloco
N_med = length(I_amostrado);                              % Número de medições
t_med = (0:N_med-1) * Ts_med / 60;                        % Instantes das medições (min)
Soc0 = Soc0_dados_reais;                                  % SoC inicial real (conhecido pelo protocolo do ensaio)
[~, nome_arquivo] = fileparts(arquivo_dados_reais);       % Nome do arquivo sem pasta e extensão
nome_perfil = ['Real - ' nome_arquivo];                   % Nome usado nos títulos
rotulo_perfil = ['real_' nome_arquivo];                   % Nome usado nos arquivos de saída
ordem_planta = 0;                                         % Não há planta simulada: 0 marca "dados reais" nas tabelas de métricas

% --- Entrada dos estimadores ---
semente_rng = semente_sensor;                             % Mesma semente dos perfis de validação
ruido_base_ativo = false;                                 % O ruído de base já está na medição real: só os erros do cenário são somados
sensores_simulados;                                       % Gera I_medido e Vt_medido (no 'nominal', iguais aos do equipamento)

% --- Checagem física (Tabela 5) e índices de plotagem ---
if any(Vt_amostrado < V_corte_desc)                       % Ensaio passou do corte (pode ser o fim da descarga)
    fprintf('AVISO: Vt < %.1f V em %.2f%% do ensaio real.\n', V_corte_desc, 100*mean(Vt_amostrado < V_corte_desc));
end
idx_plot_med = 1:max(1, round(N_med/2000)):N_med;         % Cerca de 2000 pontos nos gráficos
fprintf('Dados reais %s: %.1f min, %d medições a cada %g s\n', nome_arquivo, t_med(end), N_med, Ts_med);   % Resumo
