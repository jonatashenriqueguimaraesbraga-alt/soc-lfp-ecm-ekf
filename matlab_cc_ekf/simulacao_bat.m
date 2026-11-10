Soc0 = 1; %  valor da condição inicial do Soc
V1_0 = 0; %  valor da condição inicial do V1
I = 1.462 * ones(1, 180000); % Corrente definida para o número de amostras para uma hora
N = length(I); % número de amostras
Soc = zeros(1, N); % números de amostras
V1 = zeros(1, N);  % vetor para armazenar a tensão de polarização
Vt = zeros(1, N);  % vetor para armazenar a tensão terminal
Soc(1) = Soc0; % condição inicial do soc
V1(1) = V1_0;  % condição inicial do V1

for k = 1: N-1
    R0_atual = interp1(Soc_tab, R0, Soc(k)); % encontra o valor do R0 baseado no Soc(k)
    R1_atual = interp1(Soc_tab, R1, Soc(k)); % encontra o valor do R1 baseado no Soc(k)
    C1_atual = interp1(Soc_tab, C1, Soc(k)); % encontra o valor do C1 baseado no Soc(k)
    OCV_atual = interp1(Soc_tab, OCV, Soc(k)); % encontra o valor do OCV baseado no Soc(k)
    Soc(k+1) = Soc(k) - (Ts*eta/Cn) * I(k);
    % Equação de estado do SoC: PREVÊ o SoC do PRÓXIMO instante (k+1)
    % a partir do SoC atual (k) e da corrente atual (k)
    V1(k+1)  = (1 - Ts/(R1_atual*C1_atual)) * V1(k) + (Ts/C1_atual) * I(k);
    % Equação de estado do V1: PREVÊ a tensão de polarização do PRÓXIMO
    % instante (k+1), mesma lógica do SoC acima
    Vt(k) = OCV_atual - V1(k) - R0_atual*I(k);
    % Equação de SAÍDA (medição): calcula a tensão terminal do instante
    % ATUAL (k), usando os estados que já temos em mãos nesse momento
    % (não "prevê" nada — só combina valores já conhecidos)
end

% Cálculo do último ponto (Vt(N)) que ficou de fora do loop
OCV_N = interp1(Soc_tab, OCV, Soc(N));
R0_N  = interp1(Soc_tab, R0, Soc(N));
Vt(N) = OCV_N - V1(N) - R0_N * I(N);

t = (0:N-1)*Ts;                                  % Cria vetor de tempo real (amostra x passo)
t = t/60;                                        % Converte de segundos para minutos

figure;                                          % Abre uma nova janela de gráfico
plot(t, Soc);                                    % Plota o SoC em função do tempo real
xlabel('Tempo (min)');
ylabel('SoC (fração 0-1)');
title('Estado de Carga (SoC) durante a descarga');

figure;                                          % Abre outra janela (não sobrescreve a anterior)
plot(t, V1);                                     % Plota a tensão de polarização em função do tempo real
xlabel('Tempo (min)');
ylabel('V1 (V)');
title('Tensão de polarização (V1) durante a descarga');

figure;                                          % Abre a terceira janela
plot(t, Vt);                                     % Plota a tensão terminal em função do tempo real
xlabel('Tempo (min)');
ylabel('Tensão terminal (V)');
title('Tensão terminal (Vt) durante a descarga');

