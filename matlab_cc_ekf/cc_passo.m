function Soc_prox = cc_passo(Soc_k, I_k, bat, Ts)
% cc_passo: UM passo da Contagem de Coulomb (integração da corrente medida, sem nenhuma correção)
% É a Equação 1 do modelo aplicada à corrente MEDIDA: o erro inicial nunca some e o bias se acumula como deriva
% Simulink: bloco MATLAB Function com o SoC voltando por um Unit Delay (ou um Discrete-Time Integrator com ganho -eta/Cn)

Soc_prox = Soc_k - (Ts*bat.eta/bat.Cn) * I_k;           % Retira do SoC a carga medida no passo
end
