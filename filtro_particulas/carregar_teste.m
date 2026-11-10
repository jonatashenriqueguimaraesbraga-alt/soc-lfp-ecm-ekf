function [t_min, I_med, Vt_med, Soc_ref] = carregar_teste(pasta_ekf, perfil, cenario, sorteio)
% carregar_teste: le um perfil de TESTE (.csv a 1 s) ja com o cenario de erro aplicado
% Sao os mesmos arquivos (mesmas medicoes e sorteios) do EKF do trabalho de controle
% Entradas: pasta_ekf = pasta 'resultados ekf', perfil = 'val100', 'fuds' ou 'us06',
%           cenario = 'nominal', 'ref_bias' ou 'ref_ruido', sorteio = 1 a 20
% Saidas (vetores linha): tempo (min), corrente medida (A), tensao medida (V), SoC verdadeiro (fracao)

% o val100 ficou na pasta da primeira versao dos dados
if strcmp(perfil, 'val100')
    % pasta do val100
    pasta = fullfile(pasta_ekf, 'dados_lstm');
else
    % pasta do FUDS e do US06
    pasta = fullfile(pasta_ekf, 'dados_lstm_v10');
end
% nome do arquivo deste perfil, cenario e sorteio
arquivo = fullfile(pasta, sprintf('dados_lstm_teste_%s_p3_%s_r%d_1s.csv', perfil, cenario, sorteio));
% le a tabela do arquivo
dados = readtable(arquivo);
% tempo em minutos
t_min = dados.t_min';
% corrente medida (com os erros do cenario)
I_med = dados.I_medido';
% tensao medida
Vt_med = dados.Vt_medido';
% SoC verdadeiro da celula simulada
Soc_ref = dados.Soc';
end
