% PERFIL PADRÃO DE CONDUÇÃO - DST, US06 ou FUDS, com a corrente de dados públicos (CALCE, célula A123 LFP de 1,1 Ah, 20 °C, 1 s)
% Só a CORRENTE vem do banco público; a tensão e o SoC saem da nossa planta (Tabela 7 da referência), como em todos os perfis.
% Passos: (1) lê 1 ciclo do perfil (arquivo da pasta perfis_padrao); (2) escala o pico para I_pico_padrao (2C da Tab. 5);
%         (3) sem regeneração, os pulsos de carga viram repouso; (4) repete o ciclo desde a carga completa até Soc_final_ale (5%);
%         (5) acrescenta o repouso final; (6) passa de 1 s para o passo da planta (Ts), mantendo cada valor constante no seu segundo.
% Antes de chamar: perfil = 'dst', 'us06' ou 'fuds'; configuracao.m (seção 6b) e parametros_bat.m (Cn, eta) já rodados
% Gera: I, N, t (min), Soc0 e nome_perfil (mesmas variáveis dos outros perfis)

Soc0 = 1;                                                     % SoC REAL inicial: carga completa, como nos ensaios dos artigos (Yang et al., 2019)
switch perfil                                                 % Escolhe o arquivo do ciclo pelo nome do perfil
    case 'dst'                                                % Dynamic Stress Test (USABC): ciclo de 360 s
        arquivo_ciclo = arquivo_ciclo_dst;                    % Arquivo do ciclo (configuracao.m)
        nome_perfil = 'DST';                                  % Nome usado nos títulos dos gráficos
    case 'us06'                                               % US06 (estrada, agressivo): ciclo de 600 s
        arquivo_ciclo = arquivo_ciclo_us06;                   % Arquivo do ciclo
        nome_perfil = 'US06';                                 % Nome nos gráficos
    case 'fuds'                                               % Federal Urban Driving Schedule (urbano): ciclo de 1372 s
        arquivo_ciclo = arquivo_ciclo_fuds;                   % Arquivo do ciclo
        nome_perfil = 'FUDS';                                 % Nome nos gráficos
end
if ~usar_regeneracao                                          % Versão só de descarga (padrão deste trabalho)
    nome_perfil = [nome_perfil ' (só descarga)'];             % Deixa claro nos gráficos que o ciclo foi adaptado
end

tabela_ciclo = readtable(fullfile(pwd, pasta_perfis_padrao, arquivo_ciclo));   % Colunas: t_s (s) e I_A (A, descarga positiva, célula A123)
dt_ciclo = tabela_ciclo.t_s(2) - tabela_ciclo.t_s(1);       % Período das amostras do ciclo (1 s)
I_ciclo = tabela_ciclo.I_A' * (I_pico_padrao / I_pico_calce);   % Escala: pico de 3,85 A (A123) → 2,8 A (2C da nossa célula); ' = vetor linha
if ~usar_regeneracao                                          % Sem frenagem regenerativa
    I_ciclo = max(I_ciclo, 0);                                % Corrente de carga (negativa) vira repouso (zero)
end

carga_alvo = (Soc0 - Soc_final_ale) * Cn / eta;              % Carga (C = A·s) a retirar de Soc0 até Soc_final_ale (Equação 1)
carga_ciclo = sum(I_ciclo) * dt_ciclo;                        % Carga líquida retirada por um ciclo (C)
n_ciclos = ceil(carga_alvo / carga_ciclo);                    % Ciclos inteiros necessários (o último é cortado abaixo)
I_1s = repmat(I_ciclo, 1, n_ciclos);                          % Repete o ciclo n_ciclos vezes (um valor por segundo)
k_fim = find(cumsum(I_1s) * dt_ciclo >= carga_alvo, 1);       % Primeiro segundo em que a carga retirada chega ao alvo
I_1s = [I_1s(1:k_fim), zeros(1, round(dur_repouso_final_ale / dt_ciclo))];   % Corta ali e acrescenta o repouso final

passos_por_amostra = round(dt_ciclo / Ts);                    % Passos da planta em cada segundo do ciclo (1 s / 0,02 s = 50)
I = repelem(I_1s, passos_por_amostra);                        % Cada valor fica constante durante o seu segundo (segurador de ordem zero)
N = length(I);                                                % Número total de amostras da planta
t = (0:N-1) * Ts;                                             % Vetor de tempo em segundos
t = t / 60;                                                   % Converte para minutos (mesma unidade dos outros perfis)
fprintf('Perfil %s: %.1f ciclos (%.1f h até %.0f%% de SoC), pico %.2f A, corrente média %.2f A\n', nome_perfil, k_fim/length(I_ciclo), ...
    k_fim*dt_ciclo/3600, 100*Soc_final_ale, max(I), mean(I_1s(1:k_fim)));   % Resumo do perfil montado
