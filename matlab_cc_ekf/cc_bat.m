% CONTAGEM DE COULOMB (CC) - rodar pelo main.m
% Uma linha por SoC inicial assumido (lista_Soc0_est, montada no main.m)
% Usa I_medido (com bias + ruído) a cada Ts_med e NUNCA se corrige: o erro inicial permanece e a deriva do bias acumula
% O passo em si está no cc_passo.m (mesma função que vai para o Simulink)

n_ini = length(lista_Soc0_est);          % Número de condições iniciais testadas
Soc_cc = zeros(n_ini, N_med);            % Pré-aloca: linha i = CC partindo de lista_Soc0_est(i)
tempo_cc = zeros(n_ini, 1);              % Tempo de execução de cada rodada (s), para comparar o custo computacional dos métodos

for i = 1:n_ini                          % Loop das condições iniciais
    tic;                                 % Dispara o cronômetro
    Soc_cc(i,1) = lista_Soc0_est(i);     % CC parte do SoC assumido (pode diferir do real Soc0)
    for k = 1:N_med-1                    % Integração recursiva no tempo
        Soc_cc(i,k+1) = cc_passo(Soc_cc(i,k), I_medido(k), bat, Ts_med);   % Retira a carga medida no passo
    end
    tempo_cc(i) = toc;                   % Para o cronômetro e guarda o tempo desta rodada
end
