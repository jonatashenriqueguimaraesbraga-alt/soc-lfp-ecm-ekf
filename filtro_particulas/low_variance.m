function idx = low_variance(w)
% low_variance: reamostragem low variance (mesmo algoritmo do trabalho 6)
% Entrada: w = pesos normalizados (Nx1)
% Saida: idx = indice da particula escolhida para cada posicao nova (Nx1)

% numero de particulas
N = length(w);
% vetor dos indices escolhidos
idx = zeros(N,1);
% sorteia o ponto de partida entre 0 e 1/N
r = rand / N;
% soma acumulada dos pesos, comeca com o peso da primeira particula
c = w(1);
% comeca olhando a primeira particula
i = 1;
% escolhe N particulas novas
for m = 1:N
    % posicao do ponteiro m (ponteiros espacados de 1/N)
    U = r + (m-1) / N;
    % anda pelas particulas ate a soma dos pesos passar do ponteiro
    while U > c && i < N
        % proxima particula
        i = i + 1;
        % soma o peso dela
        c = c + w(i);
    end
    % guarda a particula escolhida
    idx(m) = i;
end
end
