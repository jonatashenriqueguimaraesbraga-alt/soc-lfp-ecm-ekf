% TESTE FINAL - CC, EKF e FP nos perfis de teste (val100, FUDS e US06)
% Configuracao do FP congelada na validacao: sigma0 = 5 p.p., sem diversidade extra, N = 100
% Mesmos .csv (mesmas medicoes e sorteios 1 a 20) do EKF do trabalho de controle
% Sensibilidade: FP com R = (30 mV)^2 sobre as mesmas medicoes
% Para o tempo por amostra: rodar com o PC sem outros programas abertos

% comeca limpo
clear; clc; close all;

% ===================== CONFIGURACOES =====================
% pasta 'resultados ekf' do trabalho de controle (onde estao os .csv)
pasta_ekf = 'C:\Users\misys\Downloads\Mestrado automacao\SISTEMAS DE CONTROLE AUTOMOTIVO\resultados ekf';
% pasta dos resultados
pasta_res = fullfile(pwd, 'resultados');
% perfis de teste
lista_perfis = {'val100', 'fuds', 'us06'};
% cenarios de erro de corrente
lista_cenarios = {'nominal', 'ref_bias', 'ref_ruido'};
% SoC inicial assumido (fracao); o verdadeiro e 100% em todos os perfis
lista_Soc0_est = [1.00 0.90];
% numero de sorteios
n_sorteios = 20;
% numero de particulas (escolhido na validacao)
N_final = 100;
% desvio da nuvem inicial (p.p., escolhido na validacao)
sigma0_final_pp = 5;
% R da sensibilidade (V^2): (30 mV)^2
R_sensib = (30/1000)^2;
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

% --- FP final: mesmo modelo, mesmo Q e R do EKF ---
% numero de particulas
cfg_fp.N = N_final;
% desvio da nuvem inicial (fracao)
cfg_fp.sigma0 = sigma0_final_pp / 100;
% desvio do ruido de processo do SoC por passo (raiz de Q11)
cfg_fp.dp_Soc_proc = sqrt(cfg_ekf.Q(1,1) * Ts);
% desvio do ruido de processo de V1 por passo (raiz de Q22)
cfg_fp.dp_V1_proc = sqrt(cfg_ekf.Q(2,2) * Ts);
% variancia da medicao de tensao no peso (V^2)
cfg_fp.R = cfg_ekf.R;
% reamostra quando Neff < N/2
cfg_fp.frac_Neff = 0.5;
% sem Cauchy
cfg_fp.escala_I_cauchy = 0;
% sem espalhamento
cfg_fp.dp_espalhamento = 0;
% V1 inicial das particulas
cfg_fp.V1_0 = 0;
% nome na tabela
cfg_fp.nome = 'FP';
% --- FP da sensibilidade: igual, so muda o R ---
% copia o FP final
cfg_fp_R30 = cfg_fp;
% R de (30 mV)^2
cfg_fp_R30.R = R_sensib;
% nome na tabela
cfg_fp_R30.nome = 'FP R30';

% --- Laco principal ---
% vai juntando uma linha por metodo x caso
linhas = struct([]);
% series do sorteio 1 (para as figuras do artigo)
series = struct([]);
% cronometro geral
t_geral = tic;
% um sorteio por volta
for r = 1:n_sorteios
    % perfis de teste
    for p = 1:length(lista_perfis)
        % cenarios de erro de corrente
        for c = 1:length(lista_cenarios)
            % le as medicoes deste perfil, cenario e sorteio
            [t_min, I_med, Vt_med, Soc_ref] = carregar_teste(pasta_ekf, lista_perfis{p}, lista_cenarios{c}, r);
            % SoC inicial assumido
            for Soc0_est = lista_Soc0_est
                % dados que identificam o caso
                caso = struct('perfil', lista_perfis{p}, 'cenario', lista_cenarios{c}, 'Soc0_est_pct', 100*Soc0_est, 'sorteio', r);
                % contagem de Coulomb
                [Soc_cc, tempo_cc] = cc_perfil(I_med, Soc0_est, bat, Ts);
                % guarda a linha da CC
                linhas = [linhas, montar_linha(caso, 'CC', NaN, Soc_cc, Soc_ref, t_min, tempo_cc, NaN, NaN, NaN)];
                % EKF
                [Soc_ekf, ~, tempo_ekf] = ekf_perfil(I_med, Vt_med, Soc0_est, cfg_ekf, bat, Ts);
                % guarda a linha do EKF
                linhas = [linhas, montar_linha(caso, 'EKF', NaN, Soc_ekf, Soc_ref, t_min, tempo_ekf, NaN, NaN, NaN)];
                % FP final (semente = sorteio)
                [Soc_fp, Neff_fp, dp_fp, nre_fp, tempo_fp] = fp_bat(I_med, Vt_med, Soc0_est, cfg_fp, bat, Ts, r);
                % guarda a linha do FP
                linhas = [linhas, montar_linha(caso, cfg_fp.nome, cfg_fp.N, Soc_fp, Soc_ref, t_min, tempo_fp, ...
                          median(Neff_fp(2:end)), 100*dp_fp(end), nre_fp/(length(I_med)-1))];
                % FP da sensibilidade (mesma semente)
                [Soc_fp30, Neff_fp30, dp_fp30, nre_fp30, tempo_fp30] = fp_bat(I_med, Vt_med, Soc0_est, cfg_fp_R30, bat, Ts, r);
                % guarda a linha do FP R30
                linhas = [linhas, montar_linha(caso, cfg_fp_R30.nome, cfg_fp_R30.N, Soc_fp30, Soc_ref, t_min, tempo_fp30, ...
                          median(Neff_fp30(2:end)), 100*dp_fp30(end), nre_fp30/(length(I_med)-1))];
                % no sorteio 1, guarda as series para as figuras
                if r == 1
                    % junta tudo do caso numa struct
                    s = caso;
                    % tempo (min)
                    s.t_min = t_min;
                    % SoC verdadeiro
                    s.Soc_ref = Soc_ref;
                    % CC
                    s.Soc_cc = Soc_cc;
                    % EKF
                    s.Soc_ekf = Soc_ekf;
                    % FP final
                    s.Soc_fp = Soc_fp;
                    % Neff do FP final
                    s.Neff_fp = Neff_fp;
                    % desvio da nuvem do FP final
                    s.dp_fp = dp_fp;
                    % FP da sensibilidade
                    s.Soc_fp_R30 = Soc_fp30;
                    % corrente medida (para as figuras)
                    s.I_med = I_med;
                    % guarda o caso
                    series = [series, s];
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
% resumo por perfil, cenario, SoC inicial e metodo (tabela do artigo)
resumo = groupsummary(tab, {'perfil', 'cenario', 'Soc0_est_pct', 'metodo'}, {'mean', 'std'}, ...
    {'rmse_pct', 'erro_max_pct', 'convergiu', 't_amostra_ms', 'Neff_mediana'});
% resumo geral por metodo
resumo_geral = groupsummary(tab, {'metodo'}, {'mean', 'std'}, {'rmse_pct', 'erro_max_pct', 'convergiu', 't_amostra_ms', 'Neff_mediana'});

% --- Salva (guarda copia de rodada anterior antes de sobrescrever) ---
% data e hora para a copia
marca = datestr(now, 'yyyymmdd_HHMM');
% nomes dos arquivos
arqs = {'fp_teste_todos.csv', 'fp_teste_resumo.csv', 'fp_teste_resumo_geral.csv'};
% para cada arquivo
for a = 1:length(arqs)
    % caminho completo
    arq = fullfile(pasta_res, arqs{a});
    % se ja existe, guarda uma copia
    if exist(arq, 'file'), copyfile(arq, strrep(arq, '.csv', ['_antes_' marca '.csv'])); end
end
% todas as linhas
writetable(tab, fullfile(pasta_res, arqs{1}));
% resumo por caso
writetable(resumo, fullfile(pasta_res, arqs{2}));
% resumo geral
writetable(resumo_geral, fullfile(pasta_res, arqs{3}));
% tabelas, series do sorteio 1 e configuracoes em .mat
save(fullfile(pasta_res, 'fp_teste.mat'), 'tab', 'resumo', 'resumo_geral', 'series', 'cfg_fp', 'cfg_fp_R30', 'cfg_ekf', 'n_sorteios');

% --- Resumo no Command Window: RMSE medio +- desvio por caso ---
% cabecalho
fprintf('\nTeste final: %d perfis x %d cenarios x %d SoC0 x %d sorteios\n', length(lista_perfis), length(lista_cenarios), length(lista_Soc0_est), n_sorteios);
% titulos das colunas
fprintf('%-8s %-10s %5s %18s %18s %18s %18s\n', 'Perfil', 'Cenario', 'SoC0', 'CC', 'EKF', 'FP', 'FP R30');
% metodos na ordem das colunas
metodos = {'CC', 'EKF', 'FP', 'FP R30'};
% um caso por linha
for p = 1:length(lista_perfis)
    for c = 1:length(lista_cenarios)
        for Soc0_est = lista_Soc0_est
            % comeca a linha
            fprintf('%-8s %-10s %5.0f', lista_perfis{p}, lista_cenarios{c}, 100*Soc0_est);
            % uma coluna por metodo
            for m = 1:length(metodos)
                % linhas da tabela deste caso e metodo
                sel = strcmp(tab.perfil, lista_perfis{p}) & strcmp(tab.cenario, lista_cenarios{c}) & ...
                      tab.Soc0_est_pct == 100*Soc0_est & strcmp(tab.metodo, metodos{m});
                % media +- desvio do RMSE nos sorteios
                fprintf(' %8.2f +- %6.2f', mean(tab.rmse_pct(sel)), std(tab.rmse_pct(sel)));
            end
            % fecha a linha
            fprintf('\n');
        end
    end
end
% tempo por amostra medio de cada metodo
fprintf('\nTempo por amostra (ms): ');
% um metodo por vez
for m = 1:length(metodos)
    % media de todos os casos
    fprintf('%s %.4f | ', metodos{m}, mean(tab.t_amostra_ms(strcmp(tab.metodo, metodos{m}))));
end
% confirma
fprintf('\nArquivos salvos em %s\n', pasta_res);

% --- Funcao local: monta uma linha da tabela de resultados ---
function linha = montar_linha(caso, metodo, N, Soc_est, Soc_ref, t_min, tempo, Neff_med, dp_final_pp, frac_reamost)
% metricas com a mesma funcao do trabalho de controle (faixa de +-2 p.p.)
[rmse, ~, erro_max, t_conv] = metricas_erro(Soc_est, Soc_ref, t_min, 0.02);
% copia os dados do caso
linha = caso;
% nome do metodo
linha.metodo = metodo;
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
% tempo de convergencia (min); NaN = nao convergiu
linha.t_conv_min = t_conv;
% tempo medio por amostra (ms)
linha.t_amostra_ms = 1000 * tempo / length(Soc_est);
% Neff mediano, so no FP
linha.Neff_mediana = Neff_med;
% desvio padrao do SoC das particulas no fim (p.p.), so no FP
linha.dp_final_pct = dp_final_pp;
% fracao dos passos com reamostragem, so no FP
linha.frac_reamost = frac_reamost;
end
