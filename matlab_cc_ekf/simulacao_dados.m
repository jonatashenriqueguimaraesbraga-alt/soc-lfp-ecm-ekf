% SIMULAÇÃO DOS DADOS - planta (ECM de 1ª ordem) + amostragem + sensores, para QUALQUER perfil de corrente
% Substitui o simulacao_hppc.m (versão da AP, guardada no github_repo). Rodar pelo main.m ou pelo gerar_dados_lstm.m
% Antes de chamar: configuracao.m já rodado e variáveis perfil e semente_perfil definidas
%
% Gera duas "camadas" de variáveis:
%   PLANTA (passo fino Ts, só existe em simulação):  t, N, I, Soc, V1, Vt
%   MEDIÇÃO (passo Ts_med, o que os estimadores recebem; mesmo formato dos dados reais):
%       t_med, N_med, I_medido, Vt_medido, Soc_ref (referência para o erro: aqui, o SoC verdadeiro nos instantes medidos)

parametros_bat;                           % Gera Cn, eta, tabelas, limites da célula e a struct bat (modelo que os estimadores conhecem)

% --- Planta com (ou sem) erro de modelo: cópia da bat com os fatores do configuracao.m ---
bat_planta = bat;                                         % Começa igual ao modelo dos estimadores
bat_planta.R0 = fator_R0_planta * bat.R0;                 % R0 da planta
bat_planta.R1 = fator_R1_planta * bat.R1;                 % R1 da planta
bat_planta.C1 = fator_C1_planta * bat.C1;                 % C1 da planta
bat_planta.R2 = fator_R1_planta * bat.R2;                 % R2 da planta (só a de 3ª ordem usa)
bat_planta.R3 = fator_R1_planta * bat.R3;                 % R3 da planta
bat_planta.C2 = fator_C1_planta * bat.C2;                 % C2 da planta
bat_planta.C3 = fator_C1_planta * bat.C3;                 % C3 da planta
bat_planta.Cn = fator_Cn_planta * bat.Cn;                 % Capacidade da planta
bat_planta.OCV = bat.OCV + desvio_OCV_planta;             % OCV da planta (dOCV não muda com um desvio constante)

% --- Checagens do passo (param a execução com a explicação) ---
if ordem_planta == 3 && ~strcmp(discretizacao_planta, 'exata')                              % A planta de 3ª ordem tem ramos muito rápidos
    error('A planta de 3ª ordem exige discretizacao_planta = ''exata'' (o ramo 2 em 50%% de SoC tem tau de ~2e-5 s).');
end
if strcmp(discretizacao_planta, 'euler') && Ts >= 2*min(bat_planta.R1.*bat_planta.C1)       % Euler na planta exige Ts < 2·R1·C1
    error('Ts = %.3f s instável com Euler (limite = %.3f s). Diminua o Ts ou use ''exata''.', Ts, 2*min(bat_planta.R1.*bat_planta.C1));
end
if strcmp(discretizacao_est, 'euler') && Ts_med >= 2*min(R1.*C1)                            % Euler no EKF exige Ts_med < 2·R1·C1
    error('Ts_med = %.3f s instável com Euler no EKF (limite = %.3f s). Use discretizacao_est = ''exata''.', Ts_med, 2*min(R1.*C1));
end
passo_med = round(Ts_med / Ts);                           % Quantos passos da planta cabem em um período de medição (1 s / 0,02 s = 50)
if abs(Ts_med/Ts - passo_med) > 1e-9                      % Ts_med precisa ser múltiplo inteiro de Ts
    error('Ts_med (%.3f s) precisa ser múltiplo inteiro de Ts (%.3f s).', Ts_med, Ts);
end

% --- Perfil de corrente (cada perfil define I, N, t, Soc0 e nome_perfil) ---
switch perfil                             % Escolhe o script do perfil pelo nome definido no main.m
    case 'hppc'                           % HPPC sintético da AP (14 pulsos a 1C + 1 h de repouso)
        perfil_hppc;                      % Gera I, N, t
        Soc0 = 1;                         % SoC REAL inicial (100%)
        nome_perfil = 'HPPC';             % Nome usado nos títulos dos gráficos
    case 'val100'                         % Validação da dissertação partindo de 100% (Fig. 26a)
        perfil_val100;                    % Gera I, N, t, Soc0 e nome_perfil
    case 'val60'                          % Validação da dissertação partindo de 60% (Fig. 26b)
        perfil_val60;                     % Gera I, N, t, Soc0 e nome_perfil
    case 'aleatorio'                      % Degraus sorteados (treino/validação da LSTM); usa semente_perfil
        perfil_aleatorio;                 % Gera I, N, t, Soc0 e nome_perfil
    case {'dst', 'us06', 'fuds'}          % Ciclos padrão de condução (corrente do CALCE, só descarga; configuracao.m, seção 6b)
        perfil_padrao;                    % Gera I, N, t, Soc0 e nome_perfil
    otherwise                             % Nome digitado errado
        error('Perfil "%s" não existe. Use hppc, val100, val60, aleatorio, dst, us06 ou fuds.', perfil);
end
if strcmp(perfil, 'aleatorio')                                  % Rótulo curto para nomes de arquivo
    rotulo_perfil = sprintf('aleatorio_s%d', semente_perfil);   % Ex.: aleatorio_s11
else
    rotulo_perfil = perfil;                                     % Ex.: hppc, val100, val60
end
rotulo_perfil = sprintf('%s_p%d', rotulo_perfil, ordem_planta); % Ordem da planta no nome (ex.: val100_p3): dados de plantas diferentes nunca se misturam

% =====================================================================
% PLANTA: a "verdade física" da bateria, com a corrente LIMPA I, no passo fino Ts
% =====================================================================
Soc = zeros(1, N);                        % Pré-aloca o SoC verdadeiro
V1 = zeros(1, N);                         % Pré-aloca V1 (tensão no capacitor do 1º ramo)
Vt = zeros(1, N);                         % Pré-aloca Vt (tensão terminal)
Soc(1) = Soc0;                            % Condição inicial do SoC (vem do perfil)
V1(1) = V1_0;                             % Condição inicial de V1 (configuracao.m)
if ordem_planta == 1                      % Planta = mesmo modelo de 1 ramo do EKF
    for k = 1:N-1                                                     % Um passo da planta por volta
        [Soc(k+1), V1(k+1), Vt(k)] = ecm_passo(Soc(k), V1(k), I(k), bat_planta, Ts, discretizacao_planta);   % Equações 1, 2 e 3
    end
    [~, ~, Vt(N)] = ecm_passo(Soc(N), V1(N), I(N), bat_planta, Ts, discretizacao_planta);   % Último Vt (o ~ descarta as saídas que não interessam)
else                                      % Planta de 3ª ordem (Tabela 7 completa)
    V_rc = zeros(3, N);                   % Tensões dos três ramos RC (linha j = ramo j)
    V_rc(1,1) = V1_0;                     % Ramo 1 parte de V1_0; ramos 2 e 3 partem de zero (célula em repouso)
    for k = 1:N-1                                                     % Um passo da planta por volta
        [Soc(k+1), V_rc(:,k+1), Vt(k)] = ecm3_passo(Soc(k), V_rc(:,k), I(k), bat_planta, Ts, discretizacao_planta);   % Três ramos
    end
    [~, ~, Vt(N)] = ecm3_passo(Soc(N), V_rc(:,N), I(N), bat_planta, Ts, discretizacao_planta);   % Último Vt
    V1 = V_rc(1,:);                       % Guarda o 1º ramo com o nome de sempre (para o gráfico)
end

% --- Checagem física: o perfil respeita os limites da célula (Tabela 5)? ---
if any(Vt < V_corte_desc)                 % Tensão abaixo do corte de descarga: uma célula real teria parado o ensaio
    fprintf('AVISO: Vt < %.1f V (corte, Tab. 5) em %.2f%% do ensaio (SoC até %.1f%%).\n', V_corte_desc, 100*mean(Vt < V_corte_desc), 100*max(Soc(Vt < V_corte_desc)));
end
if max(I) > I_max_desc                    % Corrente acima do máximo da célula
    fprintf('AVISO: corrente máxima %.2f A acima do limite da célula (%.1f A, Tab. 5).\n', max(I), I_max_desc);
end

% =====================================================================
% MEDIÇÃO: os sensores leem a planta a cada Ts_med e somam seus erros
% =====================================================================
idx_med = 1:passo_med:N;                  % Amostras da planta que os sensores leem (com Ts_med = Ts, todas)
N_med = length(idx_med);                  % Número de medições
t_med = t(idx_med);                       % Instantes das medições (min)
I_amostrado = I(idx_med);                 % Corrente verdadeira nos instantes de medição
Vt_amostrado = Vt(idx_med);               % Tensão verdadeira nos instantes de medição
Soc_ref = Soc(idx_med);                   % Referência para o erro: SoC verdadeiro nos instantes de medição
semente_rng = semente_sensor;             % Semente dos erros: HPPC e validação = 1 (igual à AP)
if strcmp(perfil, 'aleatorio')            % Nos perfis aleatórios, cada semente de perfil ganha ruídos diferentes
    semente_rng = semente_sensor + semente_perfil;   % Ex.: 1 + 11 = 12
end
ruido_base_ativo = true;                  % Simulação: o sensor tem o ruído de base (configuracao.m, seção 3)
sensores_simulados;                       % Gera I_medido e Vt_medido (com bias e ruído)

% --- Índices para plotagem (downsample só para desenhar) ---
passo_plot = 100;                                         % Planta: 1 a cada 100 pontos
idx_plot = 1:passo_plot:N;                                % Índices da planta para as linhas
passo_plot_ruido = 600;                                   % Referência de espaçamento dos pontos soltos (em passos da planta)
idx_plot_med = 1:max(1, round(passo_plot/passo_med)):N_med;          % Medição: mesmo espaçamento de tempo das linhas da planta
idx_plot_ruido_med = 1:max(1, round(passo_plot_ruido/passo_med)):N_med;   % Medição: pontos soltos (vermelhos)

fprintf('Perfil %s: planta de ordem %d, %.1f min, SoC de %.1f%% a %.1f%%, %d medições a cada %g s, sensor: %s\n', ...
    nome_perfil, ordem_planta, t(end), Soc(1)*100, Soc(end)*100, N_med, Ts_med, cenario_sensor);   % Resumo

% --- Gráficos dos dados (desligados no gerar_dados_lstm.m) ---
if plotar_dados
    figure;                                                                         % Corrente real x medida
    plot(t(idx_plot), I(idx_plot), 'k-', 'LineWidth', 1.5);                         % Corrente real (planta): preto
    hold on;                                                                        % Sobrepõe o próximo plot
    plot(t_med(idx_plot_ruido_med), I_medido(idx_plot_ruido_med), 'r.', 'MarkerSize', 3);   % Corrente medida: pontos vermelhos
    hold off;                                                                       % Libera o gráfico
    lgd = legend('I (real)', 'I medido (bias + ruído)', 'Location', 'best');        % Legenda
    set(lgd, 'FontName', 'Times New Roman', 'TextColor', 'k', 'Color', 'w', 'EdgeColor', 'k');  % Cores da legenda
    aplicar_estilo_artigo(['Corrente real vs medida - ' nome_perfil], 'Tempo (min)', 'Corrente (A)');   % Padrão visual; perfil no título evita sobrescrever arquivos

    figure;                                                                         % Tensão no capacitor
    plot(t(idx_plot), V1(idx_plot), 'k-', 'LineWidth', 1.5);                        % V1 (planta)
    aplicar_estilo_artigo(['Tensão no capacitor (V1) - ' nome_perfil], 'Tempo (min)', 'V1 (V)');   % Padrão visual

    figure;                                                                         % Tensão terminal real x medida
    plot(t(idx_plot), Vt(idx_plot), 'k-', 'LineWidth', 1.5);                        % Vt real (planta)
    hold on;                                                                        % Sobrepõe o próximo plot
    plot(t_med(idx_plot_ruido_med), Vt_medido(idx_plot_ruido_med), 'r.', 'MarkerSize', 3);  % Vt medido
    yline(V_corte_desc, 'k:', 'HandleVisibility', 'off');                           % Tensão de corte (Tab. 5), fora da legenda
    hold off;                                                                       % Libera o gráfico
    lgd = legend('Vt (real)', 'Vt medido (com ruído)', 'Location', 'best');         % Legenda
    set(lgd, 'FontName', 'Times New Roman', 'TextColor', 'k', 'Color', 'w', 'EdgeColor', 'k');  % Cores da legenda
    aplicar_estilo_artigo(['Vt real vs medido - ' nome_perfil], 'Tempo (min)', 'Tensão terminal (V)');   % Padrão visual
end
