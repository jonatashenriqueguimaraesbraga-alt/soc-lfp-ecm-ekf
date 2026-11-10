% PERFIL EM DEGRAUS - monta o vetor de corrente I a partir de uma lista de degraus (corrente + duração)
% Usado pelos perfis val100, val60 e aleatorio. Antes de chamar, o perfil define:
%   correntes_degraus = [I_1, I_2, ...]  corrente de cada degrau (A; positivo = descarga; 0 = repouso)
%   duracoes_degraus  = [d_1, d_2, ...]  duração de cada degrau (s; não depende do Ts)
% Gera: I, N, t (mesmas variáveis do perfil_hppc.m)

n_degraus = length(correntes_degraus);                  % Número de degraus do perfil
amostras_degraus = round(duracoes_degraus / Ts);        % Converte a duração de cada degrau de segundos para amostras
N = sum(amostras_degraus);                              % Número total de amostras = soma das amostras de todos os degraus
I = zeros(1, N);                                        % Pré-aloca o vetor de corrente já no tamanho final

idx = 1;                                                % Ponteiro: onde começa o próximo degrau dentro de I
for k = 1:n_degraus                                     % Percorre os degraus em ordem
    I(idx : idx+amostras_degraus(k)-1) = correntes_degraus(k);   % Preenche o trecho do degrau k com a corrente dele
    idx = idx + amostras_degraus(k);                    % Avança o ponteiro para o início do próximo degrau
end

t = (0:N-1) * Ts;                                       % Vetor de tempo em segundos
t = t / 60;                                             % Converte para minutos (mesma unidade dos gráficos do HPPC)
