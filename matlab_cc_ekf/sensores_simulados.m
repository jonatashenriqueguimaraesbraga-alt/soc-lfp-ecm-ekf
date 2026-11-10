% SENSORES SIMULADOS - soma os erros de sensor aos sinais amostrados (ajustes na seção 3 do configuracao.m)
% Usado pelo simulacao_dados.m (ruido_base_ativo = true) e pelo carregar_dados_reais.m (ruido_base_ativo = false: o ruído de base já vem da medição)
% Antes de chamar: I_amostrado e Vt_amostrado (vetores linha, um valor a cada Ts_med), N_med, Cn, semente_rng e ruido_base_ativo
% Gera: I_bias, ruido_corrente, I_medido (corrente que os estimadores enxergam), ruido, Vt_medido (tensão que os estimadores enxergam)

rng(semente_rng);                         % Fixa a semente UMA VEZ: ruído de corrente e de tensão saem da mesma sequência (reprodutível)

% --- Tamanho dos erros de CORRENTE conforme o cenário (configuracao.m, seção 3) ---
I_pico = I_ref_sensor_C * Cn / 3600;      % Fundo de escala do sensor (A): 1C = 1,462 A (no HPPC é o próprio pico, como na AP)
sigma_base = ruido_base_ativo * percentual_ruido * I_pico;   % Ruído de base (A): 1% do fundo de escala na simulação; 0 nos dados reais
switch cenario_sensor                     % Erro extra de cada cenário, POR CIMA do ruído de base
    case 'nominal'                        % Só o ruído de base ("dados medidos", Tab. 12)
        bias_A = 0;                       % Sem bias extra
        var_extra = 0;                    % Sem ruído extra
    case 'ref_bias'                       % Referência: bias de 0,15 A (linha "Bias" das Tabs. 14 e 15)
        bias_A = bias_ref_A;              % 0,15 A na segunda metade
        var_extra = 0;                    % Sem ruído extra
    case 'ref_ruido'                      % Referência: ruído de variância 0,2 A² (linha "Média zero" das Tabs. 14 e 15)
        bias_A = 0;                       % Sem bias
        var_extra = var_ruido_ref;        % 0,2 A²
    case 'proprio'                        % Cenário da AP: bias de 1% + ruído de base
        bias_A = percentual_bias * I_pico;      % Bias de 1% do fundo de escala
        var_extra = 0;                    % Sem ruído extra
    otherwise                             % Nome digitado errado
        error('cenario_sensor "%s" não existe.', cenario_sensor);
end
if var_extra == 0                         % Só o ruído de base
    sigma_i = sigma_base;                 % Desvio padrão total (A) (conta idêntica à da AP)
else                                      % Ruídos independentes: as VARIÂNCIAS se somam
    sigma_i = sqrt(sigma_base^2 + var_extra);   % Desvio padrão total (A)
end

% --- Sensor de CORRENTE: bias + ruído ---
I_bias = zeros(1, N_med);                 % Bias começa zerado
k_bias = max(1, round(inicio_bias * N_med));   % Amostra em que o bias começa (inicio_bias = 0.5 → metade; max evita índice 0)
I_bias(k_bias:N_med) = bias_A;            % Bias constante a partir de k_bias (erro sistemático)
ruido_corrente = sigma_i * randn(1, N_med);    % Ruído gaussiano de média zero (sorteado sempre, mesmo com sigma_i = 0, para o ruído de tensão ser o mesmo em todos os cenários)
I_medido = I_amostrado + I_bias + ruido_corrente;   % Corrente medida = amostrada + erros

% --- Sensor de TENSÃO: só ruído ---
ruido = ruido_base_ativo * sigma_v * randn(1, N_med);   % Ruído gaussiano de média zero (continua a mesma sequência do rng acima; zero nos dados reais)
Vt_medido = Vt_amostrado + ruido;         % Tensão medida = amostrada + ruído
