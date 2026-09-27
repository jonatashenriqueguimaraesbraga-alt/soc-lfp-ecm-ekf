% CONTAGEM DE COULOMB (CC) - rodar pelo main.m
% Uma linha por SoC inicial assumido (lista_Soc0_est, definida no main.m)
% Usa I_medido (com bias + ruído) e NUNCA se corrige: o erro inicial permanece e a deriva do bias acumula

n_ini = length(lista_Soc0_est);          % Número de condições iniciais testadas
Soc_cc = zeros(n_ini, N);                % Pré-aloca: linha i = CC partindo de lista_Soc0_est(i)

for i = 1:n_ini                          % Loop das condições iniciais
    Soc_cc(i,1) = lista_Soc0_est(i);     % CC parte do SoC assumido (pode diferir do real Soc0)
    for k = 1:N-1                        % Integração recursiva no tempo
        Soc_cc(i,k+1) = Soc_cc(i,k) - (Ts*eta/Cn) * I_medido(k);   % Integração pura, sem correção por tensão
    end
end
