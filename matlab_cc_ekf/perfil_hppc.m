% --- Durações em SEGUNDOS (não dependem do Ts) ---
dur_pulso_ext = 180;    % Pulsos extremos (1-4 e 11-14): 180 s a 1C = 5% de SoC
dur_pulso_int = 360;    % Pulsos intermediários (5-10): 360 s a 1C = 10% de SoC
dur_repouso   = 3600;   % Repouso entre pulsos: 3600 s = 1 h

% Vetor com o tamanho (em amostras) de cada um dos 14 pulsos
tamanhos_pulso = zeros(1, 14);                              % Pré-aloca vetor com 14 posições (uma por pulso)
for k = 1:14                                                % Loop para definir a duração de cada pulso
    if k <= 4 || k > 10                                     % Pulsos 1-4 e 11-14 são os "extremos" (5%)
        tamanhos_pulso(k) = round(dur_pulso_ext / Ts);      % Converte segundos em amostras
    else                                                    % Pulsos 5-10 são os "intermediários" (10%)
        tamanhos_pulso(k) = round(dur_pulso_int / Ts);      % Converte segundos em amostras
    end
end
tamanho_repouso = round(dur_repouso / Ts);                  % Converte 1 h de repouso em amostras

% Calcula o tamanho total do vetor I
tamanho_total = sum(tamanhos_pulso) + 14 * tamanho_repouso;  % Soma todos os pulsos + todos os repousos

% Pré-aloca
I = zeros(1, tamanho_total);              % Cria vetor I vazio já no tamanho final (evita aviso de MATLAB)

% Preenche o vetor
idx = 1;                                  % Ponteiro que marca onde começa o próximo trecho a preencher
for k = 1:14                              % Loop que percorre os 14 ciclos (pulso + repouso)
    I_pulso = (Cn/3600) * ones(1, tamanhos_pulso(k));   % Cria o trecho de corrente do pulso (1C constante, vindo de Cn)
    I_repouso = zeros(1, tamanho_repouso);               % Cria o trecho de corrente do repouso (I=0)
    I(idx : idx+tamanhos_pulso(k)-1) = I_pulso;          % Insere o pulso na posição correta do vetor I
    idx = idx + tamanhos_pulso(k);                       % Avança o ponteiro pelo tamanho do pulso
    I(idx : idx+tamanho_repouso-1) = I_repouso;          % Insere o repouso logo após o pulso
    idx = idx + tamanho_repouso;                         % Avança o ponteiro pelo tamanho do repouso
end

N = length(I);                            % Número total de amostras (tamanho do vetor I)
t = (0:N-1) * Ts;                         % Vetor de tempo em segundos (0 até N-1, multiplicado por Ts)
t = t / 60;                               % Converte o vetor de tempo de segundos para minutos