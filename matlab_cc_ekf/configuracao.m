% CONFIGURAÇÃO GERAL - todos os números "ajustáveis" do trabalho ficam AQUI
% Rodado pelo main.m e pelo gerar_dados_lstm.m. Mudou um valor aqui, muda em todos os scripts.
% O que NÃO fica aqui: os parâmetros da bateria (Tabelas 5, 6 e 7, em parametros_bat.m) e a escolha do perfil (no main.m)
%
% Desenho do experimento (igual à cadeia da referência: aquisição a 10 ms, p. 57 → reamostragem a 1 s, p. 69):
%   PLANTA (bateria "verdadeira", passo fino Ts) → SENSORES (amostram a cada Ts_med, com erros) → ESTIMADORES (CC, EKF e LSTM, todos a cada Ts_med)
%   Os três métodos recebem exatamente as mesmas medições e são avaliados nos mesmos instantes.

% =====================================================================
% 0) MODO
% =====================================================================
modo_config = 'AF';                % 'AF' = desenho final (sensores e estimadores a 1 s, como a referência) | 'AP' = reproduz a apresentação parcial (tudo a 0,02 s, Euler)

% =====================================================================
% 1) PLANTA (a bateria simulada que gera a "verdade")
% =====================================================================
Ts = 0.02;                         % Passo da planta (s): fino, faz o papel da aquisição contínua (a referência adquiriu a 10 ms)
discretizacao_planta = 'exata';    % Ramo RC da planta: 'exata' (exponencial, solução da EDO) ou 'euler' (equação do resumo estendido)
ordem_planta = 3;                  % Ramos RC da planta. 3 = Tabela 7 completa: o modelo que a referência identificou nos ensaios da célula real
                                   % (FIT de 92,5% a 20 °C), usado aqui como a "célula". O EKF usa só R0, R1 e C1 dessa tabela, como na referência
                                   % (p. 70: "o EKF utiliza apenas um dos três ramos identificados no modelo completo"; p. 79). 1 = só para o modo 'AP'
V1_0 = 0;                          % Tensão inicial no capacitor C1 (V): célula em repouso no início de todos os perfis
% --- Erro de modelo extra (SÓ para análise de sensibilidade; cada valor diferente de 1/0 precisa de justificativa no artigo) ---
fator_R0_planta = 1;               % R0 da planta = fator × R0 da Tabela 7 (ex.: 1.1 = resistência 10% maior, célula envelhecida)
fator_R1_planta = 1;               % R1 (e R2, R3 na planta de 3ª ordem) = fator × Tabela 7
fator_C1_planta = 1;               % C1 (e C2, C3 na planta de 3ª ordem) = fator × Tabela 7
fator_Cn_planta = 1;               % Capacidade da planta = fator × Cn (ex.: 0.95 = 5% de perda de capacidade)
desvio_OCV_planta = 0;             % Desvio somado à OCV da planta (V) (ex.: 0.005 = 5 mV, efeito parecido com histerese)

% =====================================================================
% 2) MEDIÇÃO E ESTIMADORES
% =====================================================================
Ts_med = 1;                        % Período de amostragem dos sensores = passo da CC, do EKF e da LSTM (s). 1 s = reamostragem da referência (p. 69)
discretizacao_est = 'exata';       % Ramo RC no EKF: com Ts_med = 1 s, Euler é instável (exige Ts < 2·R1·C1 = 0,48 s); a referência usa a forma exata (Eqs. 3.5-3.6)

% =====================================================================
% 3) SENSORES SIMULADOS (iguais para todos os perfis)
% =====================================================================
% Todo cenário tem o RUÍDO DE BASE de um sensor real (uma medição nunca tem ruído zero); os erros da referência entram POR CIMA,
% como a referência fez sobre os dados medidos (Seç. 3.2.7). Sem ruído de base, o EKF que começa em 90% (onde dOCV/dSoC = 0 na Tab. 7)
% fica parado no repouso inicial e diverge (teste de 31/10: RMSE de 53%) - situação que não existe com um sensor real.
cenario_sensor = 'nominal';        % Erros na CORRENTE: 'nominal' (só ruído de base = "dados medidos", Tab. 12) |
                                   % 'ref_bias' (+ 0,15 A na 2ª metade, linha "Bias" das Tabs. 14 e 15) | 'ref_ruido' (+ variância 0,2 A², linha "Média zero") |
                                   % 'proprio' (+ bias de 1% do fundo de escala; só para reproduzir a AP). Erro inicial de 10% = lista_erro_Soc0 (seção 4)
semente_sensor = 1;                % Semente dos ruídos de sensor (somada à semente do perfil aleatório; 1 = mesma da AP)
inicio_bias = 0.5;                 % Fração do ensaio em que o bias começa (0.5 = segunda metade, como na referência, p. 81)
% --- Ruído de base (sensor comercial) ---
I_ref_sensor_C = 1;                % Fundo de escala do sensor de corrente, em múltiplos de 1C (1C = Cn/3600 = 1,462 A). Fixo: é do sensor, não do perfil
percentual_ruido = 0.01;           % Ruído de base: desvio de 1% do fundo de escala (~15 mA; Chemali et al., 2018: sensor com erro < 25 mA)
percentual_bias = 0.01;            % Bias de 1% do fundo de escala (só no cenário 'proprio', o da AP)
% --- Cenários da referência (Seç. 3.2.7, p. 81) ---
bias_ref_A = 0.15;                 % Bias de 0,15 A na segunda metade dos dados
var_ruido_ref = 0.2;               % Ruído branco de variância 0,2 A² (desvio de 0,447 A), somado ao de base a cada amostra de Ts_med (a referência não diz o período)
% --- Sensor de tensão (todos os cenários; nos dados reais o ruído já vem da medição) ---
sigma_v = sqrt(8) / 1000;          % Desvio padrão do ruído de tensão (V). HIPÓTESE: igual ao R_k da Tabela 11 (8 mV²); a referência não informa o ruído real do sensor

% =====================================================================
% 4) ESTIMADORES (CC e EKF) - valores da Tabela 11 (20 °C) convertidos para fração e volt
% =====================================================================
lista_erro_Soc0 = [0, -0.10];      % Erro do SoC inicial ASSUMIDO em relação ao real: 0 = sem erro; -0.10 = começa 10% abaixo (Tabs. 14 e 15)
P0_Soc = 0.95/100^2;               % P(1,1) inicial: 0,95 %² → fração²
P0_V1  = 8/1000^2;                 % P(2,2) inicial: 8 mV² → V²
Q11_tab = 9.99e-10/100^2;          % Q(1,1) da Tabela 11: %² → fração² (por segundo; o ekf_bat multiplica por Ts_med)
Q11_alt = 1e-10;                   % Q(1,1) alternativo (ajustado no HPPC na AP; nos perfis de validação é teste fora da amostra de ajuste)
Q22 = 10/1000^2;                   % Q(2,2) da Tabela 11: 10 mV² → V² (por segundo)
R_ekf = 8/1000^2;                  % R do EKF: 8 mV² da Tabela 11 → V². Separado do sigma_v: o filtro usa o valor da referência, não o ruído "verdadeiro" da simulação
% Resultado PRINCIPAL = EKF com Q11_tab (valores da referência). Q11_alt = análise de sensibilidade (foi ajustado com o SoC verdadeiro do HPPC, informação que um BMS não tem)

% =====================================================================
% 5) AVALIAÇÃO (a mesma régua para CC, EKF e LSTM)
% =====================================================================
t_inicio_avaliacao_min = 0;        % Métricas desde o início (min) para os três métodos: a LSTM deve estimar desde t = 0 (janela completada com a 1ª amostra),
                                   % senão o período de convergência do EKF ficaria fora da conta
limiar_conv = 0.02;                % Faixa de convergência (fração): tempo de convergência = quando o erro entra em ±2 p.p. e não sai mais (definição deste trabalho)

% =====================================================================
% 6) PERFIL ALEATÓRIO (treino e validação da LSTM) - criação deste trabalho, não vem da dissertação
% =====================================================================
niveis_descarga_ale = 0.25:0.25:2.75;  % Correntes de descarga sorteadas (A): faixa de operação da célula, até 2C = 2,8 A (Tab. 5) - escolhida pela especificação, não pelos perfis de teste
prob_repouso_ale = 0.25;               % Chance de cada degrau ser repouso (I = 0)
dur_min_ale = 30;                      % Duração mínima de cada degrau (s)
dur_max_ale = 600;                     % Duração máxima de cada degrau (s)
Soc_final_ale = 0.05;                  % O perfil para em 5% de SoC: abaixo disso, correntes altas levam Vt abaixo do corte de 2,5 V (Tab. 5; R1 = 0,338 Ω em 0%). O HPPC cobre 5-0% a 1C
dur_repouso_final_ale = 600;           % Repouso no fim do perfil (s), para a rede ver a relaxação em SoC baixo
% --- Degraus rápidos (só nos perfis novos da versão 10, gerar_dados_lstm_v10.m): dinâmica parecida com a dos ciclos de condução ---
dur_min_ale_rapido = 2;                % Duração mínima de cada degrau rápido (s)
dur_max_ale_rapido = 60;               % Duração máxima de cada degrau rápido (s) (os ciclos DST, US06 e FUDS mudam a corrente a cada poucos segundos)

% =====================================================================
% 6b) PERFIS PADRÃO DE CONDUÇÃO (DST, US06, FUDS) - corrente de dados públicos (CALCE, célula A123 LFP de 1,1 Ah, 20 °C, 1 s)
% =====================================================================
% Só a CORRENTE vem do banco público; a tensão e o SoC saem da NOSSA planta (Tabela 7), como em todos os perfis.
% Arquivos com 1 ciclo de cada perfil (extraídos do ensaio A1-007-DST-US06-FUDS-20-20120817.xlsx; descarga positiva), na pasta abaixo.
% O ciclo é repetido desde a carga completa até Soc_final_ale (5%), seguido do repouso final (dur_repouso_final_ale), como os perfis aleatórios.
pasta_perfis_padrao = 'perfis_padrao';                     % Pasta (dentro da pasta do MATLAB) com os ciclos .csv
arquivo_ciclo_dst  = 'ciclo_DST_CALCE_A123_20C.csv';       % DST (USABC): ciclo de 360 s
arquivo_ciclo_us06 = 'ciclo_US06_CALCE_A123_20C.csv';      % US06 (estrada, agressivo): ciclo de 600 s
arquivo_ciclo_fuds = 'ciclo_FUDS_CALCE_A123_20C.csv';      % FUDS (urbano): ciclo de 1372 s
I_pico_calce = 3.85;               % Pico de descarga dos três perfis no ensaio CALCE (A; célula de 1,1 Ah = 3,5C)
I_pico_padrao = 2.8;               % Pico na nossa célula (A) = limite de 2C da Tab. 5 (I_max_desc). Os ciclos USABC são definidos em % da potência de pico da bateria
usar_regeneracao = false;          % false = pulsos de carga (frenagem) viram repouso: os parâmetros da referência foram identificados só em DESCARGA (HPPC e validação).
                                   % true = ciclos completos, com carga (só se o orientador pedir; o modelo seria usado fora da faixa identificada)

% =====================================================================
% 7) DADOS PARA A LSTM (gerar_dados_lstm.m)
% =====================================================================
passo_csv_s = 1;                                                   % Período do .csv (s): igual ao Ts_med (a LSTM vê as mesmas amostras que a CC e o EKF)
lista_perfis_lstm   = {'hppc', 'aleatorio', 'aleatorio', 'aleatorio', 'aleatorio', 'val100', 'val60'};   % Perfis exportados
lista_sementes_lstm = [0, 11, 12, 13, 21, 0, 0];                   % Semente de cada perfil (só o 'aleatorio' usa; 0 = não se aplica)
lista_papeis_lstm   = {'treino', 'treino', 'treino', 'treino', 'validacao', 'teste', 'teste'};   % Papel de cada arquivo na LSTM

% =====================================================================
% 7b) BATERIA DE TESTES (rodar_cenarios.m e arquivos de teste da LSTM): todas as combinações abaixo
% =====================================================================
lista_perfis_teste = {'val100', 'fuds', 'us06'};                 % Perfis de teste (versão 10, 03/11): val100 (referência, Fig. 26a) + FUDS e US06 (ciclos padrão, seção 6b).
                                                                   % O val60 (começo em 60%) fica para a fase com dados reais
lista_cenarios_sensor = {'nominal', 'ref_bias', 'ref_ruido'};    % Nominal (Tab. 12) + os cenários de erro da referência (Tabs. 14 e 15)
n_monte_carlo = 20;                % Sorteios de ruído por combinação (sementes 1 a 20). Resultado = média ± desvio padrão:
                                   % um único sorteio não representa o método (teste de 31/10: EKF com erro inicial no val100 variou de 1% a 7%)

% =====================================================================
% 7c) PERFIS EXTRA DA LSTM (gerar_dados_lstm_extra.m) - mais diversidade no treino e na validação (02/11)
% =====================================================================
% Motivo: com só 3 perfis aleatórios de treino, a LSTM decorou os perfis (RMSE de treino ~6%, validação 13-19%).
% Mais perfis diferentes = a única regra que serve para todos é contar a carga e corrigir com a tensão.
sementes_extra_treino_100 = 101:120;   % 20 perfis de TREINO que começam em 100% (sementes novas, não repetem as antigas)
sementes_extra_treino_soc = 121:140;   % 20 perfis de TREINO que começam num SoC sorteado (BMS ligado em qualquer SoC)
sementes_extra_val_100 = 201:203;      % 3 perfis de VALIDAÇÃO que começam em 100%
sementes_extra_val_soc = 204:206;      % 3 perfis de VALIDAÇÃO que começam num SoC sorteado
Soc0_min_ale = 0.20;                   % Menor SoC inicial sorteado (fração): sobra pelo menos 15% de descarga até o fim do perfil (5%)
                                       % Os perfis com SoC sorteado começam com a bateria em repouso (polarização zero), como depois de um descanso longo

% =====================================================================
% 7d) DADOS DA LSTM - VERSÃO 10 (gerar_dados_lstm_v10.m, 03/11): protocolo dos artigos (todos começam na carga completa e vão até 5%)
% =====================================================================
% Treino da v10 = HPPC + 23 aleatórios antigos que começam cheios + 40 aleatórios novos + DST (só descarga). Validação = 4 antigos + 6 novos.
% Teste = val100 + FUDS + US06 (lista_perfis_teste), × 3 cenários de sensor × 20 sorteios. Treino e validação: caso nominal.
% Metade dos novos tem degraus rápidos (2 a 60 s), para a rede ver variações rápidas de corrente, como nos ciclos de condução.
sementes_v10_treino_lento  = 141:160;  % 20 perfis de TREINO com degraus de 30 a 600 s (como os antigos)
sementes_v10_treino_rapido = 161:180;  % 20 perfis de TREINO com degraus rápidos (2 a 60 s)
sementes_v10_val_lento  = 207:209;     % 3 perfis de VALIDAÇÃO com degraus de 30 a 600 s
sementes_v10_val_rapido = 210:212;     % 3 perfis de VALIDAÇÃO com degraus rápidos
lista_perfis_padrao_treino = {'dst'};  % Ciclo padrão que entra no TREINO (divisão usual da literatura: DST no treino; US06 e FUDS no teste)

% =====================================================================
% 8) DADOS REAIS (fase do artigo - carregar_dados_reais.m)
% =====================================================================
arquivo_dados_reais = '';          % Caminho do .csv do laboratório (vazio até o professor passar os dados)
coluna_tempo = 'tempo_s';          % Nome da coluna de tempo (s) no arquivo
coluna_corrente = 'corrente_A';    % Nome da coluna de corrente (A)
coluna_tensao = 'tensao_V';        % Nome da coluna de tensão terminal (V)
sinal_descarga_real = 1;           % +1 se o equipamento grava descarga positiva (convenção deste código); -1 se grava negativa
Soc0_dados_reais = 1;              % SoC inicial do ensaio real (ex.: 1 após carga completa; 0.6 no perfil de 60%)
% Nos dados reais, o ruído de base já vem do equipamento: só os erros dos cenários 'ref_bias' e 'ref_ruido' são somados.
% No cenário 'nominal' com dados reais, a CC usa a mesma corrente da referência (CC de laboratório) e dá RMSE ≈ 0, como na referência.

% =====================================================================
% 9) GRÁFICOS
% =====================================================================
plotar_dados = true;               % true = mostra corrente, V1 e Vt de cada simulação; o gerar_dados_lstm.m e o rodar_cenarios.m desligam (false)
plotar_resultados = true;          % true = gráficos de SoC e diagnóstico do EKF; o rodar_cenarios.m desliga (false)
imprimir_resultados = true;        % true = tabela de cada rodada no Command Window; o rodar_cenarios.m desliga (imprime só o resumo)
salvar_metricas_individuais = true;   % true = um metricas_*.csv por rodada; o rodar_cenarios.m desliga (grava a tabela de todos os sorteios)

% =====================================================================
% 9b) COMPARAÇÃO FINAL CC × EKF × LSTM (comparacao_final.m, etapa L3, 03/11)
% =====================================================================
pasta_lstm_res = fullfile('resultados ekf', 'resultados_lstm_v10_10s');   % Resultados da LSTM baixados do Drive (rodada 9: versão 10 com 10 sementes; a rodada 8, com 5, fica em resultados_lstm_v10); aceita a subpasta repetida que o .zip cria
n_redes_lstm = 10;                 % Redes (sementes de treino) da LSTM: 10, como recomendam Vidal et al. (2022); decidido em 04/11 antes de ver o resultado (o script confere com as colunas das previsões)
semente_figuras = 1;               % Sorteio de ruído mostrado nas figuras de SoC no tempo (1 = mesma semente do main.m); as tabelas usam os 20 sorteios
cenario_figuras = 'nominal';       % Cenário de sensor das figuras de SoC no tempo
incluir_Q11_alt_figuras = false;   % false = figuras só com o EKF da Tabela 11 (resultado principal); o Q11 alternativo fica nas tabelas (sensibilidade)
% --- Artigo da AF (plano_artigo_af.md, 04/11): só o que entra no artigo; o resto é opcional (slides) ---
perfil_figura_artigo = 'fuds';     % Perfil da figura de SoC no tempo do artigo (FUDS: perfil de teste de Yang 2019 e Chen 2023, sem divergência do EKF)
Soc0_figura_artigo_pct = 90;       % SoC inicial assumido nessa figura (%): mostra numa figura só a CC parada em -10%, o EKF convergindo e a LSTM
gerar_figuras_extras = true;       % true = também as outras 5 figuras de SoC e as 2 de barras (para os slides); false = só as figuras do artigo
rmse_ref_val100 = [0.809, 2.439, 0.809, 0.809];   % RMSE-SoC (%) do EKF da referência no perfil val100 (dados experimentais, SoC de referência por CC):
                                   % nominal com SoC inicial correto (Tab. 12), com erro inicial de 10% (Tab. 14), com bias (Tab. 14), com ruído de média zero (Tab. 14)

% =====================================================================
% MODO 'AP': reproduz exatamente a apresentação parcial (teste de regressão)
% =====================================================================
if strcmp(modo_config, 'AP')       % Sobrescreve só o que mudou entre a AP e o desenho final
    Ts_med = Ts;                   % Na AP, sensores e estimadores rodavam no mesmo passo da planta (0,02 s)
    discretizacao_planta = 'euler';   % Na AP, a planta usava a Equação 2 do resumo estendido (Euler)
    discretizacao_est = 'euler';      % Na AP, o EKF também usava Euler
    ordem_planta = 1;                 % Na AP, a planta tinha 1 ramo RC
    cenario_sensor = 'proprio';       % Na AP, bias + ruído de 1% juntos
    R_ekf = sigma_v^2;                % Na AP, o R era calculado a partir do sigma_v (mesmo valor, conta idêntica à da AP)
end
