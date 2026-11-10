function [rmse, mae, erro_max, t_conv] = metricas_erro(Soc_est, Soc_ref, t_min, limiar_conv)
% metricas_erro: a MESMA régua para CC, EKF e LSTM (a LSTM usa a mesma definição no Colab)
% Entradas: Soc_est e Soc_ref (fração, mesmos instantes), t_min (tempo em min dos mesmos instantes), limiar_conv (fração, ex.: 0.02)
% Saídas (em pontos percentuais, p.p., e minutos):
%   rmse     = raiz da média dos erros ao quadrado (métrica da referência, Tabs. 12, 14 e 15)
%   mae      = média do erro absoluto (menos sensível a picos que o RMSE)
%   erro_max = maior erro absoluto (o RMSE dilui erros localizados)
%   t_conv   = tempo até o erro entrar em ±limiar e não sair mais (NaN = termina fora da faixa = não convergiu)

erro = (Soc_est - Soc_ref) * 100;                       % Erro em pontos percentuais
rmse = sqrt(mean(erro.^2));                             % RMSE (p.p.)
mae = mean(abs(erro));                                  % MAE (p.p.)
erro_max = max(abs(erro));                              % Erro máximo (p.p.)
fora = find(abs(erro) > limiar_conv*100, 1, 'last');    % Último instante FORA da faixa de convergência
if isempty(fora)                                        % Nunca saiu da faixa
    t_conv = 0;                                         % Converge desde o início
elseif fora == length(erro)                             % Ainda fora no último instante
    t_conv = NaN;                                       % Não convergiu dentro do ensaio
else                                                    % Saiu da faixa e voltou de vez
    t_conv = t_min(fora+1) - t_min(1);                  % Tempo desde o início da avaliação até entrar de vez na faixa
end
end
