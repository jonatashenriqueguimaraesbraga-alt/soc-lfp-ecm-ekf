function [t_min, I_med, Vt_med, Soc_ref] = carregar_validacao(arquivo, cenario, semente_ruido, cfg_sensor)
% carregar_validacao: le um perfil de validacao (.csv a 1 s) e aplica o cenario de erro de corrente
% Os .csv de validacao so existem no cenario nominal; bias e ruido sao somados aqui,
% do mesmo jeito do sensores_simulados.m do trabalho de controle
% Entradas: arquivo = caminho do .csv, cenario = 'nominal', 'ref_bias' ou 'ref_ruido',
%           semente_ruido = semente do ruido extra, cfg_sensor = struct com bias_A, inicio_bias e var_ruido
% Saidas (vetores linha): tempo (min), corrente medida (A), tensao medida (V), SoC verdadeiro (fracao)

% le a tabela do arquivo
dados = readtable(arquivo);
% tempo em minutos
t_min = dados.t_min';
% corrente medida (ja tem o ruido de base do sensor)
I_med = dados.I_medido';
% tensao medida (ja tem o ruido do sensor)
Vt_med = dados.Vt_medido';
% SoC verdadeiro da celula simulada
Soc_ref = dados.Soc';
% numero de amostras
N_med = length(I_med);
% erro extra de corrente conforme o cenario
switch cenario
    case 'nominal'
        % nada a somar
    case 'ref_bias'
        % amostra em que o bias comeca (metade do ensaio)
        k_bias = max(1, round(cfg_sensor.inicio_bias * N_med));
        % soma o bias constante dali em diante
        I_med(k_bias:end) = I_med(k_bias:end) + cfg_sensor.bias_A;
    case 'ref_ruido'
        % fixa a semente do ruido extra
        rng(semente_ruido);
        % soma ruido branco de variancia var_ruido (A^2)
        I_med = I_med + sqrt(cfg_sensor.var_ruido) * randn(1, N_med);
    otherwise
        % nome de cenario digitado errado
        error('cenario "%s" nao existe.', cenario);
end
end
