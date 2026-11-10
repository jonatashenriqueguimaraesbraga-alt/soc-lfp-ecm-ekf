% VALIDACAO DO FP - escolhas do filtro feitas SO nos 6 perfis de validacao (s207 a s212)
% Etapas (rodar uma de cada vez, nesta ordem, mudando "etapa" abaixo):
%   'sigma0'      -> desvio da nuvem inicial: 3, 5, 10, 20 p.p. e uniforme 0-100%
%   'diversidade' -> com o sigma0 escolhido: sem nada, Cauchy na corrente, espalhamento apos reamostrar
%   'N'           -> com as escolhas anteriores: N = 100, 500, 1000, 5000 (RMSE e tempo)
% Em todas: 6 perfis x 3 cenarios x SoC0 100/90% x n_sorteios, com CC e EKF nas MESMAS medicoes
% Sorteio r: semente do FP = r; no cenario de ruido, o ruido extra da corrente usa a semente 1000 + r

% comeca limpo
clear; clc; close all;

% ===================== CONFIGURACOES =====================
% etapa da validacao: 'sigma0', 'diversidade' ou 'N'
etapa = 'N';
% pasta dos .csv a 1 s gerados no trabalho de controle
pasta_dados = 'C:\Users\misys\Downloads\Mestrado automacao\SISTEMAS DE CONTROLE AUTOMOTIVO\resultados ekf\dados_lstm_v10';
% pasta dos resultados
pasta_res = fullfile(pwd, 'resultados');
% perfis de validacao
perfis_val = 207:212;
% cenarios de erro de corrente
lista_cenarios = {'nominal', 'ref_bias', 'ref_ruido'};
% SoC inicial assumido (fracao); o verdadeiro e 100% em todos os perfis
lista_Soc0_est = [1.00 0.90];
% numero de sorteios
n_sorteios = 20;
% --- etapa 'sigma0' ---
% desvios da nuvem inicial testados (p.p.); Inf = uniforme 0-100%
lista_sigma0_pp = [3 5 10 20 Inf];
% numero de particulas nas etapas 'sigma0' e 'diversidade'
N_base = 500;
% --- etapas 'diversidade' e 'N' (preencher com o resultado da etapa anterior) ---
% sigma0 escolhido na etapa 'sigma0' (p.p.)
sigma0_escolhido_pp = 5;
% escala do ruido de Cauchy na corrente (A)
escala_cauchy = 0.02;
% desvio do espalhamento do SoC apos reamostrar (fracao)
dp_espalhamento = 1e-4;
% diversidade escolhida na etapa 'diversidade': 'nenhuma', 'cauchy' ou 'espalhamento'
diversidade_escolhida = 'nenhuma';
% --- etapa 'N' ---
% numeros de particulas testados
lista_N = [100 500 1000 5000];
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

% --- FP base: mesmo modelo, mesmo Q e R do EKF ---
% numero de particulas
cfg_base.N = N_base;
% desvio da nuvem inicial (fracao)
cfg_base.sigma0 = sigma0_escolhido_pp / 100;
% desvio do ruido de processo do SoC por passo (raiz de Q11)
cfg_base.dp_Soc_proc = sqrt(cfg_ekf.Q(1,1) * Ts);
% desvio do ruido de processo de V1 por passo (raiz de Q22)
cfg_base.dp_V1_proc = sqrt(cfg_ekf.Q(2,2) * Ts);
% variancia da medicao de tensao no peso (V^2)
cfg_base.R = cfg_ekf.R;
% reamostra quando Neff < N/2
cfg_base.frac_Neff = 0.5;
% sem Cauchy
cfg_base.escala_I_cauchy = 0;
% sem espalhamento
cfg_base.dp_espalhamento = 0;
% V1 inicial das particulas
cfg_base.V1_0 = 0;
% nome do FP base
cfg_base.nome = 'FP';
% diversidade escolhida (vale para a etapa 'N')
switch diversidade_escolhida
    case 'cauchy'
        % liga o ruido de Cauchy na corrente
        cfg_base.escala_I_cauchy = escala_cauchy;
    case 'espalhamento'
        % liga o espalhamento apos reamostrar
        cfg_base.dp_espalhamento = dp_espalhamento;
end

% --- Variantes do FP testadas nesta etapa ---
% lista vazia
variantes = {};
switch etapa
    case 'sigma0'
        % uma variante por sigma0
        for j = 1:length(lista_sigma0_pp)
            % parte do FP base
            v = cfg_base;
            % sigma0 desta variante (Inf continua Inf)
            v.sigma0 = lista_sigma0_pp(j) / 100;
            % nome: uniforme ou valor em p.p.
            if isinf(v.sigma0), v.nome = 'FP unif'; else, v.nome = sprintf('FP sig%g', lista_sigma0_pp(j)); end
            % guarda a variante
            variantes{end+1} = v;
        end
    case 'diversidade'
        % FP sem diversidade extra
        v = cfg_base; v.escala_I_cauchy = 0; v.dp_espalhamento = 0; v.nome = 'FP base'; variantes{end+1} = v;
        % FP com Cauchy na corrente
        v = cfg_base; v.escala_I_cauchy = escala_cauchy; v.dp_espalhamento = 0; v.nome = 'FP Cauchy'; variantes{end+1} = v;
        % FP com espalhamento apos reamostrar
        v = cfg_base; v.escala_I_cauchy = 0; v.dp_espalhamento = dp_espalhamento; v.nome = 'FP espalh'; variantes{end+1} = v;
    case 'N'
        % uma variante por numero de particulas
        for j = 1:length(lista_N)
            % parte do FP base
            v = cfg_base;
            % numero de particulas desta variante
            v.N = lista_N(j);
            % nome com o N
            v.nome = sprintf('FP N%d', lista_N(j));
            % guarda a variante
            variantes{end+1} = v;
        end
    otherwise
        % nome de etapa digitado errado
        error('etapa "%s" nao existe.', etapa);
end

% --- Erros de corrente dos cenarios (mesmos do trabalho de controle) ---
% bias de 0,15 A
cfg_sensor.bias_A = 0.15;
% bias a partir da metade do ensaio
cfg_sensor.inicio_bias = 0.5;
% ruido extra de variancia 0,2 A^2
cfg_sensor.var_ruido = 0.2;

% --- Laco principal ---
% vai juntando uma linha por metodo x caso
linhas = struct([]);
% numero de casos por sorteio
n_casos = length(perfis_val) * length(lista_cenarios) * length(lista_Soc0_est);
% cronometro geral
t_geral = tic;
% um sorteio por volta
for r = 1:n_sorteios
    % perfis de validacao
    for p = perfis_val
        % nome do arquivo (o sorteio do sensor do .csv e o perfil + 1)
        arquivo = fullfile(pasta_dados, sprintf('dados_lstm_validacao_aleatorio_s%d_p3_nominal_r%d_1s.csv', p, p+1));
        % cenarios de erro de corrente
        for c = 1:length(lista_cenarios)
            % le o perfil e aplica o cenario
            [t_min, I_med, Vt_med, Soc_ref] = carregar_validacao(arquivo, lista_cenarios{c}, 1000 + r, cfg_sensor);
            % numero de amostras
            N_med = length(I_med);
            % SoC inicial assumido
            for Soc0_est = lista_Soc0_est
                % dados que identificam o caso
                caso = struct('perfil', sprintf('s%d', p), 'cenario', lista_cenarios{c}, 'Soc0_est_pct', 100*Soc0_est, 'sorteio', r);
                % contagem de Coulomb
                [Soc_cc, tempo_cc] = cc_perfil(I_med, Soc0_est, bat, Ts);
                % guarda a linha da CC
                linhas = [linhas, montar_linha(caso, 'CC', NaN, NaN, Soc_cc, Soc_ref, t_min, tempo_cc, NaN, NaN, NaN)];
                % EKF
                [Soc_ekf, ~, tempo_ekf] = ekf_perfil(I_med, Vt_med, Soc0_est, cfg_ekf, bat, Ts);
                % guarda a linha do EKF
                linhas = [linhas, montar_linha(caso, 'EKF', NaN, NaN, Soc_ekf, Soc_ref, t_min, tempo_ekf, NaN, NaN, NaN)];
                % variantes do FP
                for j = 1:length(variantes)
                    % configuracao desta variante
                    cfg = variantes{j};
                    % roda o FP com a semente do sorteio
                    [Soc_fp, Neff_hist, dp_hist, n_reamost, tempo_fp] = fp_bat(I_med, Vt_med, Soc0_est, cfg, bat, Ts, r);
                    % guarda a linha do FP
                    linhas = [linhas, montar_linha(caso, cfg.nome, 100*cfg.sigma0, cfg.N, Soc_fp, Soc_ref, t_min, tempo_fp, ...
                              median(Neff_hist(2:end)), 100*dp_hist(end), n_reamost/(N_med-1))];
                end
            end
        end
    end
    % tempo gasto ate aqui (min)
    gasto = toc(t_geral) / 60;
    % progresso e previsao do tempo que falta
    fprintf('Sorteio %d de %d concluido | %.1f min gastos | faltam ~%.1f min\n', r, n_sorteios, gasto, gasto/r*(n_sorteios - r));
end

% --- Tabelas ---
% todas as linhas
tab = struct2table(linhas);
% resumo por metodo (todos os casos juntos): media e desvio
resumo_geral = groupsummary(tab, {'metodo'}, {'mean', 'std'}, {'rmse_pct', 'erro_max_pct', 'convergiu', 't_amostra_ms', 'Neff_mediana'});
% resumo por cenario, SoC inicial e metodo
resumo = groupsummary(tab, {'cenario', 'Soc0_est_pct', 'metodo'}, {'mean', 'std'}, {'rmse_pct', 'erro_max_pct', 'convergiu', 't_amostra_ms'});

% --- Salva (guarda copia de rodada anterior antes de sobrescrever) ---
% data e hora para a copia
marca = datestr(now, 'yyyymmdd_HHMM');
% nomes dos arquivos desta etapa
arqs = {['fp_val_' etapa '_todos.csv'], ['fp_val_' etapa '_resumo.csv'], ['fp_val_' etapa '_resumo_geral.csv']};
% para cada arquivo
for a = 1:length(arqs)
    % caminho completo
    arq = fullfile(pasta_res, arqs{a});
    % se ja existe, guarda uma copia
    if exist(arq, 'file'), copyfile(arq, strrep(arq, '.csv', ['_antes_' marca '.csv'])); end
end
% todas as linhas
writetable(tab, fullfile(pasta_res, arqs{1}));
% resumo por cenario
writetable(resumo, fullfile(pasta_res, arqs{2}));
% resumo geral
writetable(resumo_geral, fullfile(pasta_res, arqs{3}));
% tudo em .mat, junto com as configuracoes
save(fullfile(pasta_res, ['fp_val_' etapa '.mat']), 'tab', 'resumo', 'resumo_geral', 'variantes', 'cfg_ekf', 'cfg_sensor', 'n_sorteios', 'perfis_val');

% --- Resumo no Command Window ---
% cabecalho
fprintf('\nEtapa "%s": %d casos x %d sorteios\n', etapa, n_casos, n_sorteios);
% ordena do menor para o maior RMSE medio
rg = sortrows(resumo_geral, 'mean_rmse_pct');
% titulos das colunas
fprintf('%-12s %18s %16s %12s %16s %10s\n', 'Metodo', 'RMSE (pp)', 'Erro max (pp)', 'Em +-2 pp', 'Tempo/amostra(ms)', 'Neff med.');
% uma linha por metodo
for i = 1:height(rg)
    fprintf('%-12s %8.2f +- %6.2f %16.2f %12.2f %16.4f %10.1f\n', rg.metodo{i}, rg.mean_rmse_pct(i), rg.std_rmse_pct(i), ...
        rg.mean_erro_max_pct(i), rg.mean_convergiu(i), rg.mean_t_amostra_ms(i), rg.mean_Neff_mediana(i));
end
% regra da etapa 'N': menor N com RMSE a menos de 0,1 p.p. do maior N
if strcmp(etapa, 'N')
    % RMSE medio de cada N, na ordem da lista
    rmse_N = arrayfun(@(n) mean(tab.rmse_pct(strcmp(tab.metodo, sprintf('FP N%d', n)))), lista_N);
    % primeiro N que atende a regra
    N_ok = lista_N(find(rmse_N - rmse_N(end) < 0.1, 1));
    % mostra a escolha
    fprintf('\nMenor N com RMSE a menos de 0,1 p.p. do N = %d: N = %d\n', lista_N(end), N_ok);
end
% confirma
fprintf('\nArquivos salvos em %s\n', pasta_res);

% --- Funcao local: monta uma linha da tabela de resultados ---
function linha = montar_linha(caso, metodo, sigma0_pp, N, Soc_est, Soc_ref, t_min, tempo, Neff_med, dp_final_pp, frac_reamost)
% metricas com a mesma funcao do trabalho de controle (faixa de +-2 p.p.)
[rmse, ~, erro_max, t_conv] = metricas_erro(Soc_est, Soc_ref, t_min, 0.02);
% copia os dados do caso
linha = caso;
% nome do metodo
linha.metodo = metodo;
% sigma0 (p.p.), so no FP
linha.sigma0_pp = sigma0_pp;
% numero de particulas, so no FP
linha.N = N;
% RMSE (p.p.)
linha.rmse_pct = rmse;
% erro maximo (p.p.)
linha.erro_max_pct = erro_max;
% 1 = termina dentro de +-2 p.p.
linha.convergiu = double(~isnan(t_conv));
% erro no fim do perfil (p.p.)
linha.erro_final_pct = 100 * (Soc_est(end) - Soc_ref(end));
% tempo medio por amostra (ms)
linha.t_amostra_ms = 1000 * tempo / length(Soc_est);
% Neff mediano, so no FP
linha.Neff_mediana = Neff_med;
% desvio padrao do SoC das particulas no fim (p.p.), so no FP
linha.dp_final_pct = dp_final_pp;
% fracao dos passos com reamostragem, so no FP
linha.frac_reamost = frac_reamost;
end
