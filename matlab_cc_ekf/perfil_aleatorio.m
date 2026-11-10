% PERFIL ALEATÓRIO - degraus de corrente sorteados (treino e validação da LSTM)
% Criação deste trabalho (NÃO vem da dissertação): serve para a rede ver correntes de 0,25 a 2,0 A em toda a faixa de SoC,
% já que o HPPC só tem 0 e 1,462 A e os perfis de teste vão até 2,0 A
% Antes de chamar, definir semente_perfil (cada semente gera um perfil diferente). Os ajustes ficam no configuracao.m (seção 4)

Soc0 = 1;                                                     % SoC REAL inicial da bateria (100%), igual ao HPPC
nome_perfil = sprintf('Aleatório (semente %d)', semente_perfil);   % Nome usado nos títulos dos gráficos
if exist('usar_degraus_rapidos', 'var') && usar_degraus_rapidos   % Perfil com degraus rápidos (versão 10)
    nome_perfil = sprintf('Aleatório rápido (semente %d)', semente_perfil);   % Nome com a indicação "rápido"
end
rng(semente_perfil);                                          % Fixa o sorteio: a mesma semente sempre gera o mesmo perfil
if exist('usar_soc0_aleatorio', 'var') && usar_soc0_aleatorio   % Só nos perfis extra que pedem (gerar_dados_lstm_extra.m); os perfis antigos continuam iguais
    Soc0 = Soc0_min_ale + (1 - Soc0_min_ale) * rand;          % SoC inicial sorteado entre Soc0_min_ale e 100% (configuracao.m, seção 7c)
    nome_perfil = sprintf('Aleatório (semente %d, SoC inicial %.0f%%)', semente_perfil, 100*Soc0);   % Nome com o SoC inicial
end

carga_alvo = (Soc0 - Soc_final_ale) * Cn / eta;               % Carga (C = A·s) a retirar para ir de Soc0 até Soc_final_ale (pela Equação 1)
carga_acum = 0;                                               % Carga já retirada pelos degraus sorteados até agora
correntes_degraus = [];                                       % Lista de correntes, cresce a cada degrau (são poucos degraus, então não pesa)
duracoes_degraus  = [];                                       % Lista de durações, cresce junto

while carga_acum < carga_alvo - 1e-6                          % Sorteia degraus até retirar a carga alvo (1e-6 evita um degrau minúsculo por arredondamento)
    if rand < prob_repouso_ale                                % rand sorteia um número entre 0 e 1: abaixo da probabilidade, o degrau é repouso
        I_deg = 0;                                            % Degrau de repouso
    else                                                      % Senão, é descarga
        I_deg = niveis_descarga_ale(randi(length(niveis_descarga_ale)));   % randi sorteia uma posição da lista de correntes
    end
    if exist('usar_degraus_rapidos', 'var') && usar_degraus_rapidos   % Só nos perfis novos da versão 10 que pedem (gerar_dados_lstm_v10.m)
        dur_deg = round(dur_min_ale_rapido + (dur_max_ale_rapido - dur_min_ale_rapido) * rand);   % Degrau rápido: 2 a 60 s, em segundos inteiros
    else                                                      % Perfis antigos e perfis novos "lentos": continuam iguais
        dur_deg = 10 * round((dur_min_ale + (dur_max_ale - dur_min_ale) * rand) / 10);   % Duração sorteada entre o mínimo e o máximo, arredondada para múltiplo de 10 s
    end
    if I_deg > 0 && carga_acum + I_deg * dur_deg > carga_alvo   % Se este degrau passaria do SoC final...
        dur_deg = (carga_alvo - carga_acum) / I_deg;          % ...encurta o degrau para parar exatamente na carga alvo
    end
    correntes_degraus(end+1) = I_deg;                         % Acrescenta a corrente do degrau ao fim da lista
    duracoes_degraus(end+1)  = dur_deg;                       % Acrescenta a duração do degrau ao fim da lista
    carga_acum = carga_acum + I_deg * dur_deg;                % Atualiza a carga já retirada
end

correntes_degraus(end+1) = 0;                                 % Repouso final: a rede vê a relaxação da tensão em SoC baixo
duracoes_degraus(end+1)  = dur_repouso_final_ale;             % Duração do repouso final (configuracao.m)
perfil_degraus;                                               % Monta I, N e t a partir dos degraus
